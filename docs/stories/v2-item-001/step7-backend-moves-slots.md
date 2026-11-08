# V2-ITEM-001 step 7: slots, moves, count discards, one discard per path

Author role: mechanics-developer. Date: 2026-11-06. Written in STE. Core only, no UI. No commit.
Source: decisions D-33 to D-39, ANSWERS #83, #87, #88, the approved prototype `docs/visual-plans/inventory-ui-mockup-v2.html` (section G and the move, merge and discard code).
Private save dir for every run: `ECHOES_TEST_SAVE_DIR=/tmp/echoes-vnext-tests/backend-ITEM001` (deleted before each run). Godot: `/tmp/claude-0/godot-bin/godot`.

## Done

| File | Change |
|---|---|
| `core/inventory/InventoryService.gd` | Slots (`_layout` :684, `_commit_layouts` :734). Stacks in the pack (`pack_stacks`). New `move_entry` :404, `discard_entry` :383, `locate_piece` :359, `entry_at` :369, `box_size` :72, `sanctum_used` :58. `snapshot` :142 and `validate` :187 rewritten. `discard` :349 no longer moves held entries. `held_pieces` :115, `remove_held` :310, `move_pack_to_sanctum` :273 know pack stacks. `_intake_stack` :487 and `_intake_unique` :521 place into slots. |
| `core/inventory/InventoryRules.gd` (+ `.uid`) | NEW. Where an inventory action is allowed (`mode` :43, `path_is_live` :31), the one-discard mark (`discard_used` :78, `mark_discard_used` :83, `clear_discard_used` :92), the shared `data.inventory` builder (`projection` :100). |
| `core/runtime/controllers/InventoryController.gd` | `handle_discard` :39 (rules, count, slot or `item_id`), new `handle_move` :81, `_rebuilt` :102. |
| `core/runtime/FlowRuntime.gd` | Arm `inventory.move.apply` :573. Comment arm count 82. |
| `core/realms/ActiveStageService.gd` | `discard_block_reason` deleted (replaced by `InventoryRules`). `lose_unsettled_packs` clears the mark :549. |
| `core/economy/StageSettlementService.gd` | `settle` clears the mark :143. |
| `core/runtime/controllers/VentureController.gd` | A successful early leave clears the mark :369. |
| `core/state/flow/states/sanctum/SanctumSnapshotBuilder.gd`, `FlowEchoPartyState.gd`, `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd` | `data.inventory` from `InventoryRules.projection`. The path view (`flow.stage_explore`) gets `data.inventory` for the first time (:481). |
| `core/save/SaveSchema.gd`, `core/save/SaveService.gd:389` | Default block gains `pack_stacks: []`. `_repair_inventory_block` is NOT dead code: left as is (D-38). It does not know `pack_stacks` or `slot`. |
| `data/balance.json` | `data.inventory.unique_cap` 8 to 20. `pack_capacity` stays 4. Comments updated. Other numbers unchanged. |
| `tests/InventoryMoveTests.gd` (+ `.uid`) | NEW suite `inventory_moves`, 12 tests (service level). |
| `tests/InventoryPathTests.gd` (+ `.uid`) | NEW suite `inventory_paths`, 14 tests (dispatch, path rules, saved mark). |
| `tests/InventoryServiceTests.gd`, `InventoryActionTests.gd`, `InventorySaveTests.gd`, `ItemPacksTests.gd` | Updated for the new rules (see Recorded values for the re-pinned literals). |
| `tests/FlowTransactionTests.gd` | Action guard 81 to 82 (`dispatch_action_count_is_82`). |
| `tests/FlowSnapshotFingerprintTests.gd` | `_fingerprint_projection` erases `data.inventory` for `flow.stage_explore` too (same pattern as the Sanctum, D-27). |
| `ui/AppRoot.gd` | Two registration lines. |
| `scripts/test-shard-map.sh`, `AGENTS.md` | `inventory_moves` and `inventory_paths` in shard11. Suite count 142 to 144 (two places, list, "added since" sentence). `scripts/check-shard-map.sh`: `SHARD MAP CHECK: OK (144 registered suites, each in exactly one of 13 shards or the merge step).` |

## Data model

| Container | Pieces | Stacks | Size (config) |
|---|---|---|---|
| Sanctum | `inventory.items` | `inventory.stacks` | `unique_cap` (pieces and stacks share it) |
| Pack | `inventory.pack` | `inventory.pack_stacks` (new, optional when missing) | `pack_capacity` |

Every entry has an integer `slot`. A stack has no id: any entry is addressed by `{ from: "sanctum"|"pack", slot }`. A piece may also be addressed by `item_id` in a discard. A stack may exist several times per type, in either container. Intake still merges into existing stacks of its type (array order), and never starts a second stack for a surplus (the surplus is lost, `stack_limit`).

## Rules built

| Rule | Reason keys | Tests |
|---|---|---|
| Intake and moves take the lowest free slot of the container. A given target slot is used if free. | | `inventory_moves/intake_takes_the_lowest_free_slot`, `.../move_both_ways_with_and_without_a_slot` |
| Validation: no two entries in one slot, slot is a whole number from 0, slot below the size. | (validate text) `slot N used twice`, `missing or invalid slot`, `slot N at or above the size S` | `inventory_moves/validate_checks_slots` |
| Move between containers (pieces and stacks, whole entry). | `container_full`, `unknown_entry`, `bad_box`, `bad_slot`, `bad_state` | `inventory_moves/move_both_ways_with_and_without_a_slot`, `inventory_paths/move_in_the_sanctum` |
| Reorder inside a container into an empty slot. Never a swap. | `slot_taken`, `no_change` | `inventory_moves/reorder_into_an_empty_slot_never_swaps`, `inventory_paths/move_refusals_change_nothing` |
| Merge: a stack dropped on a same-type stack merges up to the stack limit (definition limit, else default). Remainder stays in the source slot. An emptied source is removed. Works across containers and into a full container. | `type_mismatch`, `stack_limit` (target full), `slot_taken` (a piece is involved) | `inventory_moves/merge_exact_partial_limit_and_mismatch` |
| Moves allowed only in the Sanctum and party prep with no live path. | `path_open`, `not_in_sanctum`, `bad_payload` | `inventory_paths/no_move_on_a_path_or_away_from_the_sanctum`, `.../move_in_party_prep_keeps_the_screen`, `.../move_refusals_change_nothing` |
| A refusal changes nothing (save, snapshot, flush count). | all | `inventory_moves/refusals_change_nothing_and_name_the_reason`, `inventory_paths/move_refusals_change_nothing` |
| Moves never mint or destroy an item (ids and quantity per type constant over 400 pseudo-random moves, `validate` clean every step). | | `inventory_moves/moves_never_mint_or_destroy_an_item` |
| Discard in the Sanctum (or party prep, no live path): unlimited, any entry, either container. A stack takes a count from 1 to its quantity (absent = whole). A partial count keeps the slot. A piece takes no count. | `count_range`, `unknown_entry`, `equipped`, `not_found`, `not_unique`, `bad_box`, `bad_payload` | `inventory_moves/discard_entry_takes_a_count_for_stacks_only`, `inventory_paths/sanctum_discard_is_unlimited_and_takes_a_count` |
| Discard on a path: one per path, pack entry only. A stack discard (also a partial one) is the one. A refused discard does not spend it. | `not_in_pack`, `path_used`, `no_stage` | `inventory_paths/one_discard_per_path_on_a_pack_entry`, `.../a_stack_discard_is_the_one_discard` |
| The used mark is `stage.discard_used` (a bool on the stage record, key absent when unused). It is in the save. Cleared when the path ends: successful early leave, defeat, path-end settlement. | | `inventory_paths/the_used_mark_survives_save_and_continue` (real file reload), `.../the_used_mark_is_saved_with_the_stage` (JSON), `.../a_new_path_resets_the_used_mark` |
| Reload bypass: the path is read from saved state (`current_stage_index`, `explore_map.locked`, receipt, `party_state`, open item rows), not from `flow_ctx.stage_id`. | | `inventory_actions/path_rules_work_from_saved_state_after_a_reload` |
| A carried stack follows the carried-piece rules: counted in `settle_plan` and `items_at_risk`, drawn on an early leave, lost on defeat, moved to the Sanctum at path end or when kept. | report row `mark_index` -1, reasons as for pieces | `inventory_paths/a_carried_stack_is_drawn_lost_and_banked_like_a_carried_piece` |
| `dispatch` guard count 82. | | `flow_transaction/dispatch_action_count_is_82` |
| No `ph_` id in `balance.json` or a new save; sizes are whole numbers above 0. | | `inventory_paths/new_save_and_config_hold_no_placeholder` |
| Same dispatches give the same save JSON. | | `inventory_paths/dispatches_are_deterministic` |

