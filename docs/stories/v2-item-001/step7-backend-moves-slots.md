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
ASSUMED: 3. Intake keeps its old merge rule: it fills existing same-type Sanctum stacks in array order up to the limit; if none exists it starts one stack in the lowest free slot; a surplus is lost (`stack_limit`). It never starts a second stack. Several stacks of one type exist only through moves.
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
