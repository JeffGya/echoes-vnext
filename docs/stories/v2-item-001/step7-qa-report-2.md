# V2-ITEM-001a step 7: QA report, round 2 (independent verifier)

Written in STE. Role: qa-verifier. Date: 2026-11-06. The verifier built none of this work.
Scope: the uncommitted working tree on HEAD `418f781`, compared with commit `810150c`. The commits between `810150c` and HEAD change docs only (`decisions.md`, `inventory-ui-mockup-v2.html`). So `git diff` is the full code change. No source, test, data or doc file was changed. This report is the only written file.

## Verdict

**PASS WITH FINDINGS.**

D-42 holds: no code path moves an entry between the pack and the Sanctum on its own. D-43 holds for one stack per type and for stacks of different types. F-04, F-05, F-07 and F-08 are fixed. Ten of thirteen mutations on the new behaviour fail at least one test. Three mutations fail no test (F2-04, F2-05, F2-06).

One rule does not do what the late fix claims: a gathered stack can still be lost while both containers have free slots (F2-01). This rule is older than this pass, but it contradicts the claim "lost as `overflow` only when both containers are full". Jeff must decide it.

## Findings (most severe first)

| ID | Severity | File:line | Failing scenario (inputs and result) | Suggested fix |
|---|---|---|---|---|
| F2-01 | Medium (design decision for Jeff) | `core/inventory/InventoryService.gd:477-511` (`_intake_stack`) | Probe P4. Sanctum size 4, pack size 4. The Sanctum holds `ph_consumable_a` 3 (its limit is 3). Gathered find `ph_consumable_a` 2. Result: `lost/stack_limit`, quantity 0, lost 2. Three Sanctum slots and four pack slots are free. Probe P4b: Sanctum stack 2 of 3, find 3: `partial/stack_limit`, 1 merged, 2 lost. The new-stack branch runs only when NO Sanctum stack of the type exists (`if matching.is_empty()`). So the pack fallback never runs for a type that has a Sanctum stack. In play, with `stack_limit_default` 20: after a Sanctum stack reaches 20, every later find of that type is destroyed, also with an empty pack. This contradicts D-17 (every gathered item owns a pack slot), D-33 (a type may have several stacks) and the late-fix claim. | Ask Jeff. Option A: after the merge, put the remainder in a NEW stack (Sanctum slot, else pack slot, else lost). Then loss happens only when both containers are full. Option B: keep the rule and record it as a decision. Option A changes the pinned `inventory_service` results (`partial/stack_limit` at call 4) and `stack_merge_and_limit`. |
| F2-02 | Low (design decision for Jeff) | `core/inventory/InventoryService.gd:472-475` | Probe P3. Sanctum full. The pack holds two `ph_material_a` stacks of 1 (limit 5). Gathered find `ph_material_a` 1. Result: a THIRD pack stack of 1 in slot 2. Intake merges only into Sanctum stacks, never into pack stacks. The direct mode (F1 producer) does the same: two direct intakes of one material made two pack stacks. Nothing is lost (each find owns a slot), but each stack find takes a full pack slot. The test `inventory_paths/a_new_stack_find_is_kept_in_the_pack_when_the_sanctum_is_full` pins two pack stacks of one type. | Ask Jeff whether intake merges a find into a same-type PACK stack with room before it takes a new slot. D-34 merges on a player drop; intake has no rule for the pack. |
| F2-03 | Low (design decision for Jeff) | `core/inventory/InventoryService.gd:126-134` (`held_pieces` order), `:141` (`draw_id`) | Probe P6. Pack: `ph_material_a` 1 in slot 0 and `ph_material_a` 5 in slot 1. Same seed, same leave, the two stacks swapped. In 9 of 18 "some" seeds the kept quantity differs (seed 1: 1 kept against 5 kept). D-43 says "Reordering the pack never changes a result" AND "key the draw on the stack's type and its order among stacks of that type". For two stacks of one type with different quantities, the two sentences conflict. The builder recorded this (his ASSUMED 3). Stacks of different types are not affected (probe P7: 0 of 18). | Ask Jeff whether the residual is acceptable. If not: mint a saved sequence number per stack at creation (like `it.<n>`) and key the draw on it. |
| F2-04 | Low (test gap) | `core/inventory/InventoryService.gd:131` | Mutation M12: the order counts carried stacks of ALL types, not of the same type. All 134 tests pass. Then a move of a stack of one type changes the draw of a stack of another type. That breaks D-43. No test reorders two stacks of different types. | Add a case to `inventory_paths/a_carried_stack_is_drawn_on_a_some_leave`: a material and a consumable stack, swapped, give the same results. |
| F2-05 | Low (test gap) | `core/inventory/InventoryService.gd:495` | Mutation M13: the direct-mode stack fallback ignores `reserved` (`pack_free(save, cfg, 0)`). All 134 tests pass. Only the F1 producer in `direct` mode on a live path reaches this. Result: a debug stack takes a pack slot that an open item row owns. Probe P5 shows the code today is correct (`lost/overflow`). | Add a case to `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full`: direct, last free slot reserved, result `lost/overflow`. |
| F2-06 | Info (test gap) | `core/inventory/InventoryService.gd:498-499` | Mutation M11: remove the `_lowest_free` fallback for a gathered stack into a full pack. All 134 tests pass. In play the branch is not reached, because every gathered row reserves a pack slot (`record_found_items`). Probe P1 and P10 (rows written past the reservation): a gathered stack goes to a slot at or above the pack size, and `validate` reports it. This matches the unique-piece rule. | Accept as defensive code, or add one direct test. |
| F2-07 | Low (stale text) | `core/inventory/InventoryService.gd:272-273`, `:289`, `:155`, `:14`; `tests/InventoryMoveTests.gd:182`; `core/runtime/controllers/InventoryController.gd:19-24` | (1) The `intake` doc says "A stack goes to its Sanctum stack and the surplus above the limit is lost". It does not describe the new Sanctum-slot then pack-slot rule. (2) The `remove_held` doc ends in a broken sentence: "the caller decides whether to call" (the deleted function name was cut, the sentence was not). (3) The `snapshot` doc says "after a size cut". (4) The header says "no size ever shrinks"; D-41 defers a pack shrink, it does not forbid it. (5) The test comment says "ASSUMED shrink rule". (6) The controller header does not say that a move into the pack counts open item rows (`container_full`). | Rewrite these comments. Comment text only. |
| F2-08 | Info | `tests/InventoryActionTests.gd:979` | `_t_discard_reload` changed the pack size from 2 to 3. The builder report does not list it. Cause: with the F-05 fix, case `open_row_only` reserves the only free pack slot, so the move is refused. The change keeps the purpose of the test (a move works on a Sanctum screen after a reload). Not a weakening. | List it in the builder report. |
| F2-09 | Info (for the UI step) | `core/economy/StageSettlementService.gd:536-544` | A new stack find that is put in the pack with a surplus lost reports `reason_key` `stack_limit` and `lost_quantity`, not `to_pack` (probe P10b). A full fit reports `to_pack`. D-42 says the card does not name the place, so the UI must not branch on `to_pack` to find the place. | None for core. Tell the UI builder. |