### Where an action is allowed (`InventoryRules.mode`, :43)

| Last snapshot | Mode |
|---|---|
| `flow.stage_explore` | path |
| `flow.sanctum`, `flow.echo_party` | path while `path_is_live`, else sanctum |
| any other | none (`not_in_sanctum`) |

Action payloads (read by `InventoryController`):

| Action | Payload |
|---|---|
| `inventory.move.apply` | `{ from, slot, to, to_slot? }` (`to_slot` absent or -1 = lowest free slot) |
| `inventory.discard.apply` | `{ item_id }` or `{ from, slot }`, plus optional `{ count }` |

Both are dispatched by the row. Neither is a slot in `snapshot.actions`. A success rebuilds the snapshot of the screen it came from (Sanctum: re-enter; party prep and path view: rebuilt in place, so the path view session state is not wiped) and requests one save (`inventory.move`, `inventory.discard`).

## Snapshot shape changes

`data.inventory` (Sanctum, party prep, path view). Built by `InventoryRules.projection`.

| Key | Change |
|---|---|
| `unique_cap`, `pack_capacity` | The container sizes (existing keys). |
| `pack_count` | Now counts pack pieces and pack stacks. `pack_load`, `pack_free`, `warn.pack` follow it. |
| `sanctum_used` | NEW. Pieces plus stacks in the Sanctum. |
| `sanctum_room` | Now `unique_cap` minus `sanctum_used`. |
| `unique_count` | Unchanged (pieces only). |
| `items`, `pack` rows | NEW keys `name` (definition name, `""` if none, never the id), `slot`. Existing keys stay. |
| `stacks` rows | RENAMED `quantity` to `count`, `limit` to `stack_limit`. NEW `name`, `slot`. `type_id`, `kind`, `at_limit` stay. No UI consumer existed (grep). |
| `pack_stacks` | NEW. Same row shape as `stacks`. Always present (empty list). |
| `path` | NEW. Present only while a path is live: `{ move_reason: "path_open", discard_used: bool, discard_pack_reason: "" or "path_used", discard_sanctum_reason: "not_in_pack" }`. An empty reason means allowed. Always present in the `flow.stage_explore` snapshot. |
| `discard_blocked` | REMOVED (the old `path_open` discard rule is gone). |

New in `flow.stage_explore`: `data.inventory` (path HUD pack button: `pack_count`, `pack_load.level`, `pack_capacity`, `path`).

## Tests run

All runs: filtered, one process at a time, private save dir, directory deleted before each run. Compile check (`--check-only`): 0 `SCRIPT ERROR` lines. `--import` run once for the new `class_name` files.

| Suites | Raw `Tests:` line |
|---|---|
| `=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char,flow_transaction,snapshot_fingerprint` | `Tests: 141 total, 141 passed, 0 failed` (paths 14, moves 12, actions 25, service 23, save 15, item_packs 30, item_packs_char 11, flow_transaction 9, snapshot_fingerprint 2) |
| `=flow_transaction,snapshot_purity,snapshot_contract,snapshot_fingerprint,save_integrity,pending_result,foundation_ui` | `Tests: 80 total, 80 passed, 0 failed` |
| `=econ_char,economy,payout_ui,stop_short,sanctum.layout,sanctum.party,echo_party` | `Tests: 263 total, 263 passed, 0 failed` |
| `=traversal,venture_char,realm_ui,sanctum.summon,stage_stop_ui,explore` | `Tests: 182 total, 182 passed, 0 failed` |
| `=seam,contact,objective` | `Tests: 85 total, 85 passed, 0 failed` |

Mutation checks by hand (each restored, `cmp` equal): leave does not clear the mark; merge moves the whole source; pack-only rule off; swap allowed. Each made at least one new test fail (`a_new_path_resets_the_used_mark`; `merge_exact_partial_limit_and_mismatch` and `moves_never_mint_or_destroy_an_item`; `one_discard_per_path_on_a_pack_entry` and `the_used_mark_is_saved_with_the_stage`; four tests).

Not run (by instruction): the full suite, the sharded suite, `reward`, `combat_*`, `fingerprint_*`, `maturity_baseline`.

## Recorded values

No fingerprint, golden constant or balance baseline moved. Details:

