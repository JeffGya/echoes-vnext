# V2-DIRECTIVE-002 — Session handover (rewritten 2026-10-14, before a context compaction)

Read this first after the compaction. Then read the files in section 3. Written in Simplified Technical English.
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
| Phase A | DONE and merged. PR #106, main `2779e08`. |
| Phases B+C | Backend and frontend are BUILT, QA-checked and committed on branch `claude/v2-directive-002-phase-bc`. **DRAFT PR #107**: https://github.com/JeffGya/echoes-vnext/pull/107. Head at time of writing: `d05aa9a` (verify with `git log --oneline -3`). |
| Full suite | ONE serial run was RUNNING when this was written (alarm 3600, started about 21:50 local). See section 1a. |
| Jeff's in-game test | Not done. Steps are in section 4 item 2. |
| Phase D | Not started. Starts after B+C merges. |
| Parked goal | V2-COMBAT-004 (Keeper tactical guidance). Planning resumes after Phase D. Recon is in the old plan and in memory file `directive-002-before-combat-004`. |
| Worktree | `/Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/v2-combat-004-plan-1b1efd` (old name; the branch is the B+C branch). |

**Commit rule (Jeff's standing yes):** commit as we go, after the main chat has verified the work. Push with `git push -q`. The PR becomes ready only after Jeff's in-game test. Jeff merges. One PR per phase.

### 1a. The full suite run
- Log: `/private/tmp/claude-501/-Users-jeffreygyamfi-Sites-echoes-vnext--claude-worktrees-v2-combat-004-plan-1b1efd/af1d7d7c-e4f7-4a08-937b-e0320acf019f/scratchpad/fullrun/full.log`.
- The log ends with a line `exit <code> end <time>` when the run finishes.
- If the log has no `exit` line, check: `pgrep -f 'godot --headless --quit --path .* -- tests$'`. A live process means the run still goes.
- When it ends, read: the `Tests:` line, the exit code (142 = the alarm killed it, NOT a pass), start and end times, and the names of failing tests.
- Expected result: only one red test, `movement_arbiter/avoid_overcommit_stays_proportionate` (known, not this story).
- Nobody runs any other test while the run goes. The test folder `/tmp/echoes-vnext-tests` is exclusive.
- When this handover was written, the log had no `exit` line and one Godot process was alive.

### 1b. What is DONE and committed (since `2779e08`)
| Part | Commits |
|---|---|
| Design, numbers, mockup, backend plan | `e496b64` |
| Backend slices S0, S1a, S1b, S1c (one result per Advance, exposure map, objective in the pool) | `c4af001`, `5963b77`, `73b9a21`, `330cd28` |
| S2a to S2e (shared Judgment reader, party stance, category bend, return-safety bend, counterfactual naming) | `5fff511`, `49d5a51`, `de6b27f`, `79ae60c`, `05df89c` |
| S3, S3b (stop kinds, reveal peek, snapshot fields, S3 findings) | `b255124`, `dfe63cd` |
| S4a, S4b, S4c (contact literals to config, bid scaling, resonance bonus rename and wiring) | `5a28dab`, `a6086e8`, `1e592b6` |
| S5 (saved journey entry, old-save repair) | `1715ace` |
| Backend QA (opus, no blockers) fixes: A naming rule, steadied class, readiness for all Directives. B guard tests, escape base in config, replan cap dropped. C stale comments and docs. D base-plan check. E speed trim | `908af1b`, `ac9a418`, `6d9bca4`, `9c8472e`, `1c8d58b` |
| Frontend step 1 (timing keys, draft glyphs, AI prompt file), F1 (glyph on Echo card, party chip, why card, step row, snapshot wiring, `data/ui/stage_why_text.json` placeholders) | `345b392`, `7e6b604` |
| Camera test fixes, Echo `id` in `party_preview`, preview presentation | `2cd396d`, `36094de` |
| F2 motion (`StopMarkMotion`) | `6a4aad2` |
| Frontend QA (opus, no blockers) fixes: chip fixed slot, overlay waits for the mark, token tap closes, small fixes | `d05aa9a` |
| Decisions D-43 to D-59 recorded | `decisions.md` (D-58 `6ac88f4`, D-59 `6cd64c2`) |

Speed result (D-55): mean Advance dispatch with 5 Echoes went from 338 / 484 ms (Scout / Seek) to 169 / 228 ms.

## 2. Decisions recap (full log: `decisions.md`, D-00 to D-59; ANSWERS #81, #82, #83)

Earlier decisions (D-00 to D-42) shaped the design. Key ones: three phases and one PR each (D-01). Directive-only influence (D-09). Contact bids scale by Judgment and fear, resonance bonus on Seek Signs (D-11, D-16, D-24, D-30). The why shows on demand only, with a persistent stop marker (D-12, D-32). `step_budget` is the baseline and readiness only lowers it (D-13, D-27). Target screens 1280x720 and 1920x1080, touch-first (D-39). Tunables live in config (ANSWERS #83, D-33).

Decisions since the design stage:

| ID | Decision |
|---|---|
| D-43 | Design approved. The n/n step count text is removed. The step row shows diamonds, lost steps crossed out. |
| D-44 | A party bend decides ties only. Per-Directive party numbers live in `data.stages.party_stance.directive_profile.<id>`. Numbers are PROPOSED DEFAULT (`numbers.md`). |
| D-45 | Pause probe done. `pause_cap_per_advance` = 2. It never binds on shipped boards. |
| D-46 | A pause ends the Advance. Naming compares only the first plan. |
| D-47 | Backend plan answers: lowest-id tie pick, snapshot carries `stages.presentation`, contact literals to config. |
| D-48 | Keep the per-step detour rule. Build C1 later with the saved journey entry. Record a terrain cause when a detour is refused. |
| D-49 | Pool rule accepted. Watch note on V2-STAGE-010, V2-STAGE-101, V2-STAGE-102: re-run `probes/pool_probe.gd.txt`. |
| D-50 | Scout base commitment 0.6. "Scout reveals wider" means per step. |
| D-51 | Frontier `route_character` deferred to V2-STAGE-010. |
| D-52 | S3 findings: whole route exempt when the target is the exposure source. `reveal_stop_kinds` is the switch. `arrived_at` = target reached. `_comment` keys stripped from `presentation`. |
| D-53 | Journey entry lifetime approved (entry kept across combat and reload, cleared after a successful return home and a later entry). |
| D-54 | Backend QA answers. Fifth reason class `steadied`. Readiness applies to every Directive. Fix packages A to C. |
| D-55 | Name an Echo only if the model plan equals the real walk. Trim speed now. V2-INFRA-010 scheduled after this story. |
| D-56 | A 13% drop rate of proposed names accepted. |
| D-57 | Timings approved as starting values. Jeff tunes in game. Reduced-motion switch is a later story. |
| D-58 | The Directive badge uses one neutral colour. |
| D-59 | Frontend QA answers. Chip gets a fixed slot beside the cards. Overlays wait for the mark. A second tap on the token closes the why card. |

## 3. File map (all in `docs/stories/v2-directive-002/` unless noted)

| File | What it is |
|---|---|
| `design.md` | The B+C design spec. |
| `decisions.md` | Decision log, D-00 to D-59. |
| `numbers.md` | Authored numbers (PROPOSED DEFAULT). |
| `backend-plan.md` | Slice plan S0 to S5 and the QA packages. |
| `timings-proposal.md` | Motion timings (approved as starting values, D-57). |
| `glyph-shapes.md`, `glyph-ai-prompts.md` | Glyph shape spec and prompts for Jeff to generate the finished glyphs. |
| `follow-ups.md` | Open items and findings not in scope. Read it fully. |
| `new-story-drafts.md` | Drafts of V2-BOND-004 and V2-STAGE-010. |
| `slack-gate-options.md`, `route-character-options.md` | Evidence for D-48 and D-51. |
| `probes/` | Probe sources. Copy out and rename to `.gd` to run. |
| `mockups/` | Old mockup. |
| `handoff.md` | Phase A handoff. |
| `~/.claude/plans/jolly-cooking-crescent.md` | Approved plan. Read the last "Status addendum" (2026-10-14). |
| `data/ui/stage_why_text.json` | Placeholder why-card text. Read directly by `ui/`. |
| `assets/ui/stage_stop_glyphs/` | Draft glyphs. Placeholders. |
| `docs/LESSONS.md` (#34, #35), `AGENTS.md`, `ANSWERS.md` | Rules and recorded decisions. Never read `CONVENTIONS.md` or the GDD whole: use `docs/canon-index.md`. |

## 4. Next steps, in order

1. **Read the full suite result** (section 1a). Fix any failure by dispatching the owning agent. One cause per fix. Use opus for attribution. Findings are not authorisation: ask Jeff before fixing QA findings.
2. **Give Jeff the in-game test steps.** Write them in STE. Run the game with: `/opt/homebrew/bin/godot --path /Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/v2-combat-004-plan-1b1efd --windowed --resolution 1600x900`. Cover these checks:
   - Two parties, same Directive, same seed, different visible result.
   - The stop glyph sits on the named Echo's card.
   - A chip shows when no Echo is named.
   - Tap the stop marker: the why card opens. A second tap on the token or a tap outside closes it.
   - A shaken party shows crossed-out steps and the shake.
   - Compare Seek Signs against Scout Carefully.
   - Save, quit, load: the glyph returns. Add a combat in between.
   - Known limits: the Advance label is blank in the live game (separate task), the why-card text is a placeholder `[Jeff's wording: ...]`, glyphs are drafts, the pulse looks weak, the walk disables Advance until 0.85 s.
3. **Docs pass at the end of the phase.**
   - `docs/integration-map.md` and `docs/project_systems_audit.md` (keep in sync, see `CONTEXT.md`).
   - `docs/MEMORY.md`: systems inventory, V2 status line, suite total from the real `Tests:` line.
   - `CONVENTIONS.md`: the `flow.stage_explore` row (about line 1278) lacks `stop`, `travel_why`, `step_budget`, `effective_steps`, `presentation`, `party_preview.id`. The `flow.stage` row (about line 1011) lacks `presentation`. Document `data/ui/stage_why_text.json`, read directly by `ui/`.
   - `AGENTS.md`: suite count 129 to the real count, and the new suites `contact_cfg`, `stage_stop_ui` and the contact bid test file. Only with Jeff's yes.
   - `scripts/run-tests-sharded.sh`: the shard map lacks `contact_cfg` and the new suites.
   - `docs/canon-index.md` if a range shifts.
   - `docs/LESSONS.md`: add a lesson if Jeff corrected something. Suggest: run the whole camera and pointer suites after any UI change, and run the full suite earlier.
4. **Notion** (show each edit to Jeff first, then write). Copy D-44 to D-59 to the V2-DIRECTIVE-002 page (D-25 to D-43 already written, Spec State Locked already set). Update the story status.
5. **Mark PR #107 ready** only after Jeff's in-game test. Jeff merges.
6. **Phase D** (combat expression, stop-short Directive cause) starts after B+C merges. Then V2-COMBAT-004 planning resumes.

## 5. Rules you must follow (Jeff's)

- **Working preferences** (`~/.claude/CLAUDE.md`): ask before assuming. Jeff designs, you coordinate. Backend before frontend. Every story ends with Docs + Commit. Write to Jeff in STE. STE does not apply to player-facing game text.
- **Repo `CLAUDE.md`:** agents default to sonnet. Opus is per call. Never `fable`. Do not spawn `game-orchestrator` as a subagent for single-discipline work. Agent questions reach Jeff through you (OPEN blocks). Re-check BLOCKED lines against the repo first. Ask one question at a time with `AskUserQuestion`.
- **Tests:**
  - ONE full mode only: serial. Alarm 3600, tool timeout 3700000, background, log to a file.
  - No subagent runs a long command (over about 2 minutes) or any full suite. This includes `qa-verifier`. A subagent ends with a RUN REQUEST. The main chat runs it.
  - Filtered runs: one per shell command, never two at once. `rm -rf /tmp/echoes-vnext-tests` first. Confirm a `Tests:` line.
  - Never use the filter `fingerprint`. It matches the long combat suites and the alarm kills it. Use `snapshot_fingerprint` or exact suite names.
  - Known red test: `movement_arbiter/avoid_overcommit_stays_proportionate`.
  - After any UI change, a QA pass runs the whole related suite group (camera, pointer).
- **Ask first:** `AGENTS.md` edits and Notion writes. Show the exact Notion edit first.
- **Never answer design questions for Jeff.** Player-facing wording is Jeff's.
- **Tunables live in config** (ANSWERS #83). Comments: write fewer (AGENTS.md rule 28).
- **Fixtures:** a typed parameter rejects duck-typed fakes (LESSONS #35). After changing a shared function signature, grep `tests/` for mocks.
- **Commits:** STE message. End with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. Create PRs with `gh pr create --body-file`.
- **Mockup and QA habits:** check a mockup against the build. After an agent stops, audit the tree (`git status`, `git diff`) before you trust its report. Findings are not authorisation.
- **Tools:** `SendMessage` resumes a finished agent only if its transcript exists. After a compaction some are lost: spawn a new one. The Notion tools are deferred: load them with `ToolSearch` (`notion-update-page`, `notion-fetch`, `notion-query-data-sources`, `notion-create-pages`).

## 6. Facts worth remembering

- Stage selection: `ActiveStageService.find_explore_target` (tiers 1 to 4). `StagePartyMovementAdapter.select_objective_target` ranks inside a slack envelope. The objective weight joins the pool (D-28, S1c).
- `ConfigService.get_directives_cfg` owns the Directive subtree read. `DirectiveService.resolve` is the accessor.
- The `_data_subtree` check `get_script() == ConfigService` keeps test subclasses working (LESSONS #35). Do not remove it.
- The stage snapshot carries `stop`, `travel_why`, `step_budget`, `effective_steps`, `presentation`, and an `id` per `party_preview` row. The journey entry is saved (S5, D-53).
- Save dirs: tests use `/tmp/echoes-vnext-tests`. Normal play uses `~/Library/Application Support/Godot/app_userdata/echoes-vnext/saves/`.
- The contact window has four old UI issues (D-22). They are a separate later story.
- A local web server for the old mockup ran on port 8765. It dies with the session. Ignore it.
- Memory dir: `/Users/jeffreygyamfi/.claude/projects/-Users-jeffreygyamfi-Sites-echoes-vnext/memory/`.

## 7. Open items for Jeff (ask one at a time)

| # | Item | Recorded in |
|---|---|---|
| 1 | Player wording: why-card lines, stop kind names, terrain cause. Jeff writes them. | `data/ui/stage_why_text.json` placeholders; D-48, D-57 |
| 2 | Finished glyph shapes. Jeff generates them with `glyph-ai-prompts.md` and sends files. Drafts in `assets/ui/stage_stop_glyphs/` are placeholders. Swap and re-import. | `glyph-shapes.md` |
| 3 | Tune in game: pulse peak, shake size, input-ready point 0.85 s, glyph overshoot. | D-57, `timings-proposal.md` |
| 4 | Scout number question: a calm party cannot change Scout's first plan (exposure_tolerance bound or price rounding). | `follow-ups.md` (slice S2e) |
| 5 | The unused key `pause_cap_per_advance`: keep or drop. | D-46 |
| 6 | The 60 ms snapshot rebuild has no owner. V2-INFRA-010 (Order 254.7) depends on V2-DIRECTIVE-002 and may take it. Notion edit done. | `follow-ups.md` (QA package E) |
| 7 | `AGENTS.md`: the 960x540 contract and the suite count. Need Jeff's yes. | D-39 |
| 8 | Reduced-motion switch is a later story. The flag exists, default off. | D-57 O2 |
| 9 | Blank Advance label on stage explore: separate task (spawn_task chip `task_2e47501b`). | this file |
| 10 | V2-BOND-004 and V2-STAGE-010 are Draft in Notion. Watch notes on the pool rule are on STAGE-010, STAGE-101, STAGE-102. | D-49, `new-story-drafts.md` |
| 11 | Phone measurement: is a pressed button enough when the Advance tail is about 1 s? | D-57 O3 |
| 12 | Remaining notes. | `follow-ups.md` |

## 8. Briefs to re-use

- **Fix after full suite (owning agent):** name the failing test, the cause, and the file. One cause per fix. Opus if the cause is unknown. End with a compile check and a filtered run (one suite, `Tests:` line). No full suite.
- **Glyph swap (ui-ux-designer):** replace the draft files in `assets/ui/stage_stop_glyphs/` with Jeff's files, keep names, re-import, run the `stage_stop_ui` suite and the camera suite group.
- **Docs pass (sonnet):** list in section 4 item 3. Take the suite total from the real `Tests:` line. Do not edit `AGENTS.md` without Jeff's yes.
