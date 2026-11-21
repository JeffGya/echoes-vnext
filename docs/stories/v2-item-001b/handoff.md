# V2-ITEM-001b: running handoff

Written in STE. Keep this file current. Last update: 2026-11-15, after the C12 build (not committed; the main chat runs the suites and the shard map check).

## Where things are
- Backend steps C0 to C12 are DONE after C12 is verified and committed. C0 to C8 are in PR 131 (merged). C9 to C11 are committed locally. C12 is built and waits for the main chat (import, suite run, shard map check) and for QA.
- Branch: `claude/echoes-v2-item-001b-pr2`. It is LOCAL: Jeff keeps it unpushed. Worktree: `/Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/v2-economy-004-item-costs-f68f4c` (the folder name says economy-004; the story is 001b). Jeff says when to push or open PR 2.
- Next: the UI steps U1 to U12 (`ui-ux-designer`). PR 2 = C9 to C12 and U1 to U7. PR 3 = U8 to U12 and the end copy review (D-56).
- Real play never opens the event until V2-ITEM-002 gives real finds. Only the debug producer (`inventory produce event` and `arm`) and the debug scenes reach it. One test (`pickup_flow`) drives a real won fight with armed finds.
- The approved plan: `/Users/jeffreygyamfi/.claude/plans/atomic-snacking-cat.md` (rows C0 to C12, U1 to U12, test plan, three-PR split). It can be stale in two places: the plan says U8 uses `pickup.swap.apply`; the real actions are `pickup.swap.start`, `pickup.swap.pick`, `pickup.swap.confirm` and `pickup.swap.cancel`. The plan also names `PickupEventPlan.gd` for register row 12; the real file is `PickupSnapshotBuilder.gd`.
- Records: `decisions.md` (D-01 to D-67; later decisions win), `pick-numbers.md`, `follow-ups.md` (the unwired register), `docs/inventory-and-items-design.md` (status tags now BUILT for the backend), `CONVENTIONS.md` section "Pickup event (V2-ITEM-001b)" (the contract), `docs/resolve-snapshot-block-spec.md` (block 18), `ANSWERS.md` #91 and #92.
- The UI contract: `docs/visual-plans/pickup-event/pickup-event-playable.html` (approved by playtest, D-36). The art kit is `art-kit.html` in the same folder.

## Corrected facts (use these; older notes in the history are wrong)
| Fact | Source |
|---|---|
| The P2 pass line is approved: M1 15% to 60%, M3 at least +0.5, M4 at least 70%. | D-63 |
| An uncalled Echo has no Calling term. `freeze_at` stays 0.5: hollow, fraying and strained freeze at composure 0; pressed (0.487) does not. | D-64 |
| A placeholder `NEW "<title>"` in a marker is allowed where no Notion story code exists yet. | D-65 |
| The pending result keeps `terrain`, `placement_seed` (String) and `bounds { w, h }` as top-level keys, only when held behind an event. | D-66 |
| `sense_base` is 0.0 (was 0.3). `worth_weight` stays 6. Probe P2 at full size: M1 17.1%, M3 +0.609, M4 99.0% (a narrow pass). | D-67 |
| The reaction key for "no effect" is `none`, not "neutral". The design document is fixed. Values: `plus`, `none`, `minus`. | `PickupCase.gd`, C12 |
| `realm.seed` is a 63-bit int saved as a JSON number. After a reload it can lose digits. Every seeded stream that reads it is affected (finds roll, chooser draw, pointer). Pre-existing and project-wide. Needs an opus determinism check. | register row 17 |
| The event opens in the fight-ending dispatch. The win relief (fear -5, morale +10) runs in a LATER dispatch. A chooser therefore freezes on its fear from BEFORE the relief. Built as is. Jeff decides. | register row 18, probe P3 |
| Probe P3 (100 real fights): a chooser freezes exactly when its status at the event is strained or worse. The rate in a real campaign is not measured. | register row 16 |
| A reload during the event skips the win steps (emotion drift, vow discovery check, ally field clear), because the machine is then in RESOLVE. Pre-existing for the Resolve card; same for the event. | register row 13 |
| The dispatch guard is 92 labels: 83, then 90 at C8 (seven pickup labels), then 92 at C10 (two debug labels). | `FlowTransactionTests` |
| The runner has 158 registered suites: 157 in 13 shards and 1 merge suite (`movement_fallback`). | `scripts/test-shard-map.sh` |
| The three `clear_path_marks` sites: `StageSettlementService.gd` (path end), `VentureController.gd` (early leave), `ActiveStageService.gd` (defeat). | C0 |

## The design in one paragraph
After a won fight with finds, an event plays on the combat board before Resolve (snapshot type `flow.pickup`, a phase of the encounter, not a machine state, D-58). The finds count is a rolling chance by encounter rank, capped by realm scale (D-46 to D-51). One standing Echo is drawn with equal chance; a pointer shows it (D-05, D-21). The chooser scores the finds by its own traits (D-06, D-12); a frozen chooser takes nothing and no swap is offered (D-39, D-43). Items show as hidden icons and are revealed when chosen (D-37, D-45). Items go into the Travel pack; an item that does not fit is held up near the Echo (D-41, D-55). The Keeper has one swap per path, only when the pack is full (D-27, D-28). Details float next to any visible item (D-25). The Directive decides the "Leave these behind?" prompt (D-35). Reaction is a class only (D-29, D-33, D-34). Items are placed in a simple row (D-52). Jeff reviews ALL copy at the end (D-56).