| Item | Result |
|---|---|
| `snapshot_fingerprint/sanctum` hash `a26556e1…` and `stage_explore` hash `fe7d8a0e…` | Unchanged, 2 of 2 pass. The `flow.stage_explore` snapshot gained `data.inventory`. To keep the hash, `_fingerprint_projection` now erases `data.inventory` for that type too (the D-27 pattern for the Sanctum: the key holds tunable sizes). This is a test-projection edit, not a re-record. Decide if you accept the pattern for the path view. |
| Test-owned literals re-pinned (this story's own block, not game balance) | `inventory_service` `_PINNED_RESULTS` and `_PINNED_SAVE`; `inventory_actions` `_PINNED_FINAL`. One cause: entries now carry `slot`, and stacks use Sanctum slots (a stack can be lost with `overflow` in a full Sanctum). I traced each new value by hand before pinning. |
| `data/balance.json` `unique_cap` | 8 to 20 as the brief says. No test pins the shipping number. |
| `stage.settle` stream, `inventory.leave.*` roots | Not changed. |

## RUN REQUEST (main chat)

1. Command (one full mode only; `GODOT_BIN` is the Godot path of this machine):
   `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"` with Bash `timeout` 3600000. The script carries its own per-shard alarms.
2. Expected duration: about 18 minutes on 4 cores, about 31 minutes on 2 cores.
3. Files the run edits: none in the checkout. It writes `/tmp/echoes-vnext-sharded/`. No `trap` is needed.
4. Verify: `git status --short` and `git diff --stat` are the same before and after the run.
5. Read back: the `COMBINED:` line (expect 2,2xx total, 0 failed), any shard log without a `Tests:` line, the `movement_fallback` merge-step line, and the `TIMING_SUITE` lines for `inventory_moves` and `inventory_paths` (expected under 10 s each; `inventory_paths` is about 7 s).

## OPEN — questions and assumptions

ASSUMED: 1. SHRINK RULE (D-37 open point, Jeff decides). A stored slot at or above a lowered size stays valid until its entry leaves. No entry moves or drops. A new entry takes only a slot below the size. Room is `size` minus entries. An entry with a missing, invalid or repeated slot reads as the lowest free slot in array order and is written at the next mutation (reads never write). The UI must draw `max(size, highest slot + 1)` slots after a cut. Alternative if Jeff prefers: the size may never drop below the highest used slot. Test: `inventory_moves/entries_without_a_slot_and_a_resized_container`.
ASSUMED: 2. Stacks use slots and count against `unique_cap` (Sanctum) and `pack_capacity` (pack), one slot each (D-33, D-37). This changes D-05 ("one total count caps unique pieces; stacks have a per-stack limit"). Effect: with 20 slots, pieces plus stacks must fit in 20. An intake of a NEW stack into a full Sanctum is lost with `overflow`; a merge into an existing stack needs no slot.
ASSUMED: 3. Intake keeps its old merge rule: it fills existing same-type Sanctum stacks in array order up to the limit; if none exists it starts one stack in the lowest free slot; a surplus is lost (`stack_limit`). It never starts a second stack. Several stacks of one type exist only through moves. (History: superseded by D-46, a lost rest is always `overflow`.)
ASSUMED: 4. The Sanctum discard no longer moves carried entries into the Sanctum (the old rule would undo the player's pack choice). `move_pack_to_sanctum` still runs at path end, on a kept leave and at the start of every unique `intake`. The `intake` pull matters only for the F1 debug producer (`direct` mode) outside a settlement: it empties the pack into the Sanctum first. Jeff may want that pull removed from `intake`; the settlement flows do not need it.
ASSUMED: 5. A move onto an occupied target slot is refused (`slot_taken`) also across containers. The prototype falls back to the first free slot there. The UI omits `to_slot` for "first free slot".
ASSUMED: 6. "On a path" for the inventory rules means the path view, or a Sanctum or party-prep screen while the saved path is live (open item row, or entered, unsettled stage whose party has not left). So on the encounter Back route and after Continue into a live path, moves are refused (`path_open`), a Sanctum entry cannot be discarded (`not_in_pack`) and a pack entry takes the one discard. The old rule allowed a Sanctum discard there when the pack was empty.
ASSUMED: 7. Moves and discards are also allowed in party prep (`flow.echo_party`), as D-33 says for moves. The brief said "Sanctum and party prep" for moves only; I applied it to the Sanctum-side discard too.
ASSUMED: 8. Carried stacks (pack stacks) are settled like carried pieces so that "stacks are not special" holds. They are listed by `held_pieces` with the id `stack:<type_id>:<pack slot>` and a `quantity`. Draw key on a "some" leave: `inventory.leave.<stage>.<run>.<settle>.held.stack:<type_id>:<slot>`, a new key under the unchanged root. Existing draws are unchanged. A kept stack moves whole to the lowest free Sanctum slot (no merge); with no free slot it stays held (`to_pack`). Not covered by a test: the "some" draw of a stack (only none, all, full Sanctum, defeat, path end).
ASSUMED: 9. The one-discard mark is cleared at three path ends: successful early leave (`VentureController`), defeat (`lose_unsettled_packs`), path-end settlement. A "new path" is any entry after one of those. A discard refused for a bad count does not spend it. If no stage record can hold the mark, a path discard is refused with `no_stage`.
ASSUMED: 10. `data.inventory.path` is present only while a path is live (the D-28 pattern), and always in the path view. Reasons are fixed strings. `discard_blocked` is removed. The row keys `quantity` and `limit` of stack rows are renamed to `count` and `stack_limit` (no consumer; D-38 allows it).
ASSUMED: 11. A move of a stack moves the whole entry (the prototype has no count move). Only a drop onto a same-type stack merges; a move with no `to_slot` never merges.
ASSUMED: 12. The test-projection edit for `flow.stage_explore` (see Recorded values) is acceptable under the D-27 precedent.
BLOCKED: None.

## Fixes after D-40

Source: decisions D-40 and D-41. Same private save dir. No commit.

### What changed

| Item | Change | File:line |
|---|---|---|
| 1. Screen decides the mode | `mode` no longer reads the saved path. `flow.sanctum` and `flow.echo_party` are always the Sanctum mode (moves free, unlimited discard on any entry, mark not spent). `flow.stage_explore` is the path mode. `path_is_live` is deleted. | `core/inventory/InventoryRules.gd:28` |
| 1. `path` key | `projection` adds `path` only with `force_path` (the path view). A Sanctum screen with a live saved path has no `path` key. | `core/inventory/InventoryRules.gd:85` |
| 2. Intake pull removed | Unique `intake` no longer calls `move_pack_to_sanctum`. Doc updated. | `core/inventory/InventoryService.gd:260` |
| 2. Path end keeps its order | `_bank_rows` moves carried entries into the Sanctum BEFORE the new rows (intake did it before), and after them as before. Kept-leave already moved first. | `core/economy/StageSettlementService.gd:186` |
| 2. F1 debug producer | No code change: `direct` mode now only places new pieces and leaves the pack alone. Tests that relied on the pull were changed. | `tests/InventoryServiceTests.gd` (`intake_never_moves_the_pack`, `rejections`) |
| 5. Shrink | Nothing built. The tolerant read stays (`_layout`: a stored slot at or above the size is kept, a missing or repeated slot reads as the lowest free slot). It is NOT a shrink rule. | `core/inventory/InventoryService.gd:684` |
| 6. Test gap | New test `inventory_paths/a_carried_stack_is_drawn_on_a_some_leave`. It predicts each draw from the stream name for six pack slots and checks kept and lost cases both occur. | `tests/InventoryPathTests.gd` |
| Tests for the old rule | Rewritten: `inventory_actions/discard_with_an_open_path`, `.../path_key_only_in_the_path_view_and_sanctum_rules_on_a_live_path`, `.../sanctum_rules_hold_after_a_reload_whatever_the_saved_path`, `.../sanctum_and_party_prep_count_open_rows_of_every_realm`; `inventory_paths/no_move_on_a_path_or_away_from_the_sanctum`, `.../the_used_mark_survives_save_and_continue` (mark set in the path view, read after a real file reload, refused in the path view, ignored on the Sanctum screen). | `tests/InventoryActionTests.gd`, `tests/InventoryPathTests.gd` |

### Tests run

| Suites | Raw `Tests:` line |
|---|---|
| `=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char` | `Tests: 131 total, 131 passed, 0 failed` |
| `=flow_transaction,snapshot_fingerprint,snapshot_purity,snapshot_contract,save_integrity,pending_result,econ_char,economy,payout_ui,sanctum.layout,sanctum.party,echo_party` | `Tests: 277 total, 277 passed, 0 failed` |
| `=traversal,venture_char,seam,stop_short,realm_ui` | `Tests: 190 total, 190 passed, 0 failed` |

Compile check: 0 `SCRIPT ERROR` lines. No suite added or removed in this pass, so `check-shard-map.sh` is unchanged from the first delivery (OK, 144 suites). The full and sharded suites were not run.

### Recorded values

None moved. No fingerprint, hash or balance number changed. Test-owned behaviour changed for one named cause (D-40: intake no longer moves the pack); the tests above were rewritten, with no pinned literal re-recorded in this pass.

### RUN REQUEST (main chat)

1. Command: `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"`, Bash `timeout` 3600000.
2. Expected duration: about 18 minutes on 4 cores, about 31 on 2 cores.
3. Files the run edits: none in the checkout (it writes `/tmp/echoes-vnext-sharded/`). No `trap` needed.
4. Verify: `git status --short` and `git diff --stat` are the same before and after.
5. Read back: the `COMBINED:` line, any shard log without a `Tests:` line, the `movement_fallback` merge line, the `TIMING_SUITE` lines of `inventory_moves` and `inventory_paths`.

## OPEN — questions and assumptions

ASSUMED: 1. `_bank_rows` calls `move_pack_to_sanctum` before the new rows as well as after, so carried entries still take Sanctum room before new rows at path end (the order intake gave before). Jeff may choose the opposite order.
ASSUMED: 2. On a Sanctum or party-prep screen the one-discard mark is neither read nor written. A saved mark stays until a path end clears it, and applies again in the path view.
ASSUMED: 3. The tolerant read of an out-of-range slot is unchanged and is not a shrink rule. A smaller pack or Sanctum size is not handled: D-41 defers it to the story that shrinks packs.
BLOCKED: None.

## Fixes after QA (D-42, D-43)

Source: decisions D-42 and D-43, `step7-qa-report.md` (F-01 to F-08). Same private save dir. No commit.

### Changes

| Item | Change | File:line |
|---|---|---|
| D-42 (F-01, F-02) | Nothing moves on its own. `move_pack_to_sanctum` is deleted: it had no other user. The only move left is the player's `inventory.move.apply` (`move_entry`). | `core/inventory/InventoryService.gd` (function removed; `move_entry` :385) |
| D-42 path end | `_bank_rows` only runs the new rows through intake. Carried entries stay in the pack. | `core/economy/StageSettlementService.gd:183` |
| D-42 kept leave | Surviving carried pieces and stacks stay in the pack. The `moved` field of the log `economy.settle.items` is removed. | `core/economy/StageSettlementService.gd:456`, :503 |
| D-43 (F-03) | New `draw_id`: a carried stack is named `stack:<type_id>:<n>`, n = its order among carried stacks of that type by slot. The leave draw key is `inventory.leave.<stage>.<run>.<settle>.held.stack:<type_id>:<n>`. Piece draws and the root are unchanged. `held_pieces` stack rows carry `order`. The held-fate record and `remove_held` still use `stack:<type_id>:<slot>`, which is only valid inside one settle. | `InventoryService.gd:115`, :141; `StageSettlementService.gd:479` |
| F-05 | `move_entry` takes `reserved` (open item rows). A move into the pack counts them as taken slots (`container_full`). `InventoryController` passes `EarningsService.open_item_rows_in_save`. | `InventoryService.gd:385`, :632; `InventoryController.gd:97` |
| F-04 | New test: a failed `stage.return_home` keeps the mark. Mutation M12 (clear before `if success:`) now fails it. | `tests/InventoryPathTests.gd` (`a_failed_return_home_keeps_the_used_mark`) |
| F-07 | `InventoryController` header rewritten to the D-40 rule (screen decides; `item_id` wins over `from`/`slot`). | `core/runtime/controllers/InventoryController.gd:1-25` |
| F-08 | The service header calls the slot code a tolerant read, not a shrink rule. The `unique_cap` comment says "The Sanctum never shrinks". Comment text only in `balance.json`. | `InventoryService.gd:14`; `data/balance.json:3739` |
| F-06 | No code change. Exception to D-28 (recorded in D-43): `flow.stage_explore` always carries `data.inventory`, like `flow.echo_party` (D-29). | `StageExploreSnapshotBuilder.gd:481` |
| Tests changed | `inventory_service/move_pack_to_sanctum` deleted (function gone). Tests that encoded the old moves rewritten: `item_packs/held_pieces_are_rolled`, `repeat_leave_draws_held_pieces_again`, `survivor_stays_held_when_the_sanctum_is_full`, `retry_after_a_partial_state_does_not_redraw`, `path_end_banks_item_rows_once`, `report_rows_carry_source_and_mark_index`; `inventory_actions/leave_item_report_reaches_the_card_and_survives_a_reload`; `inventory_paths/a_carried_stack_is_drawn_and_lost_like_a_carried_piece` (renamed); `inventory_service/intake_never_moves_the_pack`, `rejections`, `invariants`, `remove_held`. `inventory_paths/a_carried_stack_is_drawn_on_a_some_leave` now needs the same result in pack slots 0, 3 and 7. `inventory_moves/held_stacks_are_settled_like_held_pieces` checks `draw_id`. New: `a_failed_return_home_keeps_the_used_mark`, `a_move_into_the_pack_leaves_the_slots_of_open_item_rows`. | `tests/` |

### Result rows now (leave, defeat, path-end card: `data.items`)

Field names are unchanged: `{ type_id, kind, grade, quantity, source, mark_index, reason_key }`, plus `lost_quantity` only for a stack surplus.

| Field | Content |
|---|---|
| `source` | `"held"` = a carried entry (it was in the pack before). `"gathered"` = a NEW find of this path. |
| List | `kept` = survived. `lost` = lost. |
| `reason_key` of a kept carried entry | Always `ok`. The value `to_pack` is no longer used for a carried entry. The entry is still in the pack. |
| `reason_key` of a kept NEW find | `ok` (put in the Sanctum), `to_pack` (any part put in a pack slot), `overflow` (stack find whose rest found no slot; `lost_quantity` > 0). `stack_limit` was replaced by D-46. |
| `reason_key` of a lost entry | `leave_none`, `leave_some`, `defeat`, `overflow`, or an intake refusal key. |
| `mark_index` | Piece mark; `-1` for a stack and for any find not yet a piece. |
| Path-end card | Lists NEW finds only (carried entries are not rolled and not listed), as before. |

The UI can show survivors without naming a place: `kept` rows with `source` `held` stay where they were; `kept` rows with `source` `gathered` carry `ok` or `to_pack` if a place is ever needed.

### Tests run

| Suites | Raw `Tests:` line |
|---|---|
| `=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char` | `Tests: 132 total, 132 passed, 0 failed` (paths 17, moves 12, actions 25, service 22, save 15, item_packs 30, item_packs_char 11) |
| `=flow_transaction,snapshot_fingerprint,snapshot_purity,snapshot_contract,save_integrity,pending_result,econ_char,economy,payout_ui,sanctum.layout,sanctum.party,echo_party` | `Tests: 277 total, 277 passed, 0 failed` |
| `=traversal,venture_char,seam,stop_short,realm_ui` | `Tests: 190 total, 190 passed, 0 failed` |

Compile check: 0 `SCRIPT ERROR` lines. Mutations by hand (each restored, `cmp` equal): clear the mark before `if success:` fails `a_failed_return_home_keeps_the_used_mark`; drop `reserved` from the move check fails `a_move_into_the_pack_leaves_the_slots_of_open_item_rows`; key the stack draw by slot fails `held_stacks_are_settled_like_held_pieces` and `a_carried_stack_is_drawn_on_a_some_leave`. Suite count is 144 minus 0 (no suite added or removed), so the shard map is unchanged.

### Recorded values

None moved. No fingerprint, hash or balance number changed. One test-owned literal changed for a named cause: `inventory_service` `_PINNED_RESULTS` entry `moved/1/` is now `moved/ok/` (the script now calls the player move `move_entry`; the pinned save is unchanged). The early-leave draws of pieces and the `stage.settle` stream are unchanged. The draw key of a carried STACK changed from `...held.stack:<type>:<slot>` to `...held.stack:<type>:<n>`; that key existed only since step 7 and no recorded value used it.

### RUN REQUEST (main chat)

1. Command: `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"`, Bash `timeout` 3600000.
2. Expected duration: about 18 minutes on 4 cores, about 31 on 2.
3. Files the run edits: none in the checkout (it writes `/tmp/echoes-vnext-sharded/`). No `trap` needed.
4. Verify: `git status --short` and `git diff --stat` are the same before and after.
5. Read back: the `COMBINED:` line (expect 2,676 total or near: one test deleted, three added), any shard log without a `Tests:` line, the `movement_fallback` merge line.

Late fix (QA option C, D-16, D-42): a NEW stack with no free Sanctum slot now takes a free pack slot (result `packed`, reason `to_pack`; `gathered` owns a slot, `direct` needs a free one) and is lost as `overflow` only when both are full. A merge into a Sanctum stack of its type is unchanged and needs no slot. Change: `core/inventory/InventoryService.gd:468` (`_intake_stack`, new `gathered` and `reserved` parameters, call at :464). The leave and the path end use the same intake, so the result row of a new stack find is a `kept` row with `reason_key` `to_pack`. New tests: `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` (full Sanctum plus free pack slot, both full, stack limit, merge preferred), `inventory_paths/a_new_stack_find_is_kept_in_the_pack_when_the_sanctum_is_full` (leave and path end). `item_packs/path_end_preview_equals_the_payout_report` uses Sanctum size 3 so its stack-surplus case still occurs.
Late fix tests: `=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char`: `Tests: 134 total, 134 passed, 0 failed`; `=flow_transaction,snapshot_fingerprint,snapshot_purity,snapshot_contract,save_integrity,pending_result,econ_char,economy,payout_ui,sanctum.layout,sanctum.party,echo_party`: `Tests: 277 total, 277 passed, 0 failed`; `=traversal,venture_char,seam,stop_short,realm_ui`: `Tests: 190 total, 190 passed, 0 failed`. Recorded values moved: none. Expected sharded total: about 2,678.

## OPEN — questions and assumptions

ASSUMED: 1. A kept carried entry always reports `reason_key` `ok` (it stays in the pack). If the UI wants a separate value, tell me.
ASSUMED: 2. (Closed by the late fix above.) A NEW stack with no free Sanctum slot takes a free pack slot; only a full Sanctum and a full pack lose it.
ASSUMED: 3. D-43 limit: the draw name of a carried stack is its order among stacks of the same type. If the player reorders two stacks of ONE type so that their relative order swaps, their two draw results swap between them (the set of results is the same). One stack of a type, or any move that keeps the relative order, never changes a result.
ASSUMED: 4. The path-end card still lists NEW finds only. Carried entries stay silent there because they are neither rolled nor moved.
BLOCKED: None.

## Fixes after QA round 2 (D-45)

Source: decision D-45, `step7-qa-report-2.md` (F2-01 to F2-07). Same private save dir. No commit.

### Changes

| Item | Change | File:line |
|---|---|---|
| F2-01, F2-02 (D-45) | `_intake_stack` rewritten. A stack find fills in order: 1) merge into same-type Sanctum stacks with room; 2) new Sanctum stacks in free Sanctum slots (each up to the limit); 3) merge into same-type pack stacks with room; 4) new pack stacks in free pack slots (`gathered`: if none is free below the size, ONE slot above it; `direct`: only while `pack_free(reserved)` is above 0); 5) the rest is lost. Reason of the lost rest: `stack_limit` when the find is larger than one stack can be (`quantity` above the limit), else `overflow`. Result: `stored`/`ok` all in the Sanctum; `packed`/`to_pack` when any went to the pack; `partial` when some was lost; `lost` when none was kept. Conservation holds (every unit is added to one stack or counted as lost). | `core/inventory/InventoryService.gd:474` | (History: superseded by D-46.)
| New helper | `_stack_fill` adds to same-type stacks of one array, in array order. | `core/inventory/InventoryService.gd:524` |
| F2-03 | No code change. Documented behaviour kept (swapping two same-type carried stacks may swap their results). | `InventoryService.gd:141` |
| F2-07 text | `intake` doc describes the new stack order. The broken last sentence of the `remove_held` doc is fixed. The tolerant-read comments no longer say "size cut" or "no size ever shrinks": they say D-41 defers the pack shrink rule and the Sanctum never shrinks. The controller header says a move into the pack counts slots reserved by open item rows. The test comment "ASSUMED shrink rule" is reworded. | `InventoryService.gd:14`, :155, :272; `InventoryController.gd:19-21`; `tests/InventoryMoveTests.gd:182` |

