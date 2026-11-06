# V2-ITEM-001a step 7: QA report (independent verifier)

Written in STE. Role: qa-verifier. The verifier built none of this work. Date: 2026-11-06.
Scope: the uncommitted working tree on HEAD `ece86c4` (step 7 and "Fixes after D-40"). No source, test, data or doc file was changed. This report is the only written file.

## Verdict

**PASS WITH FINDINGS.**

The verifier found no defect that mints an item, duplicates an id, or lets the player bypass the one-discard-per-path limit in the path view. Every rule in the brief has at least one test that fails when the rule is broken, with one exception (F-04: the mark clear on a FAILED leave). Two rules work as written but cause a result that Jeff must judge: the new path-end order loses a new stack that the opposite order keeps (F-01), and a carried stack does not merge when it moves into the Sanctum (F-02).

## Findings (most severe first)

| ID | Severity | Rule | File:line | Failing scenario (inputs and result) | Suggested fix |
|---|---|---|---|---|---|
| F-01 | Medium (design decision for Jeff) | 4 | `core/economy/StageSettlementService.gd:186-190` (`_bank_rows`) | Probe `qa_bank_order`. Sanctum size 2: `it.2` in slot 0. Pack: carried `it.1`. Path end with one open row: a consumable stack of 3. Result: `it.1` moves first into slot 1, the Sanctum is full, the stack row is `lost/overflow` (3 lost). With the opposite order, the stack takes slot 1 and `it.1` stays held in the pack (D-24), so nothing is lost. The new order turns a "held" result into a "lost" result. Pieces never lose this way (a gathered piece goes to the pack), only stacks do, because a stack row never goes to the pack. | Ask Jeff which order he wants. Option A: keep carried-first (the builder's ASSUMED 1). Option B: new rows first, then carried entries. Option C: carried-first, but a gathered stack row that finds no Sanctum slot goes to the pack like a gathered piece (D-17: every gathered item owns a pack slot). Option C also matches "stacks are not special" (D-33). |
| F-02 | Low (design decision for Jeff) | 4 | `core/inventory/InventoryService.gd:271-302` (`move_pack_to_sanctum`) | Probe `qa_no_merge`. Sanctum size 3: consumable stack 2 in slot 0. Pack: consumable stack 2. Path end. Result: the Sanctum holds TWO consumable stacks (slots 0 and 1). The carried stack takes a new slot although the Sanctum stack has room for it. Intake never starts a second stack, but this settlement path does. In a fuller Sanctum the extra slot causes F-01 losses sooner. | Ask Jeff. If he wants merge: let `move_pack_to_sanctum` merge a carried stack into same-type Sanctum stacks up to the limit before it takes a slot (the D-40 sentence "a merge into an existing stack needs no slot"). |
| F-03 | Low | 3, 5 | `core/inventory/InventoryService.gd:763-765` (`_held_stack_row` id) with `core/economy/StageSettlementService.gd:478-483` | The early-leave draw of a carried stack uses the key `...held.stack:<type_id>:<slot>`. The slot is under player control: on a Sanctum screen during a live path (D-40) the player can move the stack to another pack slot. The test `inventory_paths/a_carried_stack_is_drawn_on_a_some_leave` shows that the same seed keeps the stack in some slots and loses it in others. So a reorder changes the leave result of that stack. A carried piece has a fixed id and cannot do this. | Accept and record it, or name the stack draw by a value the player cannot move (for example a stack sequence number minted like a piece id). A new key changes no existing draw. |
| F-04 | Low (test gap) | 3, 10 | `core/runtime/controllers/VentureController.gd:366-369` | Mutation M12: the mark is cleared before `if success:` (so also on a FAILED leave, while the path continues). All 131 tests pass. The code today is correct, but no test proves that a failed leave keeps the mark. A future edit could give the player a second discard on the same path. | Add a test: set the mark, force a failed `stage.return_home`, assert `discard_used` stays and a second pack discard returns `path_used`. |
| F-05 | Low | 4, 6 | `core/inventory/InventoryService.gd:650-652` (`_move_entry`) | Probe `qa_reserved`. Pack size 2, two open piece rows on the live path (`reserved` 2). On a Sanctum screen (D-40) the player moves two Sanctum pieces into the pack. Both moves succeed. The snapshot then shows `pack_load { carried 4, capacity 2, free 0, level 3 }`. Nothing is lost at path end (carried entries move first, and the total still fits), but the snapshot reports a pack above its size and the "every find owns a pack slot" promise (D-17) is broken while the path is open. | Either count `reserved` in the move check for the pack (refuse with `container_full`), or accept it and tell the UI that `carried` can exceed `capacity`. |
| F-06 | Low (decision record) | 6, 9 | `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd:481`, `tests/FlowSnapshotFingerprintTests.gd:209-211` | The path view snapshot now ALWAYS carries `data.inventory`, also for an item-free save. D-28 says new keys appear only when non-empty so that item-free snapshots stay byte-identical. D-29 made one written exception, for `flow.echo_party` only. The fingerprint projection now erases `data.inventory` for `flow.stage_explore`. Judgement: the erase removes only the new key (HEAD had no `data.inventory` on that snapshot), so the hash still proves the rest of the snapshot is unchanged. It does not hide another change. But the exception is not recorded as a decision. | Record a D-entry (like D-29) that `flow.stage_explore` `data.inventory` is always present and that its hash skips the key, or make the key conditional. |
| F-07 | Low (stale text) | 3 | `core/runtime/controllers/InventoryController.gd:11-14, 17-19` | The header says discards and moves are free only with "no live path", and that a Sanctum screen "while the path is live" follows the path rules. The code (D-40) does the opposite: the screen type alone decides (`InventoryRules.mode`). A reader who trusts the header will break D-40. | Rewrite the header to match `InventoryRules.gd:7-11`. |
| F-08 | Low (stale text, D-41) | 7 | `core/inventory/InventoryService.gd:14-16`, `data/balance.json:3739` | The service header names a "Shrink rule", and the `unique_cap` comment says "a smaller value never moves or drops an entry". D-40 says the Sanctum never shrinks, and D-41 defers the pack shrink rule. The code builds no shrink behaviour (only a tolerant read of a slot at or above the size), but the text states a rule Jeff has not chosen. | Call it a tolerant read, not a shrink rule. Delete "a smaller value never moves or drops an entry" from the config comment. |
| F-09 | Info | 9 | `tests/InventoryPathTests.gd:366`, report `step7-backend-moves-slots.md` line 162 | The report says `the_used_mark_survives_save_and_continue` sets the mark "in the path view". The test sets it with a direct call to `InventoryRules.mark_discard_used`, not with a path-view dispatch. A path-view dispatch that sets the mark is tested in `the_used_mark_is_saved_with_the_stage` (JSON copy only). The reload part is real (`_reload` reads the file). Coverage is adequate together. | Correct the report sentence, or dispatch the discard from the path view before the reload. |
| F-10 | Info | 3 | `tests/InventoryPathTests.gd:322-324` | The comment says the second discard is refused "by slot or by id". The test sends slot payloads only. Code review shows the `item_id` route reaches the same `discard_block_reason` call (`InventoryController.gd:69`), so the rule holds. | Add one `item_id` payload to the loop, or fix the comment. |

## Rules verified

| # | Rule | How verified | Result |
|---|---|---|---|
| 1 | Saved integer `slot` per entry; first free slot; no slot used twice; slot inside the size; no save repair | Code: `_layout`, `_first_free`, `_commit_layouts`, `_slot_problems`, `validate`. Tests `inventory_moves/intake_takes_the_lowest_free_slot`, `validate_checks_slots`. Mutation M1 (`slot 3 used twice` caught). `SaveService._repair_inventory_block` only gains `pack_stacks` in the default block; no slot repair (ANSWERS #88). | HOLDS |
| 2 | `inventory.move.apply` through `FlowRuntime.dispatch` to `InventoryController.handle_move` to `InventoryService.move_entry`; no controller-to-controller call; move both ways; reorder only to an empty slot (`slot_taken`); merge up to the limit, remainder stays, emptied source removed; whole-entry stack move; refused on `flow.stage_explore` (`path_open`); allowed on `flow.sanctum` and `flow.echo_party` with a live saved path; refusal changes nothing; no mint or destroy | Code review of `FlowRuntime.gd:573-574`, `InventoryController.gd:81-97`, `InventoryService.gd:608-660`, `InventoryRules.gd:28-44`. Mutations M1, M2, M4, M20. Probes: same slot and stack onto itself give `no_change`; `to_slot` -2 and 4 give `bad_slot`; 2.5 and 1e12 give `bad_payload`; full both ways give `container_full`; a taken slot in a full pack gives `slot_taken`. | HOLDS |
| 3 | Discard: Sanctum and party prep unlimited, any entry, stack takes a count (partial keeps the slot), piece takes no count; path view one discard, pack entry only, stack counts as the one; mark saved on the stage record, survives save/load, cleared at leave, defeat, path end; refused discard does not spend it | Code: `InventoryController.gd:39-78`, `InventoryRules.gd:50-78`. Mutations M3, M7, M8, M9, M13, M14, M15. Probe counts: 0 and -2 give `count_range`, 4 (above 3) gives `count_range`, 1.5, "2", `true`, 1e12 give `bad_payload`, 3.0 discards the whole stack. Bypass search: a double dispatch gives `path_used`; a reload keeps the mark (saved bool on the stage); a move in the path view is refused; `item_id` addressing resolves the box first, so a Sanctum piece by id gives `not_in_pack`; the debug producer is gated to debug builds (D-28) and does not discard; no other action writes or clears `discard_used` (grep: only `VentureController.gd:369`, `ActiveStageService.gd:549`, `StageSettlementService.gd:143`). The Sanctum Back route gives unlimited discards by D-40 design. | HOLDS, with F-04 (test gap) |
| 4 | Stacks fill one slot and count against `unique_cap` and `pack_capacity`; new stack into a full Sanctum is `overflow`; intake merges into an existing stack and never starts a second; unique intake does not pull the pack; path-end settlement and kept leave still move kept pieces | Code: `sanctum_used`, `pack_count`, `_intake_stack`, `_intake_unique`, `_bank_rows`, `_settle_leave_items`. Mutations M5, M10, M11, M19, M21. Probes `qa_bank_order`, `qa_no_merge`. | HOLDS; order judged in F-01, F-02 |
| 5 | Pack stacks settled like carried pieces; new key `inventory.leave.<stage>.<run>.<settle>.held.stack:<type_id>:<slot>`; existing draws and `stage.settle` unchanged | `git show HEAD:core/economy/StageSettlementService.gd`: `_keeps` is byte-identical to the tree; the only diff in the file is the mark clear and the extra `move_pack_to_sanctum` call. A piece id never starts with `stack:` (`it.<n>`), so no existing key changes. `held_pieces` lists pieces first, in the HEAD order. Mutation M6. Test `a_carried_stack_is_drawn_on_a_some_leave` predicts each draw from the key. | HOLDS; see F-03 |
| 6 | Rows carry `name` (never the id), `slot`, `count`, `stack_limit`; sizes, discard state and reasons; keys only when non-empty where D-28/D-29 say so; no per-piece action in `snapshot.actions`; no `ui/` read of save or FlowContext | Code: `InventoryService.snapshot`, `InventoryRules.projection`. Mutation M18 (id as name caught). Tests check that `actions` holds no inventory slot. `git diff ui/`: two test-registration lines only. | HOLDS; see F-06 |
| 7 | No pack shrink built; Sanctum never shrinks; no debuff; `unique_cap` 20, `pack_capacity` 4; other numbers unchanged | `git diff data/balance.json`: `unique_cap` 8 to 20 and comment text only. No new shrink code path (the tolerant read predates D-41). No debuff code. | HOLDS; see F-08 |
| 8 | Determinism and choke points; guard count 82 | grep of `core/inventory/` and `InventoryController.gd`: no `randf`, `randi(`, `randomize`, `Time.`, `OS.get`. Dictionaries (`taken`, `seen`, `ids`, `want`) are used for lookups; results come from Array order. `validate` takes a max over `seen.keys()`, which is order-free. No `SaveService` call; saves go through `with_save_reason`. No currency code touched. `flow_transaction/dispatch_action_count_is_82` passes. `inventory_paths/dispatches_are_deterministic` passes. | HOLDS |
| 9 | Fingerprints unchanged; test projection edit; no weakened tests | `snapshot_fingerprint` 2 of 2 pass. See "Test integrity". | HOLDS; see F-06 |
| 10 | Mutation checks | 21 mutations, table below. | 20 caught, 1 NONE (M12, F-04) |

## Mutation checks

Each mutation: copy to `/tmp/claude-0/qa-backup/<id>.<file>.bak`, one exact replacement, run `=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char`, restore with `cp`, `cmp` equal. A final `cmp` of every backup against the tree was also equal.

| ID | Mutation | File:line | Failing test (first ones) | Restored, cmp |
|---|---|---|---|---|
| M1 | Swap onto an occupied slot | `InventoryService.gd:630-631` | `inventory_moves/reorder_into_an_empty_slot_never_swaps`, `.../merge_exact_partial_limit_and_mismatch`, `.../refusals_change_nothing_and_name_the_reason`, `.../moves_never_mint_or_destroy_an_item`, `inventory_paths/move_refusals_change_nothing` (5 failed) | yes, equal |
| M2 | No stack-limit check on merge | `InventoryService.gd:635` | `inventory_moves/merge_exact_partial_limit_and_mismatch`, `.../moves_never_mint_or_destroy_an_item` | yes, equal |
| M3 | Path discard spends no mark | `InventoryController.gd:77` | `inventory_paths/one_discard_per_path_on_a_pack_entry`, `.../a_stack_discard_is_the_one_discard`, `.../the_used_mark_is_saved_with_the_stage` | yes, equal |
| M4 | Move allowed on `flow.stage_explore` | `InventoryRules.gd:42-43` | `inventory_paths/no_move_on_a_path_or_away_from_the_sanctum` | yes, equal |
| M5 | Unique intake pulls the pack first | `InventoryService.gd:523` | `inventory_service/rejections`, `.../intake_never_moves_the_pack` | yes, equal |
| M6 | No "some" draw for a carried stack | `StageSettlementService.gd:481` | `inventory_paths/a_carried_stack_is_drawn_on_a_some_leave` | yes, equal |
| M7 | Successful leave does not clear the mark | `VentureController.gd:369` | `inventory_paths/a_new_path_resets_the_used_mark` | yes, equal |
| M8 | Defeat does not clear the mark | `ActiveStageService.gd:549` | `inventory_paths/a_new_path_resets_the_used_mark` | yes, equal |
| M9 | Pack-only rule off on the path | `InventoryRules.gd:55-56` | `inventory_paths/one_discard_per_path_on_a_pack_entry`, `.../the_used_mark_is_saved_with_the_stage` | yes, equal |
| M10 | Path end: new rows before carried entries | `StageSettlementService.gd:186-187` | `item_packs/path_end_banks_item_rows_once` | yes, equal |
| M11 | Stacks do not count against the Sanctum size | `InventoryService.gd:59` | 11 failed, for example `inventory_service/discard_outcomes`, `inventory_actions/snapshot_field_shape` | yes, equal |
| M12 | Mark cleared also on a FAILED leave | `VentureController.gd:366` | **NONE** (131 of 131 pass) | yes, equal |
| M13 | Partial stack discard removes the whole stack | `InventoryService.gd:600-602` | `inventory_moves/discard_entry_takes_a_count_for_stacks_only`, `inventory_paths/sanctum_discard_is_unlimited_and_takes_a_count`, two more | yes, equal |
| M14 | Path-end settlement does not clear the mark | `StageSettlementService.gd:143` | `inventory_paths/a_new_path_resets_the_used_mark` | yes, equal |
| M15 | Mark spent before the service check (a refused count spends it) | `InventoryController.gd:72` | `inventory_paths/a_stack_discard_is_the_one_discard` | yes, equal |
| M18 | Type id shown as `name` when the definition has none | `InventoryService.gd:779` | `inventory_moves/rows_carry_name_slot_and_the_container_sizes` | yes, equal |
| M19 | Intake starts a second stack for a surplus | `InventoryService.gd:504` | `inventory_service/stack_merge_and_limit`, `.../stack_above_a_lowered_limit` | yes, equal |
| M20 | Moves refused in party prep | `InventoryRules.gd:32` | `inventory_paths/move_in_party_prep_keeps_the_screen` | yes, equal |
| M21 | Intake packs a piece while one Sanctum slot is free (invariant 3) | `InventoryService.gd:533` | 24 failed, for example `inventory_service/intake_order_and_modes` | yes, equal |

(M16 and M17 were planned and not run; the IDs are skipped.)

## Test integrity

Registered test names, `git show HEAD:tests/<file>` against the tree. No test was deleted without a replacement. Counts are equal in every modified file.

| File | HEAD | Tree | Renamed or replaced |
|---|---|---|---|
| `InventoryActionTests.gd` | 25 | 25 | `discard_blocked_key_and_the_live_path_rule` to `path_key_only_in_the_path_view_and_sanctum_rules_on_a_live_path`; `discard_guard_works_from_saved_state_after_a_reload` to `sanctum_rules_hold_after_a_reload_whatever_the_saved_path` |
| `InventoryServiceTests.gd` | 23 | 23 | `intake_moves_held_pieces_first` to `intake_never_moves_the_pack` |
| `FlowTransactionTests.gd` | 9 | 9 | `dispatch_action_count_is_81` to `_is_82` (constant 81 to 82) |
| `InventorySaveTests.gd`, `ItemPacksTests.gd`, `FlowSnapshotFingerprintTests.gd` | 15, 30, 14 | 15, 30, 14 | none |
| `InventoryMoveTests.gd`, `InventoryPathTests.gd` (new) | 0, 0 | 12, 15 | new |

Weakened or removed assertions, and the judgement:

| Where | Change | Judgement |
|---|---|---|
| `InventoryActionTests._t_path_open`, `_t_discard_blocked`, `_t_discard_reload`, `_t_reserved_and_party_prep` | The `path_open` refusal cases and the `discard_blocked` key are removed. | Required by D-40 (the rule is reversed). The new assertions test the new rule (Sanctum mode, mark not spent, no `path` key). Not a weakening. |
| `InventoryServiceTests._check_invariants:131-132` | The check "pack holds pieces while the Sanctum has room" is removed. | Required: moves and D-40 make that state legal. Invariant 3 (intake only) is still guarded: mutation M21 fails 24 tests. Not a weakening. |
| `InventoryServiceTests._t_invariants:645` | `allowed` now holds "at or above the size" from step 0. | A small weakening. Before step 80 no size cut exists, so a Sanctum slot at or above the size would be a defect, and the random walk would no longer report it. `gathered` intake into a full pack legitimately writes such slots, which is why the builder allowed it. Suggest: allow it only for `pack[` lines, or only from step 80. |
| `InventoryServiceTests._t_discard` | The case "a pack-piece discard moves held pieces in when a raised cap left room" and the `moved` checks are removed. | Required by D-40 (discard no longer moves the pack). New assertion: the kept piece keeps its slot. |
| `InventoryServiceTests._t_move_first` | Case `b` (cap 4) removed; expectations inverted. | Required by D-40. Case `e` adds a direct check of `move_pack_to_sanctum`. |
| `InventoryServiceTests._t_malformed` | `equipped` became `not_found` for a piece with `held_by: 7`. | Correct: that piece is malformed and is skipped by `_layout`, so it cannot be addressed. |
| `_PINNED_RESULTS`, `_PINNED_SAVE`, `_PINNED_FINAL` | Re-pinned; the script order and sizes changed (cap 3 to 4, stacks moved earlier). | Test-owned literals, one named cause (slots, stacks use Sanctum slots). The verifier read the new results against the code for the first five calls and they match. Not a game balance value. |
| `ItemPacksTests._t_report_rows` | Cap 2 to 3; a consumable is added to the Sanctum seed. | Needed so the stack row can merge instead of overflow under the new cap rule. The assertions are unchanged. |
| `FlowSnapshotFingerprintTests._fingerprint_projection` | Erases `data.inventory` for `flow.stage_explore` too. | Hides only the new key; see F-06. |

## Edge cases tried

| Case | Method | Result |
|---|---|---|
| Merge onto the same entry; move to the same slot | probe | `no_change` both |
| Negative and huge slot; fractional `to_slot` | probe, tests | -1 source gives `bad_payload`; `to_slot` -2 and 4 give `bad_slot`; 2.5 and 1e12 give `bad_payload` |
| Count 0, -2, above the count, 1.5, "2", `true`, 1e12, 3.0 | probe | `count_range`, `count_range`, `count_range`, `bad_payload` x4, 3.0 discards the whole stack |
| `item_id` and `from`/`slot` that disagree | probe | `item_id` wins: `it.1` left the Sanctum, the stack at the named slot kept 3. Consistent, not documented in the controller header |
| Full pack into a full Sanctum, and the reverse | probe | `container_full` both; a taken target slot gives `slot_taken` |
| Stack at the limit | test `merge_exact_partial_limit_and_mismatch` | `stack_limit`, nothing changes |
| Two stacks of one type | probe `qa_no_merge` | Possible through moves (D-33) and also through path-end settlement (F-02) |
| Reload between a move and a discard | code | Moves are refused in the path view, so the case reduces to a reload before a discard; the saved mark survives the reload |
| Held stack at path end with a full Sanctum | test `a_carried_stack_is_drawn_lost_and_banked_like_a_carried_piece` and code | Stays held (`to_pack`) |
| Piece ids after moves | code | `move_entry` moves the same Dictionary; the id never changes |
| JSON round trip of slots | probe and test `a_json_round_trip_keeps_slots_and_moves` | Float slots read as ints (`_to_int`); a move with `slot` 1.0 and `to_slot` 1.0 works; `validate` is clean |
| Mid-path move into the pack while rows are reserved | probe `qa_reserved` | Pack shows 4 of 2 (F-05) |
| Discard right after a move | test `sanctum_discard_is_unlimited_and_takes_a_count` | Works by the new slot |

All probes ran as five temporary tests appended to `tests/InventoryPathTests.gd` (an untracked file). The file was copied first and restored with `cp`. `cmp` was equal (sha256 `26affc92...` before and after).

## Evidence

| Run | Raw line |
|---|---|
| Baseline, 9 suites (`=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char,flow_transaction,snapshot_fingerprint`) | `Tests: 142 total, 142 passed, 0 failed` |
| M1 | `Tests: 131 total, 126 passed, 5 failed` |
| M2 | `Tests: 131 total, 129 passed, 2 failed` |
| M3 | `Tests: 131 total, 128 passed, 3 failed` |
| M4 | `Tests: 131 total, 130 passed, 1 failed` |
| M5 | `Tests: 131 total, 129 passed, 2 failed` |
| M6 | `Tests: 131 total, 130 passed, 1 failed` |
| M7 | `Tests: 131 total, 130 passed, 1 failed` |
| M8 | `Tests: 131 total, 130 passed, 1 failed` |
| M9 | `Tests: 131 total, 129 passed, 2 failed` |
| M10 | `Tests: 131 total, 130 passed, 1 failed` |
| M11 | `Tests: 131 total, 120 passed, 11 failed` |
| M12 | `Tests: 131 total, 131 passed, 0 failed` |
| M13 | `Tests: 131 total, 127 passed, 4 failed` |
| M14 | `Tests: 131 total, 130 passed, 1 failed` |
| M15 | `Tests: 131 total, 130 passed, 1 failed` |
| M18 | `Tests: 131 total, 130 passed, 1 failed` |
| M19 | `Tests: 131 total, 129 passed, 2 failed` |
| M20 | `Tests: 131 total, 130 passed, 1 failed` |
| M21 | `Tests: 131 total, 107 passed, 24 failed` |
| Probes (`=inventory_paths` with 5 temporary probe tests; the 5 failures are the probes, which report by failing) | `Tests: 20 total, 15 passed, 5 failed` |
| Final, after all restores, same 9 suites | `Tests: 142 total, 142 passed, 0 failed` |
| `--check-only` | 0 `SCRIPT ERROR` lines |
| `scripts/check-shard-map.sh` | `SHARD MAP CHECK: OK (144 registered suites, each in exactly one of 13 shards or the merge step).` |
| `git diff \| sha256sum` before | `f92e6137c5eefd20403e357a6cbb62c9deb62a7fe8f368d33f136605b6e579b1` |
| `git diff \| sha256sum` after | `f92e6137c5eefd20403e357a6cbb62c9deb62a7fe8f368d33f136605b6e579b1` |

Save directory for every run: `ECHOES_TEST_SAVE_DIR=/tmp/echoes-vnext-tests/qa-ITEM001`, deleted before each run. Binary: `/tmp/claude-0/godot-bin/godot` (Godot 4.6.stable). The full sharded suite was not run by the verifier (main chat result: `COMBINED: 2677 total, 2677 passed, 0 failed`).

## OPEN — questions and assumptions

ASSUMED: The path view stage (`flow_ctx.stage_id`) and the mark stage (`current_stage_index`) are always the same stage. Evidence: the stage map offers only the current stage (`FlowStageMapState.gd:106-112`). The leave and defeat clears use `stage_id`; the mark uses `current_stage_index`. If a later story lets the player replay an earlier stage, a mark could stay on the wrong stage and leak into the next path.
ASSUMED: "One discard per path" applies only in the path view. On the Sanctum Back route the player can discard without limit (D-40). The verifier did not report this as a bypass.
ASSUMED: The pinned literals in `InventoryServiceTests` and `InventoryActionTests` are test-owned and may be re-pinned for a named cause. The verifier checked the first five pinned results by hand, not all thirteen.
BLOCKED: F-01 needs Jeff's choice of the path-end order (carried first, rows first, or carried first with a gathered stack falling back to the pack).
BLOCKED: F-02 needs Jeff's choice: should a carried stack merge into a Sanctum stack at path end?
BLOCKED: F-03 needs Jeff's choice: is a slot-dependent draw for carried stacks acceptable?
BLOCKED: F-06 needs a recorded decision (D-29 style) for `flow.stage_explore` `data.inventory` always present.
