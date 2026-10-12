# V2-DIRECTIVE-002 — Session handover (written 2026-10-11, before a context compaction)

Read this first after the compaction. Then read the files in section 3. Written in Simplified Technical English.
You are the **game orchestrator** (archetype: `.claude/agents/game-orchestrator.md`). You coordinate. You do not implement. Jeff is the designer and decides scope, numbers and player-facing wording.

## 1. Where we are

| Item | State |
|---|---|
| Story | V2-DIRECTIVE-002 (profile-sensitive Directives). Notion: Ready, Spec State **Mostly Locked** (set 2026-10-11). Page id `339c3d1e-de92-8103-9faa-cf423c3e61ba`. |
| Phase A | **DONE and merged**: PR #106, main commit `2779e08`. Accessor, legacy-key bug fix, data-only Directives, guard, save repair. Full serial suite 2043 total, 2042 passed, 1 failed (the known red test). |
| Phases B+C | **Design stage.** Design document written and revised. Waiting for Jeff's approval. No numbers authored. No backend code written. |
| Phase D | Not started. Waits for B+C. |
| Original goal | V2-COMBAT-004 (Keeper tactical guidance). Parked. Jeff switched to DIRECTIVE-002 first because COMBAT-004 depends on it (and on V2-INFRA-004, which waits for the item chain ITEM-002 then ITEM-003). COMBAT-004 recon is saved in the old plan and memory. |
| Branch | `claude/v2-directive-002-phase-bc`, created from `origin/main` (`2779e08`). Upstream was unset on purpose, so a plain `git push` cannot hit `main`. Push with `git push -u origin HEAD`. |
| Worktree | `/Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/v2-combat-004-plan-1b1efd` (the name is old; the branch is the B+C branch). |
| Uncommitted | `ANSWERS.md` (#83), `docs/stories/v2-directive-002/decisions.md`, and new files: `design.md`, `new-story-drafts.md`, `mockups/` (HTML, PNG, README). Nothing is committed on this branch. **Commit only when Jeff asks.** |

### Agents that were in flight when this was written (both finished before the compaction)
1. `sr-game-designer` (id `a0e1502734c87e19d`): **DONE.** `design.md` is final (453 lines), status "Ready for Jeff's approval", decisions D-25 to D-40 applied: touch-first block and screen sizes in section 8, saved journey entry in section 8a (assumed name `travel_why`, mechanics-developer decides), "Directive" cause, crossed-out step bar, RUN REQUEST outline for the pause measurement in section 11, section 12b is a short "Still open" list of 8 items, section 13 row 16 records the AGENTS.md 960x540 open item. Both in-flight agents are finished: nothing to wait for.
2. `sr-game-artist` (id `a540d94f456ad8614`): **DONE.** `mockups/stage-stop-marker-mockup.html`, `README.md` and the preview PNG are revised: option 1 is the main sheet (options 2 and 3 collapsed as "not chosen"); views 1920x1080, 1280x720, phone landscape 1600x720 (notch, safe bands) and tablet 1440x1080; touch-map toggle; crossed-out step bar in calm, shaken and mid-walk; the why card has a Directive-cause variant and a named-Echo variant. Artist findings: the marker pole is near vertical at 1280x720 and up only if the token and the marker head are one tap target (the alias); two separate targets need a 56-unit head offset and then the ring overhangs the cell at 1280x720. The pulse shows only on stop kinds that can name an Echo (met, spotted, paused). Assumptions to confirm: baseline of six steps with two lost is a placeholder; phone safe insets are typical values. Three small details still open for Jeff: faint ring after the pulse, terracotta for combat only, last-journey entry place.
**Check the files on disk** (`wc -l design.md` should be about 453, top status line "Ready for Jeff's approval", `ls mockups`, `git status`) and then present both to Jeff if he has not seen the final versions.

## 2. Decisions (full log: `decisions.md`, D-00 to D-40; ANSWERS.md #81, #82, #83)

Phase A and plan (D-00 to D-24) are recorded in `decisions.md`. The decisions that shape B+C:

| ID | Decision |
|---|---|
| D-01 | Three phases, one PR each: A (done), B+C, D. C and D never re-record the same values in parallel. |
| D-02 | Hazard addendum out. Seam only: route scoring reads an exposure input that is empty. |
| D-03 | Profile inputs: Calling family, virtue domains via the identity state only, Standing and Judgment, fear, morale. Bonds as interrupt. **D-26 amends it:** bonds also enter stage through Judgment. |
| D-04 | Party profile: bounded modifiers plus counterfactual naming (an Echo is named only if removing them changes path, steps or stop). |
| D-05 | Revive `exposure_tolerance` (0.3 Scout, 0.8 Seek) as the one exposure input. |
| D-06 / D-14 | Scout Carefully and Seek Signs only. A new Directive is data plus tests, no logic change. Unlock stays "always". |
| D-07 | `reposition` and `regroup` goal sources belong to V2-COMBAT-004. |
| D-08 | Contrast required at every Standing (tests at Standing 1 and 6). |
| D-09 | Directive only: no shared influence function, no ping code. |
| D-10 | Phase D registers a Directive cause in stop-short. |
| D-11 / D-16 / D-24 / D-30 | Contact bids scale by Judgment and fear. Wire the resonance bonus: +0.1 (PROPOSED DEFAULT) on the turn score of every conversation under Seek Signs, before the 1.2 clamp. Rename key to `conversation_resonance_bonus` (data entry, `CONTACT_EFFECT_KEYS`, tests, docs in one change). |
| D-12 / D-32 | Visible result: stage "why" + visible route/stop difference. The why is **on demand only** (tap the stop marker; party token is an alias; no button). A stop marker stays after every Advance. The on-demand surface is the persistent journey entry. |
| D-13 / D-27 | `step_budget` is the baseline. Readiness (fear/morale bands) only LOWERS effective steps. |
| D-15 / D-19 | A malformed Directive entry aborts config load. Degenerate `intent_weights` stays a warning. |
| D-18 / D-34 | Picker shows one description field from config. **Jeff's final lines** (go into `data/balance.json` `data.directives.<id>.description` by script copy, character for character, in the data step): Scout: "Watch your step before you move. Proceed with patience. Do not ask more than needed and return back safely" / Seek: "There is much to discover. Push ahead, stay alert but beware the danger. Wanting too much can cost." A test checks config text equals picker text. |
| D-25 | Bond interrupt: seam only. New **Foundation** story "Stage bond interrupt" (drafted as V2-BOND-004). |
| D-26 | Stage Judgment includes bond support, same as combat (amends D-03). ANSWERS #82 needs a dated amendment note (not done yet). Stage test fixtures use real bonds. |
| D-28 | The `objective` weight (Scout 1.2, Seek 1.6) joins the Tier 2 weighted pool inside the slack envelope. Tier 1 no longer pre-empts every find. Scout prefers nearby intel; Seek prefers the objective but may take a much closer find first. An objective outside the envelope is delayed, not lost (Tier 4 stays). Moves stage fingerprints. |
| D-29 / D-36 | Scout stops for any new find; Seek only for objective or hostile. Two stop kinds kept with different internal names (`spotted_ahead`, `paused_to_read`; `arrived_at` for target reached; `interrupted` for met something). Pause cap decided by measurement. |
| D-31 | Bridges NOT counted as exposure in B+C (default). New story "Stage hazards and exposure" (drafted as V2-STAGE-010) owns hazards and this question. |
| D-33 / ANSWERS #83 | Reactive-bid threshold 60 moves to config (also the copy in `StageExploreSnapshotBuilder.gd:191`). Project rule: tunables live in config unless a documented reason. |
| D-35 | Identity leans reuse `MovementStyleService` tables. |
| D-37 | Walk time 0.5 s moves to config. `game-feel-developer` measures and proposes a timing. Jeff approves after seeing it. |
| D-38 | Items 1-3: picture first (option 1 after the mockup: path, six stop-marker shapes, portrait pulse); short beat for a shaken party; repeat filter on naming (journey entry only). |
| D-39 | Target devices: smartphone, tablet, laptop, landscape mostly, at least 1080. Design and check at **1280x720 logical and 1920x1080**. Drop 960x540. Touch-first. **AGENTS.md still says 960x540 minimum: open item for Jeff, not edited.** |
| D-40 | Items 4-16: copy rule (fear/morale never a fault); measure pauses per Advance and why-frequency before authoring values; one visible Seek payoff; show "Directive" as the cause when it alone decided; step bar shows baseline with lost steps crossed out (snapshot carries baseline and effective steps); tap-the-marker trigger; sr-game-artist names tint tokens, mid-game-designer authors data keys, ui-ux-designer deletes `_label_for_directive` and `_TINT_BY_ID`; other stage-screen timing literals move to config in one pass; the config sweep covers only lines B+C edits; the journey entry IS SAVED (additive save field, repair rule, opus save pass). |

## 3. Files that hold the specs (all in `docs/stories/v2-directive-002/` unless noted)

| File | What it is |
|---|---|
| `design.md` | **The B+C design spec** (about 450 lines when finalised): six dials, profile inputs, party aggregation, capacity, contact bids, contrast cases, what the player sees, failure modes, seams, test plan skeleton, hard-coded tunables list (10.1), resolved decisions, short "still open", contradictions found. No numbers. |
| `decisions.md` | Decision log D-00 to D-40 with questions and answers. |
| `handoff.md` | Phase A handoff (what changed, how verified). |
| `follow-ups.md` | Open items and findings not in scope (contact-window issues = separate story, QA nits, picker wording, etc.). |
| `new-story-drafts.md` | Drafts of V2-BOND-004 "Stage bond interrupt" (Foundation, Order 254.5) and V2-STAGE-010 "Stage hazards and exposure" (Order 254.6; Foundation recommended, Expansion alternative). Property tables marked NOT WRITTEN. |
| `mockups/stage-stop-marker-mockup.html` (+ `README.md`, preview PNG) | Visual mockup of the stop markers, portrait pulse, why card, step bar. Style follows `docs/stories/v2-combat-005/mockups/stop-short-*.html`. |
| `~/.claude/plans/jolly-cooking-crescent.md` | The approved plan (phases A, B+C, D, test plan, docs pass). Read its "Status addendum" at the end. |
| `ANSWERS.md` | #81 (Directive data-only to add), #82 (profile inputs; needs D-26 amendment note), #83 (tunables in config). |
| `docs/movement-model.md`, `docs/LESSONS.md` (#34, #35), `AGENTS.md` | Canon and rules. Never read the GDD or CONVENTIONS whole: use `docs/canon-index.md`. |

## 4. Next steps, in order

1. **Collect the two in-flight results from disk** (section 1). Audit: `design.md` has no 960x540 left, status "Ready for Jeff's approval", journey-saved section present, "Still open" list short; mockup has the three required states.
2. **Present to Jeff** (send files with `SendUserFile`): final design, revised mockup. He approves the design. Then set Notion Spec State to **Locked** (ask first).
3. **New stories.** Jeff must approve `new-story-drafts.md`, choose Foundation or Expansion for the hazards story, and confirm the Notion writes: create the two rows and add a link to V2-STAGE-010 on the V2-COMBAT-004 page. The Notion update tool is deferred: load it with `ToolSearch select:mcp__3e8ac948-1486-44df-88b6-e7742be5c06f__notion-update-page`. Create-pages tool also needs loading. Each write needs Jeff's yes.
4. **Small doc fixes to do** (ask or just do, they are docs): dated amendment on ANSWERS #82 (D-26 changed it); note in `docs/movement-model.md` 11.12 that D-12 narrows the preview; Jeff's decision on AGENTS.md 960x540.
5. **Numbers.** `mid-game-designer` authors all numbers as PROPOSED DEFAULT in `data/balance.json` after Jeff approves the design. Grep where `core/` reads each key first. Includes: the picker text copy (use a `haiku` script, equality check), `conversation_resonance_bonus` rename, reactive-threshold config key(s) (all the different 60s listed in design 10.1), timing keys, bounds, replan and candidate caps, bid scaling curves, objective weights tuning.
6. **Measurement (run through the main chat).** `mechanics-developer` builds a probe. It counts pauses per Advance (Scout and Seek) and how often a why would show, on shipped stage boards. It ends with a RUN REQUEST (command, timeout, alarm, duration, files edited and restore trap, restore check, output to read). **You run it**, read the raw output, check restores with `cmp`. The numbers set the pause cap.
7. **Backend** (`mechanics-developer`, sonnet; `opus` for: counterfactual determinism, the save-schema change for the journey entry, moved-hash attribution). Backend before frontend. Order of serial re-records (one cause per step): (1) exposure map and one-result refactor with Directive logic unchanged, (2) profile bends, (3) stop kinds, (4) bid scaling, (5) resonance bonus. Feasibility checks first (design section 12 end): counterfactual cost, per-step reveal vs the single reveal sweep (`StageExploreTurnService.gd:309`), stop tokens vs `MovementResult.STOP_REASONS`, max party size, lowest-id tie-break pin, bond edges path for stage Judgment, `TIER_PRESSURE_SOURCE` once the objective is in the pool, party-size literals.
8. **Frontend** (`ui-ux-designer`; `game-feel-developer` for timing and the shaken beat; `sr-game-artist` for tint tokens and glyph; `technical-artist` only if a shader is needed): stop marker layer authored in `.tscn`, portrait pulse, crossed-out step bar, tap-the-marker why card, journey entry, label and tint from the Directive entry (delete `_label_for_directive` and `_TINT_BY_ID`), timing from config. Jeff approves game-feel timings after seeing them.
9. **QA.** `qa-verifier` reviews the combined tree (opus where two agents' work meets). Read-only plus short filtered runs only.
10. **ONE full serial run** by the main chat, then Jeff tests in game, docs pass, commit when asked, PR (one PR per phase), reply to Codex review threads (Auto-fix is on).
11. **Phase D** after B+C merges. Do not start earlier.

## 5. Rules you must follow (Jeff's)

- **Working preferences** (`~/.claude/CLAUDE.md`): ask before assuming; confirm before editing; explain in beginner-friendly STE; backend before frontend; Jeff designs, you develop; only improve existing code; every story ends with Docs + Commit; GDD is canon; **write to Jeff in Simplified Technical English** (short active sentences). STE does not apply to player-facing game text. Player wording is Jeff's: propose none.
- **Repo `CLAUDE.md`** (orchestration): agents default to sonnet; opus is per call; never `fable`; read the roster files; do not spawn `game-orchestrator` as a subagent for single-discipline work; questions from agents reach Jeff through you (OPEN blocks); re-check BLOCKED lines against the repo first; ask one question at a time with `AskUserQuestion`.
- **Session rules from Jeff:** NO subagent runs a long command (over about 2 minutes) or any full suite, **including `qa-verifier`**. A subagent ends with a RUN REQUEST. The main chat runs it. Filtered runs: one Godot process at a time, one run per shell command (the tool backgrounds a command after 120 s), `rm -rf /tmp/echoes-vnext-tests` first, confirm a `Tests:` line. **Run ONE full mode only: the serial suite.** Alarm **3600**, tool timeout **3700000**, background, log to a file, read `Tests:` line, exit code (142 = alarm killed it, not a pass) and start and end times (`.start` and `.end` files). Never run sharded AND serial (LESSONS #34). The known red test `movement_arbiter/avoid_overcommit_stays_proportionate` is expected until fixed.
- **Fixtures:** a typed parameter rejects duck-typed fakes (LESSONS #35). After changing a shared function signature, grep `tests/` for mocks and run every suite that references the symbol.
- **Never** commit, push, create or edit Notion rows, or change AGENTS.md without Jeff's yes. Notion writes: show the exact edit first.
- **Commits:** STE message, end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. Create PRs with `gh pr create --body-file <file>` (a heredoc inside `$(...)` breaks on macOS bash 3.2). After a PR opens use `mcp__ccd_pr__get_status`. "Auto-fix pull requests" is on: when a `<ci-monitor-event>` arrives, fix, verify, commit, push, reply on the thread with the required signature line, resolve the thread.
- **Scope:** findings are not authorisation. List QA findings to Jeff and ask before fixing. Adjacent findings go to `follow-ups.md`.
- **Tunables in config** (ANSWERS #83). Comments: write fewer, no history (AGENTS.md rule 28).
- **After an agent stops, audit the tree** (`git status`, `git diff`) before you trust its report.

## 6. Facts worth remembering (verified in code)

- Stage selection: `ActiveStageService.find_explore_target` (`core/realms/`, about lines 401-516), tiers 1-4; `StagePartyMovementAdapter.select_objective_target` ranks inside a slack envelope (nearest + max(2, 25% of nearest)), weight first then distance. `StageExploreTurnService.advance_turn` (`core/realms/`) re-plans every step and drops the result (`build_result`); the stage reveals content in one sweep after the walk.
- `data.directives.<id>` has 18 keys incl. `contact_effects` (optional). `ConfigService.get_directives_cfg(config_service)` owns the subtree read (typed parameter). `DirectiveService.resolve(save, directives_cfg)` is the accessor.
- `witness_resonance_bonus` has no reader yet (rename planned). Picker description is shown only in the picker. The travel snippet label is 480x60, top centre; `_TRAVEL_DURATION` is 0.5 s; snippet hold 3.0 s.
- Contact bids appear as a small diamond badge and a hint line on Echo cards in the contact window (`ui/overlays/realm/ContactModal`). The contact window has four known UI issues (raw calling ids, fourth card below fold, colour-only badge, weak contrast): **separate later story (D-22)**.
- Full serial suite takes about 53 minutes. Save dirs: tests use `/tmp/echoes-vnext-tests`; normal play uses `~/Library/Application Support/Godot/app_userdata/echoes-vnext/saves/`.
- Run the game windowed: `/opt/homebrew/bin/godot --path <worktree> --windowed --resolution 1600x900` (no `--headless`).

## 7. Open items for Jeff (collect and ask one at a time)

1. Approve the final design; approve the mockup (or ask for changes).
2. Approve the two story drafts; choose Foundation or Expansion for V2-STAGE-010; confirm Notion writes (create rows, link on COMBAT-004 page).
3. AGENTS.md 960x540 contract: keep or update (D-39).
4. The artist's three small details: does a faint ring stay on the portrait until the next move; is terracotta reserved for combat only; where does the last-journey entry sit.
5. Player wording for every line the design leaves open (the why card, stop kinds, journey cause line). Jeff writes it.
6. Game-feel timings (walk time, snippet timing, shaken beat): proposed by `game-feel-developer`, Jeff approves after seeing.
7. Notion Spec State to Locked after design approval.

## 8. Briefs to re-use if an in-flight agent's work is missing

- **Design finalisation (sr-game-designer):** apply D-38, D-39, D-40 and D-34 text to `design.md`; remove all 960x540; add the touch-first rule block; add the saved-journey-entry section (additive field, sanitised, lifetime proposal, repair rule, opus pass, tests); step bar baseline + crossed-out + both numbers in the snapshot; item 7 cause line "Directive"; replace section 12b with a short "Still open" list; status "Ready for Jeff's approval"; no numbers; under 450 lines.
- **Mockup revision (sr-game-artist):** write only under `mockups/`; option 1 main sheet; 1280x720, 1920x1080, phone-landscape with notch and safe edges, tablet; crossed-out step bar in three states (calm, shaken, mid-walk); keep six marker shapes, portrait pulse, why card with a "cause" slot; options 2 and 3 as a collapsed "not chosen" section; README lists reuse and open details.