### Tests

| Test | What it pins |
|---|---|
| `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` (rewritten) | QA example (Sanctum stack 3/3, free slots, find 2: new Sanctum stack, nothing lost); multi-step spill (merge, new Sanctum stack, new pack stack, 7 units, none lost); pack merge before a new pack slot; a full pack stack gives a new pack stack; both full (`lost/overflow`, save unchanged); 8 against limit 3 with two pack slots (`partial/stack_limit`, 6 kept, 2 lost); mode difference (direct lost, gathered one slot above the size at function level: no play path reaches it because every gathered row reserves a pack slot, F2-06); reserved slot (direct lost, gathered packed, F2-05). | (History: superseded by D-46.)
| `inventory_moves/held_stacks_are_settled_like_held_pieces` (extended) | F2-04: the draw order is counted per type; moving a stack of another type does not change a draw name. |
| `inventory_moves/intake_takes_the_lowest_free_slot` | Merge into the pack stack, partial/overflow, both full. |
| `inventory_paths/a_new_stack_find_is_kept_in_the_pack_when_the_sanctum_is_full` | The leave merges the second find into the first pack stack (one pack stack of 3). The two-pack-stacks assertion is removed. |
| Rewritten for the new rule | `inventory_service/stack_merge_and_limit`, `stack_above_a_lowered_limit`, `cfg_of_the_wrong_type_does_not_crash`, `fixed_calls_give_the_pinned_save` (re-pinned results and save); `item_packs/partial_stack_keeps_the_stored_quantity` (Sanctum 1, pack 1: 3 kept in the pack, 5 lost), `path_end_preview_equals_the_payout_report` (find of 12 keeps the lost-quantity case). |

