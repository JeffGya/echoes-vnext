# V2-ITEM-001b: running handoff

Written in STE. Keep this file current: update the "State" and "Next" sections after every step. Last update: 2026-11-13, after Step 0 commit and C0 dispatch.

## Where things are
- Branch: `claude/echoes-v2-item-001b-134dda`. Worktree: `/Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/v2-economy-004-item-costs-f68f4c` (the folder name says economy-004; the branch is 001b).
- Commits on the branch after `main` (`e326f315`, PR 130 merged): `253f05fc` design record and mockups; `30c528fd` design document, pick numbers record, follow-ups, decisions D-57 to D-62. Nothing pushed. No PR open. Jeff says when to push or open a PR.
- The approved plan: `/Users/jeffreygyamfi/.claude/plans/atomic-snacking-cat.md` (read it first). It holds the backend steps C0 to C12, the UI steps U1 to U12, the debug scene menu, the unwired register, probes, the test plan with exact debug commands, and the three-PR split.
- The design record: `decisions.md` (D-01 to D-62; later decisions win), `pick-numbers.md` (D-12 numbers), `follow-ups.md` (unwired register), `docs/inventory-and-items-design.md` (living design document, below the GDD), `ANSWERS.md` #91 (Echo decisions follow one readable pattern) and #92 (design starts with research on comparable games).
- The UI contract: `docs/visual-plans/pickup-event/pickup-event-playable.html` (approved by playtest, D-36). The art kit is `art-kit.html` in the same folder.
- Session scratchpad files (not in the repo, may vanish): `/private/tmp/claude-501/-Users-jeffreygyamfi-Sites-echoes-vnext--claude-worktrees-v2-economy-004-item-costs-f68f4c/c67e8351-5069-4d32-85d8-8e4439d80c80/scratchpad/` holds `design-rules-v2.md` (older than decisions.md; decisions.md wins), `feel-round-2.md`, `art-round-1.md`, and `pp/` (mockup build parts and tests). If the scratchpad is gone, use the repo files only.

## The design in one paragraph
After a won fight with finds, an event plays on the combat board before Resolve (snapshot type `flow.pickup`, a phase of the encounter, not a machine state, D-58). The finds count is a rolling chance by encounter rank, capped by realm scale (D-46 to D-51). One Echo is drawn with equal chance from the Echoes that did not fall; a pointer shows it (D-05, D-21). The chooser scores the finds by its own traits (D-06, D-12); a frozen chooser takes nothing and no swap is offered (D-39, D-43). Items show as hidden icons and are revealed when chosen (D-37, D-45). Items go into the Travel pack; an item that does not fit is held up near the Echo (D-41, D-55). The Keeper has one swap per path, only when the pack is full, and it may drop any pack item (D-27, D-28). Details float next to any visible item (D-25). The Directive decides the "Leave these behind?" prompt (D-35). Reaction is a class only; the emotion effect is a later story (D-29, D-33, D-34). Items are placed in a simple row; real placement is a later story (D-52). Jeff reviews ALL copy at the end (D-56).