## Round-1 findings status

| ID | Status | Evidence |
|---|---|---|
| F-01 | CLOSED by D-42 | `_bank_rows` (`StageSettlementService.gd:183-190`) runs only the new rows through intake. A new stack with a full Sanctum takes a free pack slot (late fix). Test `a_new_stack_find_is_kept_in_the_pack_when_the_sanctum_is_full`. Residual: F2-01. |
| F-02 | CLOSED by D-42 | No path-end move exists. A carried stack stays in the pack. |
| F-03 | FIXED, with a residual (F2-03) | `draw_id` keys the draw on type and order. Mutation M4 (key by slot) fails `a_carried_stack_is_drawn_on_a_some_leave`. Probe P7: different types are slot-independent. |
| F-04 | FIXED | New test `a_failed_return_home_keeps_the_used_mark`. Mutation M6 (clear before `if success:`) fails it. |
| F-05 | FIXED | `_move_entry` counts `reserved` (`InventoryService.gd:644`); the controller passes `open_item_rows_in_save` (`InventoryController.gd:97`). Mutation M7 fails `a_move_into_the_pack_leaves_the_slots_of_open_item_rows`. A merge onto a pack stack needs no slot and stays allowed. |
| F-06 | No change needed (D-43) | Fingerprint suite passes (2 of 2). |
| F-07 | FIXED | Controller header matches `InventoryRules.gd:5-12`. Small gap: F2-07 (6). |
| F-08 | FIXED in the two named places | `git diff data/balance.json`: 1 line, `_unique_cap_comment` text only. Service header says "tolerant read". Other stale text: F2-07. |
| F-09, F-10 | Not in scope of this pass | Info items; not re-checked. |