Mutations by hand (each restored, `cmp` equal): order counted over all types fails `held_stacks_are_settled_like_held_pieces` (F2-04); direct fallback ignores `reserved` fails `a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` (F2-05); no `_lowest_free` fallback for a gathered stack fails the same test (F2-06).

| Suites | Raw `Tests:` line |
|---|---|
| `=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char` | `Tests: 134 total, 134 passed, 0 failed` |
| `=flow_transaction,snapshot_fingerprint,snapshot_purity,snapshot_contract,save_integrity,pending_result,econ_char,economy,payout_ui,sanctum.layout,sanctum.party,echo_party` | `Tests: 277 total, 277 passed, 0 failed` |
| `=traversal,venture_char,seam,stop_short,realm_ui` | `Tests: 190 total, 190 passed, 0 failed` |

Compile check (`--check-only --quit`): 0 `SCRIPT ERROR` lines. No suite added or removed (shard map unchanged). The expected sharded total is 2680 (no test added or removed).

### Recorded values

None moved. No fingerprint, hash or balance number changed. Test-owned literals re-pinned for one named cause (D-45: a stack find no longer stops at a full Sanctum stack and starts new stacks): `inventory_service` `_PINNED_RESULTS` and `_PINNED_SAVE`. I traced the new results by hand (the consumable find of 4 splits into 3 in the Sanctum and 1 in the pack; the player move then takes the pack stack to slot 0).

### Result rows

Field names are unchanged. A new stack find that put any part in the pack reports `kept`, `source` `gathered`, `reason_key` `to_pack`. A find with a lost rest reports `reason_key` `overflow` and `lost_quantity` (superseded by D-46: it was `stack_limit` for a find larger than one stack). The final contract is in the section `Fixes after QA round 4 (D-47)`.

### RUN REQUEST (main chat)

1. Command: `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"`, Bash `timeout` 3600000.
2. Expected duration: about 18 minutes on 4 cores, about 31 on 2.
3. Files the run edits: none in the checkout (it writes `/tmp/echoes-vnext-sharded/`). No `trap` needed.
4. Verify: `git status --short` and `git diff --stat` are the same before and after.
5. Read back: the `COMBINED:` line (expect 2680 total), any shard log without a `Tests:` line, the `movement_fallback` merge line.

## OPEN — questions and assumptions

ASSUMED: 1. The reason of a lost rest is `stack_limit` when the find is larger than one stack can be, else `overflow`. A find of 3 where 1 fits and no slot is left reports `partial`/`overflow`. D-45 names both keys but not this split; tell me if the UI needs another rule. (History: superseded by D-46, the reason is always `overflow`.)
ASSUMED: 2. A `gathered` stack may start only ONE new pack stack above the pack size (as a gathered piece takes one slot above it); further chunks need a free slot below the size. This path is not reached in play (every gathered row reserves a pack slot) and is tested at function level.
ASSUMED: 3. Intake of a stack can now start several stacks in one call (a find larger than one stack). This follows D-45 and replaces the earlier rule "intake never starts a second stack".
BLOCKED: None.

## Fixes after QA round 3

Source: `step7-qa-report-3.md` (F3-01 to F3-05), decision D-46. Same private save dir. No commit.

### Changes

| Item | Change | File:line |
|---|---|---|
| F3-01 (High) | A `gathered` stack find keeps the slot its row owns for the FIRST new pack stack. Every further pack chunk, and every `direct` chunk, needs `pack_free(reserved) > 0`. For `gathered`, `reserved` is now `later_rows`: the open rows still to settle AFTER this one (`rows.size() - index - 1`). Rows already settled are not counted: they are already in the pack, so `pack_count` counts them. The pack can no longer hold more entries than its size through the play path. | `core/inventory/InventoryService.gd:474` (`_intake_stack`, step 4) |
| F3-01 callers | `_bank_rows` (path end and preview) and `_settle_leave_items` (early leave) pass `rows.size() - i - 1`. `_settle_item_row` names the parameter `later_rows`. The preview runs the same `_bank_rows`, so it still equals the payout. | `core/economy/StageSettlementService.gd:183`, :494, :524 |
| D-46 (F3-02) | The lost rest of a stack find ALWAYS reports `overflow`. The `stack_limit` split is removed. A find is never refused for its size. Stored plus lost equals the find quantity. The result stays `partial` when some part was kept, `lost` when none. The move refusal `stack_limit` (target stack at its limit) is a different use and stays. | `InventoryService.gd:521` |
| F3-03 | `_stack_limit_comment` text (comment only) and the docstring of `_t_preview_equals_payout` rewritten. | `data/balance.json:3743`; `tests/ItemPacksTests.gd:659` |
| F3-05 | History, left as is (earlier sections are superseded by D-45 and D-46). | none |

