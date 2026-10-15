# V2-DIRECTIVE-002 — Session handover (rewritten 2026-10-15, after Jeff approved phases B+C)

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
| Phase A | DONE and merged. PR #106, main `2779e08`. |
| Phases B+C | BUILT, QA-checked, committed on branch `claude/v2-directive-002-phase-bc`. **Jeff tested in game and approved on 2026-10-15.** **DRAFT PR #107**: https://github.com/JeffGya/echoes-vnext/pull/107. Head when written: `6b6f081` (verify with `git log --oneline -3`). |
| Full suite | Serial run: 2192 total, 2191 passed, 1 failed. The one red test is the known `movement_arbiter/avoid_overcommit_stays_proportionate` (not this story). |
| Bend variants | Rejected (D-65). V0 kept. No number in `data/balance.json` changed. |
| Party card word | Done: "The party" (D-64), in `data/ui/stage_why_text.json` (`party_card_label`). |
| Docs pass | Done 2026-10-15, except the items in section 4 that need Jeff's yes. |
| Phase D | Not started. Starts after B+C merges. |
| Parked goal | V2-COMBAT-004 (Keeper tactical guidance). Planning resumes after Phase D. Recon is in the old plan and in the memory file `directive-002-before-combat-004`. |
| Worktree | `/Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/v2-combat-004-plan-1b1efd` (old name; the branch is the B+C branch). |