## What the UI steps need (the backend contract)
- Snapshot shape: the header of `core/state/flow/states/venture/PickupSnapshotBuilder.gd`. Data keys include `order`, `pick_index`, `selected`, `swap.targets` (keyed from both sides) and `swap.dropped`. Core emits keys and ids, never player text.
- Actions per phase: `intro` has `overlay.skip`. `idle` has `cta.continue` and, when a swap is offered, `cta.swap`. `swap_pick` has `back`. `swap_preview` has `cta.confirm` and `back`. There is never `nav.back`.
- Action types: `pickup.skip`, `pickup.continue`, `pickup.swap.start`, `pickup.swap.confirm`, `pickup.swap.cancel`. Per-row (NOT in `snapshot.actions`): `pickup.select` `{ find_id | pack_id }` and `pickup.swap.pick` `{ id }`.
- Every action is refused with `error_outcome(reason)` and one `inventory.pickup.denied` log when there is no event (`no_event`), the last snapshot is not `flow.pickup` (`not_pickup`) or the event ended (`ended`).
- Session (volatile, never saved): `{ phase, swap_origin, swap_target, selected }` in `FlowContext.pickup_session`. `intro` shows only on the first publish. A reload resumes at idle.
- Continue publishes the held Resolve card (live) or the stored card (after a reload) with `data.pickup_result` (block 18). The end mark is `stage.pickup.phase == "done"`.
- After a reload the board redraws from the pending result keys `terrain`, `placement_seed` and `bounds` (D-66). Old results without them get the default board.
- Debug scenes: `debug.pickup.scene.check` (changes nothing) and `debug.pickup.scene.apply` (needs `confirm: true`). Results come back as LOG LINES (`debug.pickup.scene.check`, `.apply`, `.denied`, `.frozen_not_reached`). For U11a (the F1 menu): read these lines the way the recipe command does. Both scenes need the path view.
- Known, not fixed (C10): `armed_kept` reasons `chooser_gone` and `zero_count` log as `no_event`; a quit during an event-now event goes to the Sanctum; the debug gate test checks text order only.
- Traps from earlier steps: the chooser `actor` must be an `EchoActor.from_echo` view; `find_id` sorts as a String (zero padding); a tie goes to the LOWER `find_id`; `order`, `taken` and `left` hold find ids in the saved record. Never name a method like an `Object` method (`_set` clashed). Grep every suite run for SCRIPT ERROR as well as the `Tests:` line.

## Unwired register (summary; the full table is `follow-ups.md`)
Rows 1 to 18. Every row has a Target cell with a story code, a `NEW "<title>"`, or `none` and a reason. Rows 8, 14 and 15 are EXEMPT from markers: no code site (8: materials need crafting; 14: a UX redesign; 15: debug-only code that stays). Every other row names `File.gd` sites and has a `# UNWIRED (target: ...)` marker there. The suite `pickup_unwired` fails when a marker and the table disagree, when a table line is not a row, or when a Target story code or title is carried by no marker. Row 2 has a marker in the builder (`name_of`); the UI pack-strip names (`ItemUiText` in `ui/`) have no marker because `ui/` is not edited in the backend.

## What Jeff must still decide
1. Create the Notion rows for the six `NEW` titles below (and decide on the two proposed titles without a marker). Check every real story code in Notion first: the CSV can lag.
2. Row 18: should the event open AFTER the win relief? Today a chooser freezes on its fear from before the relief. This changes the order of two dispatches, so it needs a design call.
3. Row 17: the `realm.seed` fix (new story). It needs an opus determinism check.
4. Row 13: who owns the skipped win steps after a reload (no story).
5. What Resolve shows beyond the `data.pickup_result` block (D-16).
6. The real size of the emotion plus and minus (the reaction story). Open question Q4 in the design document.
7. Constants `LAPS_MIN`, `LAPS_MAX` and `SEVERE_FROM` are now in `data.inventory.pickup`. An upper bound for laps and a limit for `severe_from_status` are still Jeff's numbers.
8. Whether to write short notes on the Notion rows of V2-ITEM-001, V2-ITEM-002 and the other target stories (his yes first).
9. The end review of ALL player-facing copy (D-56).