How `later_rows` was derived (the QA candidate M9 used `rows.size()`): at find time each open row owns one pack slot, so `pack_count + open rows <= size`. When row i of N is settled, `pack_count` already holds the pieces and stacks of rows 0..i-1. Slots still to keep free are those of rows i+1..N-1, which is `N - i - 1`. Row i itself uses its own slot for the first chunk. Proof by probe (tests below):

| Rows (Sanctum full, size 1) | Pack size | M9 (`rows.size()`) | This fix |
|---|---|---|---|
| [relic, consumable 8] | 4 | relic 1, stack 3 kept, 5 lost (over-reserves) | relic 1, stacks 3+3+2, nothing lost, 4 entries |
| [consumable 8, relic] | 4 | stacks 3+3, relic lost or above size | stacks 3+3+2, relic in the 4th slot, 4 entries |
| [consumable 8, relic, armor] (real seam `record_found_items`) | 3 | n/a | stack 3 kept, 5 lost (`overflow`), relic, armor: 3 entries, `validate` empty |

### Tests

| Test | What it pins |
|---|---|
| `inventory_paths/a_big_stack_find_stays_within_the_pack_through_the_real_seam` (new) | QA play scenario through `record_found_items`, then path end AND an early leave with outcome all: pack entries <= 3, `validate` empty, 3 consumables kept and 5 reported lost, relic and armor in the pack. Fails without the fix (pack of 5 entries, 3 `validate` errors). |
| `inventory_paths/a_big_stack_find_leaves_the_slots_of_later_rows` (new) | Rows [relic, consumable 8] and [consumable 8, relic] with a pack of 4: 3+3+2 and 4 entries, nothing lost, preview equals payout. Fails under M9. |
| D-46 updates | `inventory_service/stack_merge_and_limit` (limit 0 case), `cfg_of_the_wrong_type_does_not_crash`, `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` (adds stored + lost = 8), `item_packs/partial_stack_keeps_the_stored_quantity`: the lost-remainder reason is `overflow`. |

Mutations by hand (each restored, `cmp` equal): the old step 4 condition (no fix) fails the real-seam test (`pack entries 5`); M9 (`rows.size()`) fails `a_big_stack_find_leaves_the_slots_of_later_rows`.

Remaining uses of the word `stack_limit` as a reason: only the move refusal (`InventoryService.gd:659`, controller header, `inventory_moves` merge tests). Other hits are the config key `stack_limit` and the snapshot field `stack_limit`. No intake test fixture pins it.

| Suites | Raw `Tests:` line |
|---|---|
| `=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char` | `Tests: 136 total, 136 passed, 0 failed` |
| `=flow_transaction,snapshot_fingerprint,snapshot_purity,snapshot_contract,save_integrity,pending_result,econ_char,economy,payout_ui,sanctum.layout,sanctum.party,echo_party` | `Tests: 277 total, 277 passed, 0 failed` |
| `=traversal,venture_char,seam,stop_short,realm_ui` | `Tests: 190 total, 190 passed, 0 failed` |

Compile check (`--check-only --quit`): 0 `SCRIPT ERROR` lines. No suite added or removed (shard map unchanged); two tests added, so the expected sharded total is 2682.

### Recorded values

None moved. No fingerprint, hash or balance number changed (only comment text in `balance.json`). No pinned literal changed in this round.

### RUN REQUEST (main chat)

1. Command: `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"`, Bash `timeout` 3600000.
2. Expected duration: about 18 minutes on 4 cores, about 31 on 2.
3. Files the run edits: none in the checkout (it writes `/tmp/echoes-vnext-sharded/`). No `trap` needed.
4. Verify: `git status --short` and `git diff --stat` are the same before and after.
5. Read back: the `COMBINED:` line (expect 2682 total), any shard log without a `Tests:` line, the `movement_fallback` merge line.

## OPEN — questions and assumptions

ASSUMED: 1. `later_rows` counts only the open rows of the stage being settled. Open rows of other stages or Realms (counted by `record_found_items` through `open_item_rows_in_save`) are not passed. They cannot exist together with an entered path in normal play; if they do, a big find could still take a slot they own. Say if you want that count added.
ASSUMED: 2. The first new pack stack of a `gathered` find may still go one slot above the pack size when no slot is free below it (function-level case, not reachable through `record_found_items`).
ASSUMED: 3. F3-04 (the pinned script no longer covers a successful pack-piece discard) is left as is; `inventory_service/discard_outcomes` covers it.
BLOCKED: None.

## Fixes after QA round 4 (D-47)

Source: `step7-qa-report-4.md` (F4-01 to F4-04), decision D-47. Same private save dir. No commit.

### Changes

| Item | Change | File:line |
|---|---|---|
| F4-01 | The slot hold counts the open item rows of OTHER stages and Realms. New helper `_other_open_rows(save, rows)` = `maxi(0, open_item_rows_in_save(save) - rows.size())`, computed once before the loop. `later_rows` = `other + rows.size() - i - 1` in `_bank_rows` (path end and preview) and in `_settle_leave_items` (early leave). `open_item_rows_in_save` counts rows that are unsettled, not lost and hold items: exactly the rows `record_found_items` reserves a slot for and that later own one. The preview runs the same `_bank_rows` on copies, so it still equals the payout (test `path_end_preview_equals_the_payout_report` passes). | `core/economy/StageSettlementService.gd:186`, :497, :524 |
| F4-02 | Accepted as built (D-47). No code change. | none |
| F4-03 | Test for the early-leave caller added (see Tests). | `tests/InventoryPathTests.gd` |
| F4-04 | Stale `stack_limit` text fixed. `step6-fixes.md` line 37 (the `data.items` contract) now lists the real reasons. In this report the kept-find line (:221) is fixed, and the history lines (:135, :269, :278, :300, :312) carry the note "superseded by D-46". | `docs/stories/v2-item-001/step6-fixes.md:37`; this file |

### Tests

| Test | What it pins |
|---|---|
| `inventory_paths/a_big_stack_find_leaves_the_slots_of_rows_in_other_realms` (new) | QA scenario: Realm B has an open relic row, Sanctum full (1), pack 3, Realm A finds consumable 8 through `record_found_items`. Path end AND early leave: 6 kept, 2 lost, pack 2 of 3. Then Realm B's row is banked: `packed`, pack 3 entries, `validate` empty. |
| `inventory_paths/a_big_stack_find_leaves_the_slots_of_later_rows` (extended) | F4-03: the early leave (outcome all) with rows [relic, consumable 8] and a pack of 4: stacks 3+3+2, 4 entries, nothing lost, `validate` empty. |

Mutations by hand (each restored, `cmp` equal): M1b (`rows.size()` instead of the later-rows count in `_settle_leave_items`) fails `a_big_stack_find_leaves_the_slots_of_later_rows` (`pack stacks [3], entries 2`); `_other_open_rows` returns 0 fails `a_big_stack_find_leaves_the_slots_of_rows_in_other_realms`.

| Suites | Raw `Tests:` line |
|---|---|
| `=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char` | `Tests: 137 total, 137 passed, 0 failed` |
| `=flow_transaction,snapshot_fingerprint,snapshot_purity,snapshot_contract,save_integrity,pending_result,econ_char,economy,payout_ui,sanctum.layout,sanctum.party,echo_party` | `Tests: 277 total, 277 passed, 0 failed` |
| `=traversal,venture_char,seam,stop_short,realm_ui` | `Tests: 190 total, 190 passed, 0 failed` |

Compile check (`--check-only --quit`): 0 `SCRIPT ERROR` lines. No suite added or removed (shard map unchanged). One test added, so the expected sharded total is 2683.

### Recorded values

None moved. No fingerprint, hash, balance number or pinned literal changed.

### Final contract of the `data.items` rows (leave card, defeat card, path-end card)

Block: `{ kept: [row], lost: [row] }`. Present only when at least one row exists. A row:

| Field | Type | Content |
|---|---|---|
| `type_id`, `kind`, `grade` | String | The item. Never an id. |
| `quantity` | int | Units kept (kept list) or units lost (lost list, whole entry). A partly lost stack find shows the KEPT part. |
| `source` | String | `held` = carried before this path (in the pack). `gathered` = a NEW find of this path. |
| `mark_index` | int | Piece mark; `-1` for a stack and for any find that is not a piece. |
| `reason_key` | String | See next table. |
| `lost_quantity` | int | Present only when part of a stack find found no slot. |

