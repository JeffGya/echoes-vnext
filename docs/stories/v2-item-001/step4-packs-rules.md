# V2-ITEM-001a step 4: packs rules for item rows

Author role: mechanics-developer. Date: 2026-10-28. Written in STE. No commit.
Opus review needed (determinism and draw order).

## What changed

| File | Function | Change |
|---|---|---|
| `core/economy/EarningsService.gd` | `add_row` | Accepts a row with a non-empty `items` array and 0 Ase and 0 Ekwan. Still rejects an empty id, a repeated id, and a row with no currency and no item. |
| same | `SOURCE_ITEM`, `item_id`, `record_item` | New. `record_item` writes the row (`ase 0`, `ekwan 0`, `scaled false`, `keep_on_defeat false`, one entry with `fate: gathered`, `reason_key: ok`). |
| same | `is_item_row`, `open_item_rows` | New. An item row is a row whose `items` array is not empty. `open_item_rows` = unsettled and not lost, in row order. |
| same | `held_fates_of`, `has_held_fate`, `put_held_fate` | New. One owner for `stage.held_fates`. A new record replaces the older record of the same piece id. |
| same | `plan` | `sources["item"]` added (`rows`, `ase`, `all`). The sums are unchanged. |
| `core/economy/StageSettlementService.gd` | `settle_plan` | New keys `item_rows` and `held_pieces`. `nothing_new` is true only with no Ase, no Ekwan, no open item row and no held piece. Doc comment updated. |
| same | `settle_leave` | Outcome roll code and stream are unchanged. Currency rows are marked from `currency_ids` (plan ids minus item rows). Item handling runs after the currency mark (`_settle_leave_items`). The result gains `items`. The `economy.settle.leave` log has the same fields; `marked_ids` is `currency_ids`. A new log `economy.settle.items` is written only when an entry exists. |
| same | `_settle_leave_items`, `_keeps`, `_settle_item_row`, `_held_record`, `_report_row`, `_item_report`, `_finish_report` | New helpers. `_settle_item_row` is shared with the path end. |
| same | `settle` and new `_bank_item_rows` | After the currency payout and `request_save`: open item rows go to `intake` (`gathered`) in row order, rows are marked settled with share 100, then `move_pack_to_sanctum`. The payout gains `items`. Log `economy.stage.items` when a row exists. |
| `core/realms/ActiveStageService.gd` | `record_found_items` | New seam (ITEM-002 calls it). |
| same | `lose_unsettled_packs` | Item entries get `fate: lost`, `reason_key: defeat`. Every held piece leaves the pack through `remove_held` and gets a `held_fates` record (`token: "defeat"`). Return value is still the number of rows lost (item rows included). The log `economy.earnings.lost` gains `items` and `held`, and is also written when only held pieces were removed. |
| `tests/ItemPacksCharacterizationTests.gd` | see below | Two defects inverted, whole-dict assertions extended. |
| `tests/ItemPacksTests.gd` (+ `.uid`) | new suite `item_packs`, 16 tests | |
| `ui/AppRoot.gd` | one line after `inventory_service` | registers the suite |
| `scripts/test-shard-map.sh` | shard12 | `item_packs` added (24 suites, est 102 s) |
| `AGENTS.md` | counts | 140 to 141 (two places), name in the list and in the "added since" sentence |

`preview()` is not changed (it is read-only and the item count is not trivial there).

## Exact call sites

| Call | Site |
|---|---|
| `ActiveStageService.record_found_items(flow_ctx, situation_id, finds, t)` | No production caller yet. ITEM-002 calls it beside `record_fight_earnings` (`FlowEncounterState.gd:222`). It requests the save itself (`economy.earnings.items`) when it writes a row. |
| `settle_leave` | `VentureController.gd:365`. The caller reads `ase`, `ekwan`, `intel_count`, `outcome` only. The new `items` key is not read yet (UI step). |
| `settle` | `VentureController.gd:686`. |
| `lose_unsettled_packs` | `FlowEncounterState.gd:224` (defeat). The return value is ignored there. |
| `InventoryService` calls | `held_pieces`, `remove_held`, `move_pack_to_sanctum`, `intake(..., "gathered", reserved, logger, t)`, `pack_free`, `take_in_order`. Config: `ConfigService.get_inventory_cfg(config_service)`. |

## Rules as built

### `record_found_items`
1. Row id = `item:<situation_id>:<find_id>` (see Review fixes).
2. A find whose row already exists is skipped (exactly-once by row id).
3. `free = pack_free(save, cfg, open item rows)`. `take_in_order(fresh, free)` picks the first `free` fresh finds.
4. Each taken find becomes one row through `record_item`. Finds beyond the room are not gathered and not lost by a cap.
5. Returns `{ taken, left }` with the caller's `find_id` values. One `economy.earnings.items` log line (`taken`, `left`, `free`) per call that has a fresh find. `request_save` only when a row was written.