**Commit rule (Jeff's standing yes):** commit as we go, after the main chat has verified the work. Push with `git push -q`. Jeff merges. One PR per phase.

### 1a. What B+C built (short)
- Core: `StageExposureMap`, `StagePartyStance`, `StageStopPolicy` (all `core/movement/`), `StageCounterfactualService` (`core/realms/`). One result per Advance. Contact bids scale by Judgment and fear. Contact literals read config.
- Snapshot `flow.stage_explore`: `stop`, `travel_why`, `effective_steps`, `commitment_depth`, `presentation`, `party_preview[].id`. `flow.stage` adds `presentation`. No new action type.
- Save fields (additive, repaired on load): `last_stop`, `travel_why`, `last_effective_steps`, `last_commitment_depth`, `leg_start_length` (no writer yet, C1 rule, D-48).
- UI: `StageWhyCard`, `StageWhyText`, `StopGlyphs`, `StopMarkMotion`, party card in `EchoCardItem`, `StepProgressBar` (red X for lost steps), `RealmShell`, `StageExploreScreen`.
- New suites: `contact_cfg`, `stage_stop_ui`. `ContactBidScalingTests` registers under `conversation_repair`.

## 2. Decisions recap (full log: `decisions.md`, D-00 to D-65; ANSWERS #81, #82, #83)

Earlier decisions (D-00 to D-59) are in `decisions.md`. Key ones: three phases and one PR each (D-01). Directive-only influence (D-09). The why shows on demand with a persistent stop mark (D-12, D-32). Target screens 1280x720 and 1920x1080, touch-first (D-39). Tunables live in config (ANSWERS #83).

Decisions since the play tests:

| ID | Decision |
|---|---|
| D-60 | Play-test findings. Advance is ready again when the walk ends (about 0.75 s); stop beats never block a click. Step row crosses out every unusable step. Keep the live look. Why card opens above the tapped glyph, card or chip. Process rules added (LESSONS #36, #37). |
| D-61 | The glyph is always on a card. The chip became a party card. |
| D-62 | Party card details: compact (about 168 x 58), blue token "P", 32 px gap, glyph top-left, pinned first, only Echo cards scroll. |
| D-63 | Party card approved. A tap on the party token with no stop mark opens the last journey entry. The why card opens centred above the tapped card. |
| D-64 | Lost-step cross stays a red X. Config key `chip_settle_seconds` keeps its name. Party card word is "The party". |
| D-65 | Keep V0. Bend variants V1 to V3 show no effect on who is named. Speed is fine (worst mean Advance 222 ms, worst 95th percentile 417 ms). |

## 3. File map (all in `docs/stories/v2-directive-002/` unless noted)

| File | What it is |
|---|---|
| `design.md` | The B+C design spec. |
| `decisions.md` | Decision log, D-00 to D-65. |
| `numbers.md` | Authored numbers (PROPOSED DEFAULT). |
| `backend-plan.md` | Slice plan S0 to S5 and the QA packages. |
| `timings-proposal.md` | Motion timings (starting values, D-57; the input-ready point was replaced by D-60). |
| `play-findings-report.md` | The 2026-10-14 play measurement behind D-60. |
| `bend-strength-proposal.md` | The bend matrix behind D-65. |
| `glyph-shapes.md`, `glyph-ai-prompts.md` | Glyph shape spec and prompts for Jeff's finished glyphs. |
| `mockups/v4/` | Party card sheets (D-62). |
| `follow-ups.md` | Open items and findings not in scope. Read it fully. |
| `new-story-drafts.md` | Drafts of V2-BOND-004 and V2-STAGE-010. |
| `slack-gate-options.md`, `route-character-options.md` | Evidence for D-48 and D-51. |
| `probes/` | Probe sources. Copy out and rename to `.gd` to run. |
| `handoff.md` | Phase A handoff. |
| `~/.claude/plans/jolly-cooking-crescent.md` | Approved plan. Read the last "Status addendum". |
| `data/ui/stage_why_text.json` | Why-card and stop text. Read directly by `ui/`. Jeff writes the final wording. |
| `assets/ui/stage_stop_glyphs/` | Draft glyphs (placeholders). |
| `docs/LESSONS.md` (#34 to #38), `AGENTS.md`, `ANSWERS.md` | Rules and recorded decisions. Never read `CONVENTIONS.md` or the GDD whole: use `docs/canon-index.md`. |

## 4. Next steps, in order

1. **Ask Jeff about the `AGENTS.md` edits** (he must say yes). Proposed edits:
   - Suite count 129 to the real count, and add `contact_cfg` and `stage_stop_ui` to the suite list.
   - Add `contact_cfg` and `stage_stop_ui` to the shard map text in `AGENTS.md`.
   - Change the responsive line to the 1280x720 base and 1920x1080 check (D-39). Today it says desktop may resize down to 960x540.
2. **Shard map in `scripts/run-tests-sharded.sh`:** it lacks `contact_cfg` and `stage_stop_ui`. This is a code-side file; assign it to an owning agent. Only the serial run is the gate (LESSONS #34).
3. **Notion** (show each edit to Jeff first, then write). Copy D-44 to D-65 to the V2-DIRECTIVE-002 page (D-25 to D-43 are already written). Update the story status.
4. **Mark PR #107 ready.** Jeff merges.
5. **Jeff's remaining work:**
   - Write the wording in `data/ui/stage_why_text.json` (placeholders marked `[Jeff's wording: ...]`).
   - Generate the finished glyphs (`glyph-ai-prompts.md`), then a `ui-ux-designer` swaps them in.
   - Tune timings in game (pulse peak, shake size, glyph overshoot).
6. **Advance label task:** the Advance label is blank on stage explore. It is a separate task (spawn_task chip `task_2e47501b`).
7. **Phase D** (combat expression, stop-short Directive cause) starts after B+C merges. Then V2-COMBAT-004 planning resumes.

## 5. Rules you must follow (Jeff's)

- **Working preferences** (`~/.claude/CLAUDE.md`): ask before assuming. Jeff designs, you coordinate. Backend before frontend. Every story ends with Docs + Commit. Write to Jeff in STE. STE does not apply to player-facing game text.
- **Repo `CLAUDE.md`:** agents default to sonnet. Opus is per call. Never `fable`. Do not spawn `game-orchestrator` as a subagent for single-discipline work. Agent questions reach Jeff through you (OPEN blocks). Re-check BLOCKED lines against the repo first. Ask one question at a time with `AskUserQuestion`.
- **ASSUMED lines** that change what Jeff sees or feels become questions before the next step (LESSONS #37). UI briefs carry a mockup checklist, and every UI step ends with a build-next-to-mockup screenshot (LESSONS #36).
- **Tests:**
  - ONE full mode only: serial. Alarm 3600, tool timeout 3700000, background, log to a file.
  - No subagent runs a long command (over about 2 minutes) or any full suite, including `qa-verifier`. A subagent ends with a RUN REQUEST. The main chat runs it.
  - Filtered runs: one per shell command, never two at once. `rm -rf /tmp/echoes-vnext-tests` first. Confirm a `Tests:` line.
  - Never use the filter `fingerprint`. Use `snapshot_fingerprint` or exact suite names.
  - Known red test: `movement_arbiter/avoid_overcommit_stays_proportionate`.
  - After any UI change, run the whole camera and pointer suite group.
- **Ask first:** `AGENTS.md` edits and Notion writes.
- **Never answer design questions for Jeff.** Player-facing wording is Jeff's.
- **Tunables live in config** (ANSWERS #83). Comments: write fewer (AGENTS.md rule 28).
- **Fixtures:** a typed parameter rejects duck-typed fakes (LESSONS #35).
- **Commits:** STE message. End with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. Create PRs with `gh pr create --body-file`.
- **Habits:** after an agent stops, audit the tree (`git status`, `git diff`) before you trust its report. Findings are not authorisation.
- **Tools:** `SendMessage` resumes a finished agent only if its transcript exists. The Notion tools are deferred: load them with `ToolSearch`.

## 6. Facts worth remembering

- Stage selection: `ActiveStageService.find_explore_target` (tiers 1 to 4). `StagePartyMovementAdapter.select_objective_target` ranks inside a slack envelope. The objective weight joins the pool (D-28, S1c).
- `ConfigService.get_directives_cfg` owns the Directive subtree read. `DirectiveService.resolve` is the accessor.
- The `_data_subtree` check `get_script() == ConfigService` keeps test subclasses working (LESSONS #35). Do not remove it.
- Naming works only when the model plan equals the real walk (D-55). It fired in 0 of 606 real Advances before the bend work, and 52% of proposed names are dropped by `confirm_walk` now (D-65).
- Save dirs: tests use `/tmp/echoes-vnext-tests`. Normal play uses `~/Library/Application Support/Godot/app_userdata/echoes-vnext/saves/`.
- The contact window has four old UI issues (D-22). They are a separate later story.
- Memory dir: `/Users/jeffreygyamfi/.claude/projects/-Users-jeffreygyamfi-Sites-echoes-vnext/memory/`.

## 7. Open items for Jeff (ask one at a time)

| # | Item | Recorded in |
|---|---|---|
| 1 | Player wording in `data/ui/stage_why_text.json`: why-card lines, stop kind names, terrain cause. | D-48, D-57 |
| 2 | Finished glyph shapes. Drafts are placeholders. | `glyph-shapes.md` |
| 3 | `AGENTS.md` edits (section 4 item 1). Need Jeff's yes. | D-39 |
| 4 | Dropped names: 52% of proposed names are dropped by `confirm_walk` (target 15% or less). Naming for calm and own parties is also open. Scope as follow-ups. | D-65, `follow-ups.md` |
| 5 | Scout number question: a calm party cannot change Scout's first plan. | `follow-ups.md` (slice S2e) |
| 6 | The unused key `pause_cap_per_advance`: keep or drop. | D-46 |
| 7 | The 60 ms snapshot rebuild has no owner. V2-INFRA-010 (Order 254.7) may take it. | `follow-ups.md` (QA package E) |
| 8 | Reduced-motion switch is a later story. The flag exists, default off. | D-57 O2 |
| 9 | Blank Advance label: separate task `task_2e47501b`. | this file |
| 10 | V2-BOND-004 and V2-STAGE-010 are Draft in Notion. Watch notes on the pool rule are on STAGE-010, STAGE-101, STAGE-102. | D-49, `new-story-drafts.md` |
| 11 | Phone measurement of the Advance tail. | D-57 O3 |
| 12 | Remaining notes. | `follow-ups.md` |

## 8. Briefs to re-use

- **Fix after a suite run (owning agent):** name the failing test, the cause and the file. One cause per fix. Opus if the cause is unknown. End with a compile check and a filtered run. No full suite.
- **Glyph swap (ui-ux-designer):** replace the draft files in `assets/ui/stage_stop_glyphs/` with Jeff's files, keep names, re-import, run the `stage_stop_ui` suite and the camera and pointer suite group.
- **Wording swap (ui-ux-designer):** put Jeff's text in `data/ui/stage_why_text.json`. Do not write wording yourself.