| List | `source` | `reason_key` values |
|---|---|---|
| `kept` | `held` | `ok` (a survivor; it stays in the pack, the UI does not name a place) |
| `kept` | `gathered` | `ok` (put in the Sanctum), `to_pack` (any part put in a pack slot), `overflow` (only with `lost_quantity`: the kept part of a stack find whose rest found no slot) |
| `lost` | `held` or `gathered` | `leave_none`, `leave_some`, `defeat`, `overflow` (no slot held it), or an intake refusal key (`unknown_kind`, `kind_disabled`, `bad_entry`, `unknown_type`) |

`stack_limit` is never an item-report reason. The path-end card lists NEW finds only. Rows replayed from a saved result come back with float `quantity` and `mark_index`: the UI reads them with `int()`.

### RUN REQUEST (main chat)

1. Command: `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"`, Bash `timeout` 3600000.
2. Expected duration: about 18 minutes on 4 cores, about 31 on 2.
3. Files the run edits: none in the checkout (it writes `/tmp/echoes-vnext-sharded/`). No `trap` needed.
4. Verify: `git status --short` and `git diff --stat` are the same before and after.
5. Read back: the `COMBINED:` line (expect 2683), any shard log without a `Tests:` line, the `movement_fallback` merge line.

## OPEN — questions and assumptions

ASSUMED: 1. The test settles Realm B's row with a direct `gathered` intake and a settled mark, not with a second full path end. The slot arithmetic is the same (`later_rows` 0 for the last row).
ASSUMED: 2. F4-02 (over-reservation: a later row that merges still holds its slot, so a big find can lose a few units) stays as built per D-47.
BLOCKED: None.

## Refusal key (D-48)

Source: decision D-48 (Jeff, 2026-11-08): core gap 1 (one-shot refusal key) and core gap 2 (item names on at-risk and result rows). Same private save dir. No commit.

### Changes

| Item | Change | File:line |
|---|---|---|
| Refusal one-shot field | `FlowContext.pending_inventory_refusal` `{ action, reason }`. Never saved (FlowContext is not in the save). Same pattern as `pending_return_confirm`. | `core/state/flow/FlowContext.gd:149` |
| Refusal handed to the snapshot | `InventoryController._deny` sets the field and publishes a COPY of the current snapshot whose `data.inventory` is rebuilt by `InventoryRules.projection` (no re-enter, no save, no new flow state, no `actions`). It does this only when the current snapshot has `data.inventory` (Sanctum, party prep, path view). Elsewhere (for example the stage map) nothing is set. The outcome still carries `error_code`. | `core/runtime/controllers/InventoryController.gd:119-136` |
| Builder | `projection` adds `refused` when the field is set. | `core/inventory/InventoryRules.gd:91` |
| One-shot clear | After the snapshot is published, `dispatch` spends the field, gives the caller a copy that carries the key, and erases it from `last_snapshot`. | `core/runtime/FlowRuntime.gd:779` |
| Names on rows | `InventoryService.name_of(cfg, type_id)` is now public (one function for inventory rows, at-risk rows and result rows). `EarningsService.at_risk_row` and `report_row` take an optional `name`; the key is added only when it is not empty. Callers pass it: leave, path end, preview, items at risk, defeat. | `core/inventory/InventoryService.gd:800`; `core/economy/EarningsService.gd:236`, :246; `core/economy/StageSettlementService.gd:489`, :495, :561, :587, :593; `core/realms/ActiveStageService.gd:548`, :556 |
| Replay after a reload | No code change: the stored result keeps the row as data, so `name` comes back through `PendingResultService`. Test below. | none |

### Snapshot field shape

`data.inventory.refused` (Sanctum, party prep, path view), present only in the one snapshot built right after a refused action:

| Key | Type | Content |
|---|---|---|
| `action` | String | `move` or `discard` |
| `reason` | String | One reason key from the list below |

The key is absent in every other snapshot, in an accepted action's snapshot, in the save, and after a reload. A refusal changes nothing else (save byte-equal, no flush, no extra save request). The other `data.inventory` fields are rebuilt from the current save, so they are current.

### Reason keys that reach the field

| Action | Reason keys |
|---|---|
| `move` | `bad_payload`, `path_open`, `bad_box`, `unknown_entry`, `bad_slot`, `no_change`, `slot_taken`, `type_mismatch`, `stack_limit` (target stack at its limit), `container_full`, `bad_state` |
| `discard` | `bad_payload`, `bad_box`, `unknown_entry`, `not_found`, `not_unique`, `count_range`, `equipped`, `not_in_pack`, `path_used`, `no_stage`, `bad_state` |
| Not carried | `not_in_sanctum` (the screen has no `data.inventory`, so there is no snapshot to carry it; the outcome `error_code` still has it) |

### Tests

| Test | What it pins |
|---|---|
| `inventory_paths/a_refusal_key_is_in_the_next_snapshot_only` | The dispatch result has the key; `last_snapshot` and the next dispatch do not; discard is named `discard`; the save is byte-equal; an accepted move and discard give none; a refusal on the stage map sets nothing. |
| `inventory_paths/each_refusal_reason_reaches_the_snapshot` | 14 reasons from the Sanctum, `container_full`, and `path_open`, `not_in_pack`, `path_used` from the path view. |
| `inventory_paths/the_refusal_key_is_never_saved_and_does_not_survive_a_reload` | No refusal field in the save; none after a real reload. |
| `inventory_paths/item_names_are_on_at_risk_and_result_rows` | Names on at-risk rows, stage-clear preview and payout rows, leave rows (kept and lost), defeat rows. |
| `inventory_paths/item_names_survive_a_reload_of_the_result` | Names on the leave card and on the replay by `PendingResultService` after a JSON reload. |
| `inventory_paths/a_type_without_a_definition_has_no_name_key` | No `name` key and no crash when the type has no definition. |
| Updated | `inventory_actions/discard_a_sanctum_piece` and `discard_refusals_change_nothing` (a refusal now republishes the snapshot, current inventory, same save); `item_packs` and `inventory_actions` row literals gain `name`; the defeat-card test uses unnamed rows (the real `balance.json` has no definitions). |

Mutations by hand (each restored, `cmp` equal): the one-shot clear removed fails `a_refusal_key_is_in_the_next_snapshot_only` (the key stays); `name` dropped from `report_row` fails 9 tests (`item_names_are_on_at_risk_and_result_rows`, `item_names_survive_a_reload_of_the_result`, and 7 row-literal tests).

| Suites | Raw `Tests:` line |
|---|---|
| `=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char` | `Tests: 143 total, 143 passed, 0 failed` |
| `=flow_transaction,snapshot_fingerprint,snapshot_purity,snapshot_contract,save_integrity,pending_result,econ_char,economy,payout_ui,sanctum.layout,sanctum.party,echo_party` | `Tests: 277 total, 277 passed, 0 failed` |
| `=inventory_ui,traversal,venture_char,seam,stop_short,realm_ui` | `Tests: 217 total, 217 passed, 0 failed` |

Compile check (`--check-only --quit`): 0 `SCRIPT ERROR` lines. No suite added or removed (shard map unchanged). Six tests added: the expected sharded total is 2689.

### Recorded values

None moved. `snapshot_fingerprint` passes 2 of 2 with the recorded hashes: `refused` is absent unless a refusal just happened, and `name` is an additive key on rows that exist only in the item-bearing snapshots and results (the fingerprint snapshots hold none). The D-27 projection rule for `data.inventory` is unchanged.

### Final contract of the `data.items` rows (and `items_at_risk`)

One row: `{ type_id, kind, grade, quantity, source, mark_index, name?, reason_key, lost_quantity? }`. An at-risk row has the same fields without `reason_key` and `lost_quantity`.

| Field | Content |
|---|---|
| `name` (NEW, D-48) | The definition name, the same source as the inventory rows. Present only when the type has a definition with a name. Without it the UI uses the kind word. Never an id. |
| `source` | `held` (carried before this path) or `gathered` (a NEW find) |
| `reason_key`, kept `held` | `ok` |
| `reason_key`, kept `gathered` | `ok`, `to_pack`, `overflow` (only with `lost_quantity`) |
| `reason_key`, lost | `leave_none`, `leave_some`, `defeat`, `overflow`, or an intake refusal key |
| Other fields | As in "Fixes after QA round 4 (D-47)" |