### Leave (after the unchanged outcome roll)
1. Entries = open item rows in row order, then held pieces in pack order. A held piece with a `held_fates` record of this settle's token (`<run_count>.<settle_count>`) is left out.
2. Outcome `none`: every entry is lost, reason `leave_none`. `all`: every entry is carried. `some`: one draw per entry.
3. Draw: `CampaignSeed.get_rng_from(realm.seed, "inventory.leave.<stage_id>.<run_count>.<settle_count>.<row|held>.<id>").randi_range(0, 99) < roundi(share * 100)`. `settle_count` is the value read before the increment. One new rng per entry, one draw each. No draw for `none`, `all`, or when there is no entry.
4. Order of effects: lost held pieces are removed (`remove_held`) and recorded; `move_pack_to_sanctum`; held survivors are recorded `carried` with reason `ok` (now in the Sanctum) or `to_pack` (still held); open item rows in row order: kept rows go to `intake` (`gathered`), lost rows get `fate: lost`. Each row ends `settled: true` with `settled_share` 100 or 0.
5. Intake result to entry fate: `stored` -> `carried`/`ok`; `packed` -> `carried`/`to_pack`; `partial` -> `carried`/`stack_limit`; `lost` or `rejected` -> `lost` with the intake reason.
6. Result `items` = `{ kept, lost, kept_count, lost_count }`. A row is `{ type_id, kind, grade, quantity, reason_key }`. No id.

### Defeat, path end
Defeat and path end are as in the table above. Path end draws nothing and writes no `held_fates`.

## Characterization changes (item-free assertions)

| Test | Change |
|---|---|
| `plan_with_zero_rows`, `plan_with_objective_rows_only`, `plan_with_fight_and_found_rows` | Whole-dict `settle_plan` expectation gets `item_rows: 0, held_pieces: 0`. The `sources` expectation in `plan_with_zero_rows` gets `item: { rows 0, ase 0, all 0 }`. |
| `add_row_rejects_empty_currency_and_duplicate_id` | Inverted: the item-only row is now accepted. Empty id and repeated id still rejected. A 0/0 row with no item is rejected (new line). |
| `nothing_new_ignores_items` | Inverted and renamed `nothing_new_counts_items`: `nothing_new` false, `item_rows` 1, the leave draws roll 90 and settles the row, defeat still loses the row. |
| The other 6 step 1 tests | Untouched. All pass. |

No recorded value moved. No fixture or constant was re-recorded.

## Tests

Environment: `/tmp/claude-0/godot-bin/godot`, `ECHOES_TEST_SAVE_DIR=/tmp/claude-0/echoes-saves-step4/` (deleted before each run). Compile check: 0 errors. `--import` run once (new `class_name ItemPacksTests`), clean.

| Run | `Tests:` line |
|---|---|
| `=item_packs,item_packs_char,inventory_service,inventory_save` | `Tests: 64 total, 64 passed, 0 failed` |
| `=econ_char,economy` | `Tests: 112 total, 112 passed, 0 failed` |
| `=payout_ui,stop_short,save_integrity` | `Tests: 129 total, 129 passed, 0 failed` |
| `=snapshot_purity,snapshot_contract` | `Tests: 20 total, 20 passed, 0 failed` |
| `=item_packs` alone | `Tests: 16 total, 16 passed, 0 failed` |
| `scripts/check-shard-map.sh` | `SHARD MAP CHECK: OK (141 registered suites, each in exactly one of 13 shards or the merge step).` |

Not run (by instruction): `reward`, `combat_*`, `fingerprint_*`, `maturity_baseline`, the full and sharded suites.

### `item_packs` tests (16)
`earnings_item_rows`; `found_items_fit_and_exceed_the_room` (fits, exceeds, row ids by index, repeat writes nothing, held piece takes a slot, full pack, empty situation id, log line, save request); `plan_counts_items_and_held_pieces`; `item_only_pack_draws_the_outcome_roll` (seeds 0, 1, 2: rolls 0, 57, 90); `outcome_stream_equals_the_item_free_value` (rolls and pays 0/0, 39/7, 78/14 with item rows and a held piece present; `marked_ids` hold no item id); `some_draws_do_not_depend_on_order_or_other_entries`; `held_pieces_are_rolled` (only held pieces; none; all); `repeat_leave_draws_held_pieces_again`; `survivor_stays_held_when_the_sanctum_is_full`; `retry_after_a_partial_state_does_not_redraw`; `defeat_loses_item_rows_and_held_pieces_once`; `path_end_banks_item_rows_once`; `path_end_with_a_full_sanctum_keeps_pieces_held`; `json_round_trip_between_phases_gives_the_same_result` (six phases, JSON between each phase, final save and phase results equal; a leave replayed from a saved state equals the first); `item_free_results_equal_step_1`; `no_placeholder_id_in_config_or_core`.