## Rules verified

| # | Rule | How verified | Result |
|---|---|---|---|
| 1 | D-42: no automatic pack-to-Sanctum move | Every container writer was read: `intake` (settlement, F1 producer), `remove_held` (leave, defeat), `discard`/`discard_entry`/`move_entry` (controller only), `SaveService._repair_inventory_block` (load; no move), snapshot builders (read only). `move_pack_to_sanctum`: no reference in `core/`, `ui/`, `tests/`, `scripts/`, `AGENTS.md`. It remains only in old step reports (step 3, 4, 6, round-1 QA), which are history. Mutations M1, M2, M3 fail tests. | HOLDS |
| 2 | Survivors keep their slot; lost draws and defeat remove; new finds use intake | Probe P8 (repeat leave): pieces in slots 0 and 1 and stacks in slots 2 and 3 keep their slots; it.1 lost; stack totals conserved. Probe P9 (defeat, mixed pack): pack empty, Sanctum unchanged. Mutation M8 fails 2 tests. | HOLDS |
| 3 | Late fix `_intake_stack` | Probes P1-P5. Both full, direct: `lost/overflow`, save unchanged. Limit 3 exact: `packed/to_pack` 3. Above limit: `partial/stack_limit` 3 kept, 2 lost. Reserved slot in direct: `lost/overflow`. Census conserved in every probe (no mint, no duplicate). Mutations M5b, M9, M10 fail tests. | HOLDS, except F2-01 and F2-02 |
| 4 | D-43 key and no collision | Key `inventory.leave.<stage>.<run>.<settle>.held.stack:<type_id>:<n>`. `n` is an int with no `:`, so splitting at the last `:` gives one type and one n: two different stacks cannot share a key. A piece key is `held.it.<n>`; a row key is under `row.`. `_keeps` is byte-identical to `810150c`. A piece row has no `order`, so `draw_id` returns its id: piece draws are unchanged. `stage.settle` stream: not in the diff. JSON round trip keeps the draw names (probe). | HOLDS; residual F2-03, gap F2-04 |
| 5 | Result rows | Fields `{ type_id, kind, grade, quantity, source, mark_index, reason_key }` plus `lost_quantity`; `report_row` unchanged. `source` `held`/`gathered`. A kept carried entry has `ok` (code `:490-492`; tests in `item_packs`). Snapshot and `PendingResultService` replay after a JSON reload give identical rows (test `inventory_actions/leave_item_report_reaches_the_card_and_survives_a_reload`, passes). Path-end preview equals the payout, also with a stack put in the pack (probe P10b) and with both containers full (probe P10). | HOLDS; see F2-09 |
| 6 | F1 producer | Probe P11, Sanctum 1, pack 2. `direct` [weapon, consumable, material, relic]: weapon in Sanctum, two stacks in pack slots 0 and 1, relic lost. `gather` with a full pack: no row written (`take_in_order` takes 0). | HOLDS |
| 7 | Determinism | No `randi`, `randf`, `randomize`, `Time.`, `OS.` added. `held_pieces` rank uses Arrays. `open_item_rows_in_save` sums over `values()`: order-free. `dispatches_are_deterministic` passes. | HOLDS |
| 8 | Choke points and boundaries | No `SaveService` call added; saves go through `with_save_reason` / `request_save`. No currency code changed. `git diff -- ui/`: empty. | HOLDS |
| 9 | Guard count and fingerprints | `flow_transaction` 9 of 9 (includes `dispatch_action_count_is_82`); `snapshot_fingerprint` 2 of 2. | HOLDS |

