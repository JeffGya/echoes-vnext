# Step 7 — QA report, round 4 (F3-01 and D-46 fix round)

Status: COMPLETE.

Scope: the uncommitted tree versus HEAD `d996fb8` (9 files, `415 insertions, 118 deletions`). The verifier changed
no source, test, data or doc file (this report is the only new file). Diff hash at the start, after every mutation
and at the end: `621e3fb5b53ab7762561b13f8ea2888be39e32a8cf067be565d0b1c853fa5b48`.

## Verdict

**PASS WITH FINDINGS.**

The F3-01 fix holds for every probe inside one stage: the pack never holds more entries than its size, `validate`
is empty, conservation holds, and the preview equals the payout. D-46 holds: every lost stack remainder reports
`overflow`. Both new tests fail without the fix. The contract checks pass.

One Medium finding (F4-01) remains. The fix counts only the open rows of the stage it settles. An open item row in
another Realm still owns a pack slot, and a big stack find can take that slot. The pack then goes above its size
when the other Realm settles. The builder recorded this as ASSUMED 1. A play route reaches it (traced by reading
code). Jeff decides whether F4-01 blocks the UI step. The fix is two lines.

## Findings (most severe first)

| Id | Severity | File:line | Failing scenario (inputs, result) | Suggested fix |
|---|---|---|---|---|
| F4-01 | Medium | `core/economy/StageSettlementService.gd:188`, `:501` (`later_rows` = `rows.size() - i - 1`, this stage only); intake `core/inventory/InventoryService.gd:505` | Probe `probe_other.gd`. Sanctum size 1, full. Pack size 3, empty. Realm B holds one open item row (a relic). Realm A: the seam `record_found_items` takes `ph_consumable_a` 8 (free room 1, because it counts Realm B's row). Path end, and leave `all`: pack stacks 3@0, 3@1, 2@2. Pack 3/3, but pack plus open rows = 4. Realm B's path then ends (gathered relic, `later_rows` 0): `packed/to_pack`, pack 4 entries, `validate` = `pack: 4 entries above pack_capacity`, `pack[0]: slot 3 at or above the size 3`. Play route (by reading code, not run through `FlowRuntime`): (1) Realm B active, a find recorded on its path; (2) Back to the Sanctum mid path (D-40); (3) `nav.realm_select` is always on the Sanctum (`SanctumSnapshotBuilder.gd:76`); (4) a COMPLETED Realm is not locked (`RealmService.gd:201` locks only `not_started`), and `handle_select_realm` (`VentureController.gd:511`) starts a replay; (5) a stack find larger than one stack spills into the pack at that path end. Before D-45 a gathered find took one slot only, so this route could not overfill the pack. | Count the open rows of other stages and Realms once, before the loop: `var other := maxi(0, EarningsService.open_item_rows_in_save(save) - rows.size())`, then pass `other + rows.size() - i - 1`. Do this in `_bank_rows` and in `_settle_leave_items`. The preview copies the save with this stage's rows still open, so the same formula gives the same number. Add the `probe_other.gd` case as a test. |
| F4-02 | Low (decision for Jeff) | `core/economy/StageSettlementService.gd:188`, `:501` | Over-reservation. (a) Path end, Sanctum full, pack 3, rows [consumable 8, consumable 1]: stacks 3, 3, 1; 2 lost (`overflow`). Rows [consumable 1, consumable 8]: stacks 3, 3, 3; 0 lost. The later row merges into a stack and needs no slot, but its slot stays reserved. (b) Leave `some`, seed 12, rows [consumable 8, relic]: the draw loses the relic; the consumable keeps 6 and loses 2 (`overflow`); one pack slot stays empty (`p_some.txt`). The pack never goes above its size, so D-46 holds. The result depends on row order and on later draws. | Optional. For leave: draw all row keeps first, then count only the kept later rows. For merges: accept as built. Ask Jeff if the order effect is acceptable. |
| F4-03 | Low (test gap) | `core/economy/StageSettlementService.gd:501` | Mutation M1b (`rows.size()` in `_settle_leave_items` only, the QA round 3 M9 shape) breaks no test. `_t_big_find_later_rows` covers the path end only; the seam test has one slot per row, so over-reservation gives the same result there. | Add the leave `all` variant of `_t_big_find_later_rows` (rows [relic, consumable 8], pack 4). |
| F4-04 | Info (stale text) | `docs/stories/v2-item-001/step6-fixes.md:37`; `step7-backend-moves-slots.md:221`, `:300`, `:312` | These lines still name `stack_limit` as the reason of a lost stack rest. D-46 replaces this with `overflow`. The step6 line is the `flow.resolve` `data.items` contract that the UI builder reads. Its kept reasons list `ok`, `to_pack`, `stack_limit` and omit `overflow`. | Add one line to the step 7 report: kept reasons are `ok`, `to_pack`, `overflow` (with `lost_quantity`). The older lines are history. |

## D-46 check

| Place | Result |
|---|---|
| `_intake_stack` | One loss return: `_res("partial" if added > 0 else "lost", "overflow", "", added, left)` (`InventoryService.gd:522`). Limit 0 also gives `overflow`. |
| `_bank_rows`, `_settle_leave_items`, `_settle_item_row`, result rows, preview | They copy the intake `reason_key`. No `stack_limit` literal (grep). |
| Snapshot builders | `stack_limit` only as a stack row field (`InventoryService.gd:174`) and the config key. |
| Move refusal | `refused/stack_limit` at `InventoryService.gd:658` (target stack at its limit). Different use. Stays. |
| Tests | `stack_limit` only in the move merge test (`InventoryMoveTests.gd:372`), the snapshot key list (`InventoryActionTests.gd:542`) and a config label (`InventoryServiceTests.gd:728`). |
| `ui/` | No `stack_limit` reference. |
| Docs | See F4-04. |

## Probes tried

Scripts in `/tmp/claude-0/qa4/` (outside the tree). Fixture: `ph_consumable_a` limit 3, `ph_material_a` limit 5.
"S1 full" = Sanctum size 1 holding one weapon. Every find goes through `ActiveStageService.record_found_items`.
Each case ran four times: path end (seed 2), leave `all` (seed 2), leave `some` (seed 1), leave `nothing` (seed 0).
Checks per run: pack count <= size, `validate` empty, conservation per stack type (find quantity = stored + lost, and
stored = the report `quantity`), preview == payout at path end.

| Id | Input | Path end result | All 4 runs |
|---|---|---|---|
| Q1 | S1 full, pack 3, finds consumable 8, relic, armor | stack 3@0 (5 lost, `overflow`), relic@1, armor@2; 3/3 | PASS |
| Q2a | S1 full, pack 4, rows [relic, consumable 8] | relic@0, stacks 3, 3, 2; 4/4; 0 lost | PASS |
| Q2b | S1 full, pack 4, rows [consumable 8, relic] | stacks 3, 3, 2, relic@3; 4/4; 0 lost | PASS |
| Q3 | S1 full, pack 4, one row consumable 20 | stacks 3, 3, 3, 3; 8 lost `overflow` | PASS |
| Q4a | S1 full, pack 4, [consumable 8, consumable 8] | 3, 3, 3, 3; second row 4 kept, 4 lost | PASS |
| Q4b | S1 full, pack 4, [consumable 8, material 12] | 3, 3, 2 + material 5; 7 lost | PASS |
| Q4c | S1 full, pack 5, [material 12, consumable 8, relic] | 5, 5, 2, consumable 3, relic@4; 5/5 | PASS |
| Q5 | S1 full, pack 3, carried consumable 2@0, [consumable 8, relic] | merge 1, new 3@1, relic@2; 4 lost | PASS (1) |
| Q6 | Sanctum 2 (weapon, consumable 2), pack 2, [consumable 13, relic] | Sanctum 3, pack 3@0, relic@1; 9 lost | PASS |
| Q7 / Q7b | S1 full, pack 3, [consumable 1, consumable 8] / [consumable 8, consumable 1] | 0 lost / 2 lost | PASS; see F4-02 |
| O1 | Open row in another Realm (see F4-01), path end and leave `all` | pack 3/3, then 4/3 after Realm B settles | FAIL, F4-01 |
| S12 | Leave `some`, seed 12, [consumable 8, relic] | relic lost by draw; consumable 6 kept, 2 lost; 2/3 | See F4-02 |
| D1 | Determinism: `probe.gd` run twice | `cmp` byte-equal (20320 bytes) | PASS |

(1) The first probe run printed "BAD" conservation for Q5 `some` and `nothing`. Cause: the probe counted the carried
stack (lost by the draw, `src=held`) as gathered. The report rows are correct. This was a probe defect.

## Mutation checks

Harness `/tmp/claude-0/qa4/mut/run.sh`: copy both files to `/tmp/claude-0/qa4-backup`, apply one mutation, run
`=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char`
(baseline `Tests: 136 total, 136 passed, 0 failed`), restore by `cp` in a `trap`, prove with `cmp`. Every run
printed `RESTORED cmp-equal`, and the diff hash after each run was `621e3fb5…fa5b48`.

| Id | Mutation | File:line | Raw `Tests:` | Failing tests |
|---|---|---|---|---|
| M1 | `rows.size()` instead of `later_rows` (QA M9), both callers | `StageSettlementService.gd:188`, `:501` | `136 total, 135 passed, 1 failed` | `inventory_paths/a_big_stack_find_leaves_the_slots_of_later_rows` |
| M1b | Same, leave caller only | `:501` | `136 total, 136 passed, 0 failed` | NONE (F4-03) |
| M2 | `later_rows` always 0, both callers | `:188`, `:501` | `136 total, 135 passed, 1 failed` | `inventory_paths/a_big_stack_find_stays_within_the_pack_through_the_real_seam` |
| M2b | `later_rows` 0, leave only | `:501` | `136 total, 135 passed, 1 failed` | same seam test |
| M2c | `later_rows` 0, path end only | `:188` | `136 total, 135 passed, 1 failed` | same seam test |
| M3 | Reserve ignored for `direct` (`reserved if gathered else 0`) | `InventoryService.gd:505` | `136 total, 135 passed, 1 failed` | `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` |
| M4 | First TWO chunks free (`made <= 1`, `made > 1`) | `:505`, `:509` | `136 total, 133 passed, 3 failed` | `item_packs/partial_stack_keeps_the_stored_quantity`, `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full`, seam test |
| M5 | Remainder reason `stack_limit` | `:522` | `136 total, 131 passed, 5 failed` | `inventory_service/stack_merge_and_limit`, `inventory_service/cfg_of_the_wrong_type_does_not_crash`, `item_packs/partial_stack_keeps_the_stored_quantity`, `inventory_moves/intake_takes_the_lowest_free_slot`, `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` |
| M5b | Old D-45 split (`stack_limit` if find > limit) | `:522` | `136 total, 132 passed, 4 failed` | the M5 set without `intake_takes_the_lowest_free_slot` |
| M6 | Remainder dropped silently (result `stored`/`packed`, no `lost_quantity`) | `:522` | `136 total, 129 passed, 7 failed` | M5 set + `item_packs/path_end_preview_equals_the_payout_report` + seam test |
| M7 | The pre-fix step 4 (every gathered chunk free) | `:505`, `:509` | `136 total, 132 passed, 4 failed` | `item_packs/partial_stack_keeps_the_stored_quantity`, `item_packs/path_end_preview_equals_the_payout_report`, `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full`, seam test |
| M8 | Further chunks ignore `reserved` (`pack_free(save, cfg, 0)`) | `:505` | `136 total, 134 passed, 2 failed` | `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full`, seam test |

Result: both new tests fail without the fix. The seam test fails under M7 (no fix). The later-rows test fails under
M1 (QA M9).

## Test integrity (versus HEAD `d996fb8`)

| File | `register_test` HEAD / now | `_t_` functions HEAD / now | Removed or renamed |
|---|---|---|---|
| `tests/InventoryMoveTests.gd` | 13 / 13 | 13 / 13 | None |
| `tests/InventoryPathTests.gd` | 18 / 20 | 18 / 20 | None. Added: `a_big_stack_find_stays_within_the_pack_through_the_real_seam`, `a_big_stack_find_leaves_the_slots_of_later_rows` |
| `tests/InventoryServiceTests.gd` | 22 / 22 | 22 / 22 | None |
| `tests/ItemPacksTests.gd` | 30 / 30 | 30 / 30 | None |

Changes made in this round (D-45 changes were judged in round 3):

| Test | Change | Judgement |
|---|---|---|
| `inventory_service/stack_merge_and_limit` | limit 0 case: `lost/stack_limit` to `lost/overflow` | Correct for D-46. Still checks that no empty stack is created. |
| `inventory_service/cfg_of_the_wrong_type_does_not_crash` | stack case: `lost/stack_limit` to `lost/overflow` | Correct for D-46. |
| `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` | 8 against limit 3: `partial/overflow`, adds stored + lost = 8 | Correct and stronger (conservation assert). |
| `item_packs/partial_stack_keeps_the_stored_quantity` | reason `overflow`; setup Sanctum 1 full, pack 1 so that 5 are lost | Correct. Quantities, fate and the report row are still pinned field by field. |
| `item_packs/path_end_preview_equals_the_payout_report` | docstring only (F3-03) | Correct. Matches the body. |
| Two new `inventory_paths` tests | See the mutation table | Both bite. The second test covers the path end only (F4-03). |

No test is weakened. No recorded value moved in this round.

## Contract checks

| Check | Result |
|---|---|
| Determinism | Probe run twice, `cmp` byte-equal. Intake and the callers use no RNG, time or OS call. |
| No `ui/` change | `git diff --stat -- ui/` is empty. |
| Dispatch guard 82 | `flow_transaction` 9 passed, includes `dispatch_action_count_is_82`. |
| Both fingerprints | `snapshot_fingerprint — 2 passed`. |
| Compile check | `--check-only --quit`: rc 0, 0 `SCRIPT ERROR`. |
| Shard map | `SHARD MAP CHECK: OK (144 registered suites, each in exactly one of 13 shards or the merge step).` |

## Evidence

| Item | Raw line |
|---|---|
| Diff hash, start, after each of 13 mutation runs, end | `621e3fb5b53ab7762561b13f8ea2888be39e32a8cf067be565d0b1c853fa5b48  -` |
| Baseline 7 inventory suites | `Tests: 136 total, 136 passed, 0 failed` |
| Contract suites `=flow_transaction,snapshot_fingerprint,snapshot_purity,snapshot_contract` | `Tests: 31 total, 31 passed, 0 failed` |
| Full sharded suite (main chat, same tree) | `COMBINED: 2682 total, 2682 passed, 0 failed` |
| Raw probe output | `/tmp/claude-0/qa4/p1.txt`, `p_other.txt`, `p_some.txt`, `det1.txt`, `det2.txt` |
| Raw mutation logs | `/tmp/claude-0/qa4/mut/M*.log` |

## OPEN — questions and assumptions

- BLOCKED: None.
- QUESTION for Jeff (F4-01): is the replay route (a completed Realm entered while another Realm has a live path with
  an open find) normal play? If yes, the builder should count the open rows of other stages and Realms (two lines).
  The builder's ASSUMED 1 says they "cannot exist together with an entered path in normal play". The code allows it:
  completed Realms are not locked on Realm Select.
- QUESTION for Jeff (F4-02): may a big stack find lose units because a LATER row keeps a slot that it then does not
  use (it merges, or the leave draw loses it)? The result then depends on row order.
- ASSUMED: The F4-01 route was traced by reading code (`SanctumSnapshotBuilder.gd:76`, `RealmService.gd:168-206`,
  `VentureController.gd:511-525`, `RealmService.get_or_create`). It was not run end to end through `FlowRuntime`. The
  mechanism itself was run (`probe_other.gd`, a hand-built open row in another Realm).
- ASSUMED: Two Realms with status `active` at the same time (the replay route) is a pre-existing Realm-lock gap,
  outside this story. Only its effect on the pack is reported here.
- ASSUMED: probes run by `--script` from `/tmp/claude-0/qa4/` equal tests in effect; they changed no tree file.
- ASSUMED: "dispatch guard 82" means `flow_transaction/dispatch_action_count_is_82`.