Pinned draws (written as literals in the tests and recomputed from the stream names):

| Seed | Stream | Values |
|---|---|---|
| 0 / 1 / 2 | `stage.settle.stage.0.0.0` | 0 (none) / 57 (some) / 90 (all) |
| 1 | `inventory.leave.stage.0.0.0.row.item:s0:0..3` | 14, 2, 65, 67 (keep below 50) |
| 1 | `inventory.leave.stage.0.0.0.held.it.1..4` | 69, 33, 66, 90 |
| 7 | `stage.settle.stage.0.0.0` / `...0.0.1` | 99 (all) / 63 (some) |
| 7 | `inventory.leave.stage.0.0.1.held.it.1..4` | 59, 42, 85, 54 |

Mutation checks done by hand (each restored, tree diff re-checked): settle_count fixed to 0 in the draw path -> `repeat_leave_draws_held_pieces_again` fails; kind token changed -> 4 tests fail; token filter removed -> `retry_after_a_partial_state_does_not_redraw` fails; held removal removed from defeat -> defeat test fails; held count removed from `nothing_new` -> 4 tests fail. (First draft of the repeat-leave test used 2 held pieces and did not catch the fixed settle_count; seed 7 draws on counts 0 and 1 gave the same keep pattern for 2 pieces. It uses 4 pieces now.)

## Assumptions

1. An item row is any row with a non-empty `items` array, whatever its `source`. A row with both currency and items is not supported: its currency would be marked by neither path. `record_item` is the only writer.
2. `unique_cap` and `pack_capacity` come from the cfg of the context's `ConfigService`. A save without an `inventory` block makes `intake` return `rejected/bad_state`; the entry is then lost with that reason. Real saves always have the block (step 2 repair).
3. Idempotency of `record_found_items` is by row id. A find left for lack of room is not remembered. If room opened between two calls for the same situation (it cannot inside one fight), the repeat would gather it.
4. Quantity is in the report row (not in the brief). A stack result screen needs it.
5. Held `held_fates` records are also written for survivors (`fate: carried`). Without them a token could not stop a second draw of a survivor. The records are one per piece id (a newer record replaces the older one), so the list is bounded by the pieces.
6. Defeat token is the literal `defeat`. The defeat does not set `encounter_ctx.packs_lost` item counts (UI step). The counts are in the log only.
7. For the leave, a held survivor's `reason_key` is `to_pack` when it is still in the pack after `move_pack_to_sanctum`, else `ok`.
8. `intake` gets `reserved` = open item rows (it only matters in `direct` mode).
9. A leave that lost all held pieces and rows still increments `settle_count` (it drew the roll). An item-free, held-free pack still draws nothing and changes nothing.

## What an Opus reviewer must attack

1. **Outcome roll unchanged.** The roll code, the stream name and the `settle_count` read are untouched. Check the diff of `settle_leave` for any line before `var roll`. The only change that touches the old path is `currency_ids` replacing `plan["ids"]` in `mark_settled` and in `marked_ids`; for an item-free pack the two lists are equal.
2. **Item-free byte equality.** Claim: with no open item row and no held piece, every result and every save byte equals step 1. Evidence: 6 untouched step 1 tests, `econ_char` (103 tests) and `item_packs/item_free_results_equal_step_1`. Weak spot: `settle` now calls `move_pack_to_sanctum` always. It rewrites `inventory.pack` to a new empty array (JSON equal) and does nothing when the block is missing. The payout dict has a new `items` key, and `settle_plan` has two new keys. Check every reader of those dicts that compares or serializes them whole (the snapshot builder reads named keys only).
3. **Draw order and names.** One new rng per entry, keyed by id, one draw. Check that no draw happens for `none`, for `all`, or with no entry (the early return before the draw loop, and the held filter).
4. **`settle_count` on a retry.** The draw uses the pre-increment value. The increment is the last stage write of the call. Attack a flow where the stage is saved between the item effects and the increment (there is no flush inside the call).
5. **Exactly-once.** Leave: row `settled` mark plus held token. Path end: receipt plus row `settled`. Defeat: `lost` flag plus an empty pack. Attack: path end after a leave (rows are settled, not banked again; tested), defeat after a leave, a reload between `intake` and the row mark (both are in-memory in one call, flushed once).
6. **Reload mid-handoff.** `_t_round_trip` reloads between phases, not inside a call. A crash inside a call loses the whole call (the save is written after it).
7. **Pack capacity.** `gathered` intake can lift the pack above `pack_capacity` (known from step 3). `record_found_items` reserves one slot per open row, so only a path-end/leave carry-over of a row onto a full Sanctum can add held pieces, never above the slots reserved.
8. **Held pieces and `nothing_new`.** A held piece makes every leave draw the roll, on any stage, even one with no gathered row (design section 10). Attack: a player with a held piece who leaves a stage at once burns a `settle_count` and may lose the piece.
9. **Hybrid rows** (assumption 1) and **dict order**: `put_held_fate` replaces by id, so `held_fates` order is write order, not id order.
10. **`rejected` intake result** is mapped to `lost`. Check `unknown_type` with a non-empty `definitions` in shipping config.