## Mutation checks

Method: copy the file to `/tmp/claude-0/qa2-backup/<id>.<file>.bak`, one exact replacement (the old text must occur once), run `=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char`, restore with `cp`, prove with `cmp` (rc 0). One mutation at a time.

| ID | Mutation | File:line | Failing tests | Restored, cmp |
|---|---|---|---|---|
| M1 | Auto move at path end (`move_entry` pack to Sanctum after the rows) | `StageSettlementService.gd:188` | `item_packs/path_end_banks_item_rows_once`, `inventory_paths/a_carried_stack_is_drawn_and_lost_like_a_carried_piece` | yes, rc 0 |
| M2 | Auto move after a kept leave | `StageSettlementService.gd:494` | `item_packs/held_pieces_are_rolled`, `inventory_paths/a_carried_stack_is_drawn_and_lost_like_a_carried_piece` | yes, rc 0 |
| M3 | Intake pull (unique intake moves the pack first) | `InventoryService.gd:529` | `inventory_service/rejections`, `.../intake_never_moves_the_pack`, `item_packs/path_end_banks_item_rows_once` | yes, rc 0 |
| M4 | Stack draw keyed by slot (`str(p["id"])`) | `StageSettlementService.gd:479` | `inventory_paths/a_carried_stack_is_drawn_on_a_some_leave` | yes, rc 0 |
| M5b | No pack fallback for a new stack | `InventoryService.gd:495` | `inventory_moves/intake_takes_the_lowest_free_slot`, `.../a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full`, `inventory_paths/a_new_stack_find_is_kept_in_the_pack_when_the_sanctum_is_full` | yes, rc 0 |
| M6 | Clear the discard mark also on a failed return home | `VentureController.gd:366` | `inventory_paths/a_failed_return_home_keeps_the_used_mark` | yes, rc 0 |
| M7 | A move into the pack ignores reserved item-row slots | `InventoryService.gd:644` | `inventory_paths/a_move_into_the_pack_leaves_the_slots_of_open_item_rows` | yes, rc 0 |
| M8 | A kept carried stack is lost at a leave | `StageSettlementService.gd:481` | `inventory_paths/a_carried_stack_is_drawn_and_lost_like_a_carried_piece`, `.../a_carried_stack_is_drawn_on_a_some_leave` | yes, rc 0 |
| M9 | Direct stack takes a pack slot with no free slot | `InventoryService.gd:495` | `inventory_service/malformed_entries_do_not_throw`, `inventory_moves/intake_takes_the_lowest_free_slot`, `.../a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` | yes, rc 0 |
| M10 | A packed stack reports `stored/ok` | `InventoryService.gd:507-508` | `inventory_moves/intake_takes_the_lowest_free_slot`, `.../a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full`, `inventory_paths/a_new_stack_find_is_kept_in_the_pack_when_the_sanctum_is_full` | yes, rc 0 |
| M11 | No `_lowest_free` fallback for a gathered stack | `InventoryService.gd:498-499` | **NONE** (F2-06) | yes, rc 0 |
| M12 | Draw order counts stacks of all types | `InventoryService.gd:131` | **NONE** (F2-04) | yes, rc 0 |
| M13 | Direct stack fallback ignores `reserved` | `InventoryService.gd:495` | **NONE** (F2-05) | yes, rc 0 |

M5 (first form, `if false:`) also failed 3 tests; it was replaced by M5b to avoid test script errors from index access. The 2 `SCRIPT ERROR` lines in M5b come from the tests reading `pack_stacks[0]` that the mutation left empty; the tests still fail with messages.

## Test integrity

Registered names, `git show 810150c:tests/<file>` against the tree.

| File | 810150c | Tree | Change |
|---|---|---|---|
| `InventoryActionTests.gd` | 25 | 25 | none |
| `InventoryMoveTests.gd` | 12 | 13 | added `a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` |
| `InventoryPathTests.gd` | 15 | 18 | renamed `a_carried_stack_is_drawn_lost_and_banked_like_a_carried_piece` to `..._drawn_and_lost_like_a_carried_piece`; added `a_failed_return_home_keeps_the_used_mark`, `a_move_into_the_pack_leaves_the_slots_of_open_item_rows`, `a_new_stack_find_is_kept_in_the_pack_when_the_sanctum_is_full` |
| `InventoryServiceTests.gd` | 23 | 22 | removed `move_pack_to_sanctum` |
| `ItemPacksTests.gd` | 30 | 30 | none |