### RUN REQUEST (main chat)

1. Command: `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"`, Bash `timeout` 3600000.
2. Expected duration: about 18 minutes on 4 cores, about 31 on 2.
3. Files the run edits: none in the checkout (it writes `/tmp/echoes-vnext-sharded/`). No `trap` needed.
4. Verify: `git status --short` and `git diff --stat` are the same before and after.
5. Read back: the `COMBINED:` line (expect 2689), any shard log without a `Tests:` line, the `movement_fallback` merge line.

## OPEN — questions and assumptions

ASSUMED: 1. A refusal republishes the current snapshot with a refreshed `data.inventory` (not a full state rebuild). The rest of the snapshot is the previous one. Say if the UI needs a full rebuild.
ASSUMED: 2. `not_in_sanctum` cannot be carried because the screens that refuse it have no `data.inventory`. The UI gets it from the dispatch result `error_code` only if it reads it; otherwise it needs no message there.
ASSUMED: 3. `name` is absent (not an empty string) when the type has no definition or no name, so the UI can test the key.
BLOCKED: None.

## New finds stay in the pack (D-49)

Source: decision D-49 (Jeff, 2026-11-08, play test). Same private save dir. No commit.

### The placement rule

| Case | Rule |
|---|---|
| A surviving gathered find at a path end or after a kept early leave | It goes to the PACK, never to the Sanctum, also when the Sanctum is empty. The player moves it later with `inventory.move.apply`. Nothing moves by itself (D-42). |
| Unique piece | The pack slot its row owns: the lowest free pack slot (one above the size only if none is free, as before). |
| Stack find | 1) merge into a same-type pack stack with room; 2) new pack stacks in free pack slots. The first new stack uses the slot the row owns; each further chunk needs `pack_free(later_rows) > 0` (F3-01, F4-01 rules, `later_rows` includes rows of other Realms). 3) What no free pack slot holds is lost as `overflow` (D-46). |
| Leave draws | Unchanged: one draw per gathered find; a lost find is not placed. Defeat still loses everything gathered and everything carried. |
| `direct` (debug producer) and `gathered` (service mode) | Unchanged: Sanctum first, then the pack. |
| Pack size | The pack never holds more entries than its size after a settlement (`validate` empty), also with carried pieces and open rows in other Realms. |

### Changes

| Item | Change | File:line |
|---|---|---|
| New intake mode | `MODE_PACK_ONLY` (`"pack_only"`). `_intake_stack` and `_intake_unique` now take the mode string (not a bool). `pack_only` skips the Sanctum steps; it has the `gathered` ownership rule for pack slots; a full fit returns `stored`/`ok`, a lost rest returns `partial`/`overflow`. `direct` and `gathered` behave as before. The `intake` doc is updated. | `core/inventory/InventoryService.gd:35-38`, :258-285, :463-475, `_intake_stack`, `_intake_unique` |
| Callers | The only caller that used `gathered` was the settlement (`_settle_item_row`, used by `_bank_rows` for the path end and the preview, and by `_settle_leave_items` for the leave). It now passes `pack_only`. The other caller is the debug producer (`direct`, unchanged). | `core/economy/StageSettlementService.gd:548` |
| Preview | Runs the same `_bank_rows`, so it equals the payout (test `path_end_preview_equals_the_payout_report` passes). | none |

### Result rows the UI sees now

Field names are unchanged. A surviving gathered find has `source` `gathered`, it is in the `kept` list, and `reason_key` is `ok` (a pack placement is the normal place). `to_pack` is no longer produced by the settlement. `overflow` with `lost_quantity` still marks a stack find whose rest found no pack slot (kept part in `kept`). Carried survivors still have `source` `held` and `ok`. Lost rows are as before (`leave_none`, `leave_some`, `defeat`, `overflow`, intake refusal keys). `name` is on every row when the type has a definition.

Consequence for the next leave: a kept find is now a carried piece in the pack, so a later early leave rolls for it again (D-19, D-22) and a defeat loses it (D-20).

### Tests

| Test | What it pins |
|---|---|
| `inventory_moves/pack_only_intake_never_touches_the_sanctum` (new) | Piece and stack in the pack with the Sanctum empty and full; pack merge; big find with the later-rows rule (`partial`/`overflow`, stored + lost = find); `direct` and `gathered` still Sanctum first. |
| `inventory_paths/new_finds_land_in_the_pack_and_stay_there` (new) | Path end, early leave all, some, none; Sanctum empty and full; a carried piece in the pack; Sanctum byte-equal; `reason_key` `ok`; nothing survives for none; pack within its size and `validate` empty. The same invariant with a carried piece, an open row in Realm B and a big find; stored + lost = 9. |
| `inventory_paths/a_find_in_the_pack_is_moved_by_the_player_only` (new) | Finds in the pack stay there; `inventory.move.apply` takes them to the Sanctum; census equal. |
| Updated for D-49 | `item_packs/item_only_pack_draws_the_outcome_roll` (kept find in the pack; a repeat leave draws it as a carried piece), `survivor_stays_held_when_the_sanctum_is_full`, `path_end_banks_item_rows_once`, `path_end_with_a_full_sanctum_keeps_pieces_held`, `report_rows_carry_source_and_mark_index`; `inventory_actions/leave_item_report_reaches_the_card_and_survives_a_reload`; `inventory_paths/a_new_stack_find_is_kept_in_the_pack_when_the_sanctum_is_full` (`to_pack` became `ok`). |

Mutations by hand (each restored, `cmp` equal): the settlement routed to `gathered` again fails 7 tests (`new_finds_land_in_the_pack_and_stay_there` and 6 others); `pack_only` disabled in `_intake_stack` fails 5 (`pack_only_intake_never_touches_the_sanctum` and 4 others); `pack_only` disabled in `_intake_unique` fails 8.

| Suites | Raw `Tests:` line |
|---|---|
| `=seam,realm_ui,inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char` | `Tests: 210 total, 210 passed, 0 failed` |
| `=flow_transaction,snapshot_fingerprint,snapshot_purity,snapshot_contract,save_integrity,pending_result,sanctum.layout,sanctum.party,echo_party` | `Tests: 107 total, 107 passed, 0 failed` |
| `=econ_char` | `Tests: 103 total, 103 passed, 0 failed` |
| `=economy,payout_ui,inventory_ui,traversal,venture_char,stop_short` | `Tests: 231 total, 231 passed, 0 failed` |

Compile check (`--check-only --quit`): 0 `SCRIPT ERROR` lines. The machine is slower now, so the groups were split to stay under 2 minutes. No suite added or removed (shard map unchanged). Three tests added: the expected sharded total is 2692.

### Recorded values

None moved. `snapshot_fingerprint` passes 2 of 2 with the recorded hashes. No pinned literal changed.

### RUN REQUEST (main chat)

1. Command: `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"`, Bash `timeout` 3600000.
2. Expected duration: about 18 to 31 minutes (the machine is slower than in earlier rounds).
3. Files the run edits: none in the checkout (it writes `/tmp/echoes-vnext-sharded/`). No `trap` needed.
4. Verify: `git status --short` and `git diff --stat` are the same before and after.
5. Read back: the `COMBINED:` line (expect 2692), any shard log without a `Tests:` line, the `movement_fallback` merge line.

## OPEN — questions and assumptions

ASSUMED: 1. The reason of a kept gathered find is `ok` for every placement in the pack. The UI cannot tell from the row whether the pack was almost full; the pack count and `pack_load` in `data.inventory` say that.
ASSUMED: 2. A kept find is a carried piece afterwards (D-19, D-22): it is rolled again on a later early leave and lost on defeat until the player moves it to the Sanctum. This follows from "it stays in the pack" and D-42; say if Jeff wants a gathered find to be safe until the next path.
ASSUMED: 3. A gathered unique piece keeps the existing rule "one slot above the size if no slot below it is free". In play every row owns a slot, so this is not reached.
BLOCKED: None.