## State
| Step | State |
|---|---|
| Step 0 records | DONE, committed `30c528fd` |
| C0 characterization tests (`tests/PickupCharacterizationTests.gd`, suite `pickup_char`, 11 tests) | DONE and committed (see git log, 'V2-ITEM-001b C0'). `tests =pickup_char` 11 of 11; `pending_result` 10 of 10; shard map check OK (147 suites). QA (qa-verifier) holds after fixes: M1 and N1 (fear_base rows added: `fear_base` must not be dropped and the status must read the LARGER of fear and fear_base), L4 (path-end guard). Open from QA, for later steps: L1 (order inside the ending dispatch not pinned: C9 needs its own test that the hook sits after the bond and Thread block), L2 (the pinned win is one synthetic case: rank S, no fallen Echo; C9 should add a win with a fallen Echo and an objective fight), L3 (`AGENTS.md` still says 146 suites; the runner has 147: fix in C12; the shard13 `est 100 s` is stale: add about 17 s). |
| C1 (finds config, `FindsRules`, validator; opus) | DONE and committed (see git log, 'V2-ITEM-001b C1'). `finds_rules` 11 of 11; `inventory_save` 15, `snapshot_fingerprint` 2, `pickup_char` 11 green; shard map OK (148 suites). QA found test gaps (M1 settle test could not fail, M2 nine validator branches untested, L1 cap above base list). Fixed; QA's mutations P4 and P7 to P13 now turn red. Facts for later: `FindsRules.NO_CAP` is -1 (C6 must read it as no cap); count = number of independent slot hits; `validate_finds` is test-only, not called at load; key `first_find_floor_rank` is "C"; the proof that a finds roll leaves a settlement unchanged belongs to C6/C9. Open for follow-ups: validator accepts floor rank S, floor 0 and an "F" modifier key (QA L3). |
| C2 (shared `state_ends` extraction) | DONE and committed. `EmotionStatusLean.state_ends(actor, composure, table, exponent, dampen_scale)`; `BehaviorArbiter._state_ends` keeps the empty-table and exponent checks and calls it. Moves nothing: `pickup_char` 11, `behavior_arbiter`, `arbiter`, `morale`, `felt_state`, `movement_arbiter`, `behavior_char` green; breaks (swap afraid/bold, unsoftened bold) go red. C4 must validate the afraid exponent itself (`BehaviorArbiter.is_valid_afraid_curve_exponent`). |
| C3 (Directive `confirm_leave_items`) | DONE and committed. `DirectiveService.confirms_leave_items(directives_cfg, id)`; schema key optional bool; fallback registry carries the flag; suite `directive_leave_flag` 4 tests; shard map OK (149). QA read-only: no high finding; M1 and L1 fixed. The reader has no production caller yet (C8/C9 wire it). Field name is in Q14 of the design document as a proposal; read as accepted. |
| D-63 | P2 pass line approved and recorded in decisions.md. |
| C4 (pick config, `PickupPick`, `validate_pick`) | DONE and committed. Numbers match pick-numbers.md (checked by script). `pickup_pick` 16 tests; 15 deliberate breaks red after QA fixes; `expr` 39, `calling_behavior` 5, `passive` 6, `leadership` 21, `divergence` 17 green; shard map OK (150). Traps for C5: chooser `actor` must be an `EchoActor.from_echo` view (a raw roster Echo reads morale 50, fear 0, so nobody freezes); `find_id` sorts as a String, so ids need zero padding; tie goes to the LOWER find_id (D-06); `reason` gives identity, sense, state or froze (no "fit"); an invalid afraid exponent gives no state points and no freeze; the id lists in `PickupPick` (callings, archetypes, vectors, traits, stats) are constants and need the same edit when one is added. OPEN for Jeff: an uncalled Echo (90% of births) has no Calling term; which statuses freeze at composure 0 (hollow, fraying, strained yes; pressed 0.487 no). |
| C5 to C12, U1 to U12 | NOT STARTED (C5 next) |