Net +3, which matches the main chat total 2677 to 2680.

| Where | Change | Judgement |
|---|---|---|
| `inventory_service/move_pack_to_sanctum` | Removed | Required: the function is deleted (D-42). |
| `_PINNED_RESULTS` `moved/1/` to `moved/ok/` | Script step 12 now calls `move_entry(pack 0 to sanctum)` | Test-owned literal, named cause. `_PINNED_SAVE` is unchanged, so the final state is still pinned. Not a weakening. |
| `_t_invariants` random walk | `move_pack_to_sanctum` replaced by `move_entry` at a random pack slot | The walk still exercises moves and checks invariants. Acceptable. |
| `_t_move_first`, `_t_remove_held`, `_t_malformed`, `_t_cfg_types` | Calls to the deleted function removed | Required. `_t_remove_held` keeps the check that nothing else moves. |
| `item_packs` (`held_pieces_are_rolled`, `repeat_leave...`, `survivor_stays_held...`, `retry...`, `report_rows...`, `path_end_banks...`) and `inventory_actions/leave_item_report...` | `to_pack` to `ok` for kept carried entries; `moved` log field removed; path-end expectations inverted (held piece stays in pack) | Required by D-42. The new assertions check the new rule (entries stay in the pack). `_t_retry_token` keeps the pre-seeded `to_pack` record of it.1, which is setup data. |
| `item_packs/path_end_preview_equals_the_payout_report` | Sanctum size 2 to 3 | Keeps the stack-surplus case (otherwise the stack goes to the pack). Probe P10b shows preview equals payout in the pack case too. Not a weakening. |
| `inventory_actions/sanctum_rules_hold_after_a_reload_whatever_the_saved_path` | Pack 2 to 3 | See F2-08. Not a weakening. |
| `inventory_moves/held_stacks_are_settled_like_held_pieces` | Settle-move part replaced by `draw_id` checks | Required. Covers same-type order and slot independence for one stack. |
| `inventory_paths/a_carried_stack_is_drawn_on_a_some_leave` | Now 2 types, 4 seeds, 3 slots; checks slot independence | Stronger. A seed with no "some" outcome is skipped; the kept/lost count guard stays. |

No test was changed only to pass.

## Edge cases tried

All probes ran as four temporary tests appended to `tests/InventoryMoveTests.gd` (registered as `inventory_moves/qa2_*`; they report by failing). The file was copied first and restored with `cp`; `cmp` equal; sha256 `697cd57b...` before and after.

| Case | Result |
|---|---|
| P1 both containers full: direct stack; gathered stack | direct `lost/overflow`, save unchanged; gathered `packed/to_pack` into slot 1 of a size-1 pack, `validate` reports it (by design, as for pieces) |
| P2 stack exactly at the limit; above the limit with the pack stack full | `packed/to_pack` 3; `partial/stack_limit` 3 kept in a second pack stack, 2 lost; census consumable 6 |
| P3 two same-type pack stacks, full Sanctum, gathered find | third pack stack (F2-02) |
| P4, P4b Sanctum stack at or near its limit, free slots | lost 2 (F2-01) |
| P5 direct with the last pack slot reserved | stack and piece both `lost/overflow` |
| P6, P7 reorder same-type / different-type stacks, 60 seeds | same type: 9 of 18 "some" seeds differ (F2-03); different types: 0 differ |
| Key check: pack [material slot 3, consumable slot 0, material slot 1] | draw ids `stack:ph_material_a:1`, `stack:ph_consumable_a:0`, `stack:ph_material_a:0` |
| JSON round trip of slots | draw ids equal after `JSON.stringify` / `parse_string` |
| P8 repeat early leave (D-22), 2 pieces + 2 stacks | leave 1 `all`, 0 draws; leave 2 `some`, 4 draws (stacks drawn again), it.1 lost, slots kept, stack totals 6 before and after |
| P9 defeat, mixed pack (relic, consumable stack) plus an open material row | 1 row lost; pack empty; Sanctum piece kept |
| P10 path end with both containers full (rows written past the reservation) | both rows kept `to_pack` above the pack size; preview equals payout |
| P10b path end, new stack 5 into the pack (limit 3) | `stack_limit`, `lost_quantity` 2; preview equals payout |
| P11 F1 producer, direct and gather | see Rules verified 6 |
| Save/load mid-handoff after a kept leave | Existing test `leave_item_report_reaches_the_card_and_survives_a_reload` (JSON reload, `PendingResultService` replay equal): passes |