## Review fixes (Opus review)

| Fix | File | Test (suite `item_packs`) | Result |
|---|---|---|---|
| F-1 `record_found_items` refuses a find that intake would reject. New `InventoryService.check_entry(cfg, entry) -> String` ("" or reason key); `_intake` calls it too (the quantity checks moved out of `_intake_stack` and `_intake_unique`). Refused finds go to `refused`, take no slot, and are counted once in `economy.earnings.items`. | `core/inventory/InventoryService.gd`, `core/realms/ActiveStageService.gd` | `found_items_refuse_what_intake_rejects` (bad kind, disabled kind, unique quantity 2, unknown type, stack quantity 0, no `find_id`; a valid find after them takes the slot) | pass |
| F-2 A `partial` intake sets the entry `quantity` to the stored quantity and keeps `lost_quantity` on the entry and in the `kept`/`lost` report rows (key only when above 0). | `core/economy/StageSettlementService.gd` | `partial_stack_keeps_the_stored_quantity` (leave and path end) | pass |
| F-3 One `held_record` builder in `EarningsService`; leave and defeat call it; the duplicate is deleted. | `EarningsService.gd`, `StageSettlementService.gd`, `ActiveStageService.gd` | existing held-fate tests | pass |
| F-4 Row id = `item:<situation_id>:<find_id>`. `item_id` and `record_item` take a String `find_id`. | `EarningsService.gd`, `ActiveStageService.gd` | `found_items_in_another_order_do_not_gather_twice` | pass |
| F-5 `items` and `held` keys on `economy.earnings.lost` only when above 0. | `ActiveStageService.gd` | `defeat_log_counts_items_and_keeps_the_item_free_payload` (item-free key list is `stage_id, rows, ase, ekwan`) | pass |
| F-7 A row whose entry intake lost gets `settled_share` 0. | `StageSettlementService.gd` | `rejected_intake_is_lost_with_its_reason`; `item_packs_char/nothing_new_counts_items` now expects 0 (its entry is rejected with `bad_state`) | pass |
| Extra | | `rejected_intake_is_lost_with_its_reason` (`unknown_kind`, `kind_disabled`, `bad_entry`, `unknown_type` give fate lost with the reason); `held_only_leave_returns_items_and_currency_keys` | pass |

Item-free behaviour: no change. The six untouched step 1 tests, `econ_char` and `economy` pass.

Tests (`ECHOES_TEST_SAVE_DIR=/tmp/claude-0/echoes-saves-step4fix/`): `=item_packs` 22/22; `=item_packs,item_packs_char,inventory_service,inventory_save` 70/70; `=econ_char,economy` 112/112; `=payout_ui,stop_short,save_integrity` 129/129; `=snapshot_purity,snapshot_contract` 20/20. Compile check: 0 errors.

### Contract for ITEM-002 (`record_found_items`)

1. Each find is `{ find_id, type_id, kind, grade, quantity }`. `find_id` is a non-empty String. The caller sends the same `find_id` for the same find on every call, in any order. A find without it is refused with `bad_entry`.
2. Returns `{ taken, left, refused }`. `taken` and `left` are lists of `find_id`. `refused` is `[{ find_id, reason_key }]` with the `check_entry` reason (`unknown_kind`, `kind_disabled`, `bad_entry`, `unknown_type`). A refused find is not gathered and is not retried by the seam.
3. A find that is not a Dictionary is refused with `find_id` "" and `bad_entry`.

## OPEN — questions and assumptions

ASSUMED: An item row is a row with a non-empty `items` array; a hybrid row (currency and items) is out of scope.
ASSUMED: `held_fates` records are written for held survivors too (`fate: carried`), one record per piece id.
ASSUMED: Defeat token is `defeat`; defeat item counts go to the log, not to `encounter_ctx.packs_lost` (the defeat card is a UI step).
ASSUMED: The report row carries `quantity` beside the four fields in the brief.
ASSUMED: `record_found_items` is idempotent by row id, not by a stamp for left finds.
ASSUMED: The renamed characterization test (`nothing_new_counts_items`) is allowed; the step 1 report still names the old test.
BLOCKED: None.
ACCEPTED (F-6, F-8): recorded from the review; no code change in this pass.