## `NEW "<title>"` story rows to create in Notion
The suite `pickup_unwired` prints this list from the markers. Titles marked "proposed" were chosen by the builder; Jeff names them. There are 7 distinct titles with markers.
| Title | Marker site (file:line at C12) | Register row |
|---|---|---|
| `NEW "Pickup placement on the board"` | `PickupEventService.gd:135`, `FindsRules.gd:24` | 3, 11 |
| `NEW "Pickup reaction effect"` | `PickupEventService.gd:139` | 4 |
| `NEW "Win steps after a reload"` (proposed) | `FlowResolveState.gd:39` | 13 |
| `NEW "Pickup intro short forms"` (proposed) | `PickupSnapshotBuilder.gd:25` | 12 |
| `NEW "Pickup tuning from real play"` | `PickupPick.gd:51` | 16 |
| `NEW "Realm seed survives a save reload"` | `PickupEventService.gd:78`, `PickupSnapshotBuilder.gd:93` | 17 |
| `NEW "Pickup event after the win relief"` | `FlowRuntime.gd:1857` | 18 |
Proposed title with NO marker (row 14 is exempt, no code site; D-65 lists it): `NEW "Pickup UX redesign"`.
Real story codes in markers (all found in the CSV): `V2-ITEM-002` (rows 1, 2, 10; row 2 at `PickupSnapshotBuilder.gd:235`), `V2-ITEM-003` (row 5), `V2-ITEM-004` (row 6), `V2-CONTINUITY-002` (row 7), `V2-DIRECTIVE-003` (row 9). Row 8 targets `V2-ECONOMY-003` (no code).

## How to run the probes (main chat; a subagent never runs the long ones)
All commands use a fresh own save directory and the `timeout` and `alarm` that root `AGENTS.md` gives. Delete the directory first. Read the raw `Tests:` line and grep for SCRIPT ERROR.
1. Default (small, fast; asserts the D-50 hand check only): `ECHOES_TEST_SAVE_DIR=<fresh dir> /usr/bin/perl -e 'alarm shift; exec @ARGV' <secs> /opt/homebrew/bin/godot --headless --quit --path <worktree> -- tests pickup_probe`.
2. FULL (P1 20000 rolls per cell, P2 2000 cases per cell, the D-63 pass line asserted): same command with `PICKUP_PROBE_FULL=1`. It is a long run: the main chat runs it.
3. P3 (real won fights through `FlowRuntime.dispatch`): same command with `PICKUP_PROBE_FIGHTS=<N>` (100 was used on 2026-11-15). It refuses to run without `ECHOES_TEST_SAVE_DIR`, edits no tracked file and is a RUN REQUEST: the main chat runs it and reads the printed table.
I did not measure run times in C12. Probe P3 and FULL times are not recorded here.

## Rules to keep (Jeff's working style)
- Write to Jeff in STE with "Done / Next / Need from you" and an OPEN block (ASSUMED / BLOCKED). Show every proposal in the chat in full before asking him to decide (ANSWERS #90). Ask one question at a time.
- Design leads and scope comes at build. Every design brief names a research step on comparable games (XCOM, Gears Tactics, Tomodachi); only `sr-game-designer` has web tools.
- Roles only: `mechanics-developer` (`core/`), `ui-ux-designer` (`ui/`), `mid-game-designer` (numbers), `sr-game-designer`, `sr-game-artist`, `game-feel-developer`, `technical-artist`, `qa-verifier`. Builders never verify their own work. Long runs, `godot --import`, screenshots and the full suite belong to the main chat. Agents run short filtered suites only, each with its own `ECHOES_TEST_SAVE_DIR`.
- Never reorder an existing RNG draw. Never touch the `stage.settle` stream. Tunables in `data/balance.json` (ANSWERS #83). No save repairs (ANSWERS #88). Never change the GDD. Player text is AGENT-WRITTEN (proposal) until Jeff's end review (ANSWERS #89, D-56); never "home" or "stage" (ANSWERS #86).
- Commit each verified step; no push; no PR until Jeff says. No Notion write without his yes.
- A new unwired part needs a marker `# UNWIRED (target: <story code or NEW "title">): <what>` at the seam and a row in `follow-ups.md` (the suite checks both). Do not write the word UNWIRED in any other comment in `core/` or `ui/`: the scan reads every `.gd` file there.

## Step history (short)
| Step | Result |
|---|---|
| Step 0 | Records: design document, pick numbers, follow-ups, D-57 to D-62. |
| C0 to C8 | Characterization tests, finds rules, shared `state_ends`, Directive flag, pick rule, chooser and swap rules, seam cap and event service, `flow.pickup` snapshot, controller and seven actions. Merged in PR 131. |
| C9 | Wiring: hook `FlowRuntime._open_pickup_event`, pending-result hold, end mark, Continue, resume, Resolve block 18. Suite `pickup_flow`. |
| C10 | Debug producer modes `event` and `arm`, forced count, cap override, scene check and apply, console commands. Suite `pickup_debug`. Guard 90 to 92. |
| C11 | Probes P1 to P3 (`pickup_probe`). P2 failed at `sense_base` 0.3; D-67 set 0.0. |
| C12 | Suite `pickup_unwired`; markers added for register rows 2, 7, 10, 11, 12, 13, 16 and 18; strict rules after QA (exempt rows, Target cells, carried codes); follow-ups rows aligned with the code; AGENTS.md, CONVENTIONS.md, docs/MEMORY.md, design document tags, canon index and shard map updated; this handoff rewritten. |
| U1 to U12 | NOT STARTED. |