## Next (in order)
1. When the C0 agent reports, read its report and audit the tree (`git status`, `git diff`). It ends with a RUN REQUEST for the import. Main chat runs: `/usr/bin/perl -e 'alarm shift; exec @ARGV' 400 /opt/homebrew/bin/godot --headless --import --path /Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/v2-economy-004-item-costs-f68f4c`, then checks the tree. Then send the agent on (SendMessage) to run `tests pickup_char` (alarm 200, own `ECHOES_TEST_SAVE_DIR`, delete it first) and fix failures. Read the `Tests:` line; a filter that matches nothing is a false pass.
2. `qa-verifier` checks C0 (never the builder).
3. Commit C0 (STE message, attribution line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`). Update this handoff.
4. C1 to C5 (pure layers; opus for C1, C5 draws; C2 sonnet build, opus verify). Then C6 to C8. That ends PR 1. Run the full sharded suite once before PR 1 (main chat; CI also runs it). Tell Jeff; he says when to open the PR.
5. PR 2: C9 to C12 and UI U1 to U7. PR 3: U8 to U12 and the end copy review.
6. After every step: update `docs/inventory-and-items-design.md` status tags where a section turns BUILT, and the unwired markers and `follow-ups.md`.

## Rules to keep (Jeff's working style)
- Write to Jeff in STE with "Done / Next / Need from you" and an OPEN block (ASSUMED / BLOCKED). Show every proposal in the chat in full before asking him to decide (ANSWERS #90). Ask one question at a time with the full picture (interview style).
- Design leads and scope comes at build. Every design brief names a research step on comparable games (XCOM, Gears Tactics, Tomodachi); only `sr-game-designer` has web tools.
- Roles only: `mechanics-developer` (`core/`), `ui-ux-designer` (`ui/`), `mid-game-designer` (numbers), `sr-game-designer` (design, research), `sr-game-artist`, `game-feel-developer`, `technical-artist`, `qa-verifier`. Never Explore or general-purpose agents. Builders never verify their own work. Long runs (over 2 minutes), `godot --import`, screenshots and the full suite belong to the main chat. Agents run short filtered suites only with their own `ECHOES_TEST_SAVE_DIR`.
- Never reorder an existing RNG draw. Never touch the `stage.settle` stream. Tunables in `data/balance.json` (ANSWERS #83). No save repairs (ANSWERS #88). Never change the GDD. Player text is AGENT-WRITTEN (proposal) until Jeff's end review (ANSWERS #89, D-56); never "home" or "stage" (ANSWERS #86).
- Commit each verified step; no push; no PR until Jeff says. No Notion write without his yes. Story codes come from the CSV and must be checked in Notion before any row changes.
- Jeff's debug request: an F1 scene menu with two scenes (Pickup event now; Arm finds for the next real fight). Precondition errors, setup applied only with his yes or shown as commands (D-61, plan section "Debug scene menu").

## Corrections found by C0 (use these in C6 and C9)
- The three `clear_discard_used` sites are: `StageSettlementService.gd:143` inside `settle` = PATH END (stage cleared); `VentureController.gd:369` inside `handle_return_home` = EARLY LEAVE; `ActiveStageService.gd:541` inside `lose_unsettled_packs` = DEFEAT. The plan labels them differently. Use this mapping.
- A real won fight in a test: the helper `CombatRoundtripIntegrationTests._setup_two_combat_situations` starts in `flow.splash`, not `flow.stage_explore`; `stage.engage_situation` still enters the encounter. A C9 test that needs the path state can start from `VentureCharacterizationTests._setup_explore_env` (single starter Echo). A test must set `last_situation_id` (an Advance does it in play; `engage_situation` does not), or no fight row is written.
- The one dispatch that ends a won fight (`combat.next_actor`) does it all: sets `ectx.final_snapshot` (type `flow.resolve`), captures the pending result, leaves the machine in `flow.encounter`, writes the fight row. The Resolve action is `cta.continue = {type: flow.go_state, to: flow.stage_explore}`. After it, the machine is in `flow.stage_explore`, `encounter_ctx` is null, and the pending result is consumed.
- Item 7 pin values (win with no finds), first 16 hex of sha256: snapshot data `242608323b62fc1a`, stage record `fb98e3b8604d9f01`, inventory `3d73c8662138083f`, pending result `5aad8910d61b2cc1`, `meta.t` 63. C9 must keep these byte-identical.
- `_state_ends` pinned table is in `tests/PickupCharacterizationTests.gd` (10 statuses x composure 0, 0.5, 1). C2 must not move it.

## Known facts that bite
- The F1 console and suite registrations live in `ui/AppRoot.gd`; a minimal backend edit there is approved (D-60).
- The dispatch guard test `EXPECTED_ACTION_COUNT` is 83 today and becomes 90 at C8 (seven new labels).
- The pre-existing gap: after a reload on the Resolve card the win emotion drift is skipped. Not fixed here (follow-ups row 13).
- The lowest win rank today is C; D is unreachable. Freezes will probably be rare (probe P3 measures).
- Real play never opens the event until ITEM-002 gives real finds. Only debug `event` and `arm` reach it. One test (`pickup_flow`, C9) must drive a real won fight with armed finds.

## Open items for Jeff
- Pass line for the Standing 1 against Standing 9 probe (D-09): needs a number from `mid-game-designer`, approved by Jeff, before C4 closes.
- What Resolve shows beyond `data.pickup_result` (D-16).
- Real emotion plus and minus sizes (later story), the placement story, ITEM-002 catalogue, and Notion rows and notes (his yes).
- Whether to start a short note on the Notion rows of ITEM-001 and ITEM-002 pointing at the design document (his yes).
- End review of ALL copy (D-56).