## Evidence

| Run | Raw line |
|---|---|
| `git diff \| sha256sum` before | `a636e2eb114e6a71659065a0e2a571d409defa06bc5c447431524a24217d9e30` |
| Baseline `=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char,flow_transaction,snapshot_fingerprint,pending_result` | `Tests: 155 total, 155 passed, 0 failed` |
| M1 | `Tests: 134 total, 132 passed, 2 failed` |
| M2 | `Tests: 134 total, 132 passed, 2 failed` |
| M3 | `Tests: 134 total, 131 passed, 3 failed` |
| M4 | `Tests: 134 total, 133 passed, 1 failed` |
| M5 | `Tests: 134 total, 131 passed, 3 failed` |
| M5b | `Tests: 134 total, 131 passed, 3 failed` |
| M6 | `Tests: 134 total, 133 passed, 1 failed` |
| M7 | `Tests: 134 total, 133 passed, 1 failed` |
| M8 | `Tests: 134 total, 132 passed, 2 failed` |
| M9 | `Tests: 134 total, 131 passed, 3 failed` |
| M10 | `Tests: 134 total, 131 passed, 3 failed` |
| M11 | `Tests: 134 total, 134 passed, 0 failed` |
| M12 | `Tests: 134 total, 134 passed, 0 failed` |
| M13 | `Tests: 134 total, 134 passed, 0 failed` |
| Probes (`=inventory_moves` with 4 temporary probe tests; the 4 failures are the probes) | `Tests: 17 total, 13 passed, 4 failed` |
| `--headless --check-only --quit` | rc 0, 0 `SCRIPT ERROR` lines |
| `scripts/check-shard-map.sh` | `SHARD MAP CHECK: OK (144 registered suites, each in exactly one of 13 shards or the merge step).` |
| `git diff \| sha256sum` after | `a636e2eb114e6a71659065a0e2a571d409defa06bc5c447431524a24217d9e30` |

Save directory for every test run: `ECHOES_TEST_SAVE_DIR=/tmp/echoes-vnext-tests/qa2-ITEM001`, deleted before each run. Binary: `/tmp/claude-0/godot-bin/godot` (project declares 4.6). A first compile-check attempt without `--quit` started the game to the splash screen and was stopped by `timeout` after 110 s (rc 124). It used the default user data folder, not the test save dir. It changed no file in the checkout (the diff hash is unchanged). The full and sharded suites were not run by the verifier.

## OPEN — questions and assumptions

BLOCKED: F2-01 needs Jeff's decision. Should the remainder of a gathered stack start a new stack (Sanctum slot, else pack slot) when the same-type Sanctum stack is at its limit, so that loss happens only when both containers are full?
BLOCKED: F2-02 needs Jeff's decision. Should intake merge a stack find into a same-type pack stack with room before it takes a new pack slot?
BLOCKED: F2-03 needs Jeff's decision. Two same-type carried stacks swap their draw results when the player swaps their order. Is that acceptable, or must each stack get a saved sequence number?
ASSUMED: F2-04, F2-05 and F2-06 are test gaps for the builder, not rule changes. They need no decision from Jeff.
ASSUMED: The old step reports (step 3, 4, 6, round-1 QA) and `design-sr-game-designer-v2.md:49-50` are history. Their text about an automatic move is superseded by D-42 and needs no edit.
ASSUMED: A gathered entry that goes above the pack size (P1, P10) is acceptable. It needs rows written past the reservation, which normal play does not do.
