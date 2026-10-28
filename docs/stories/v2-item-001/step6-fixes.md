# V2-ITEM-001a step 6: fix pass

Author role: mechanics-developer. Date: 2026-10-28. Written in STE. No commit. Source: `step6-qa-report.md`, decision D-28.
Rule for every new snapshot key (D-28): a key appears only when it holds something. One exception is B4 (see ASSUMED 2).
No recorded value moved. No fixture, hash or constant was re-recorded.

## Findings and changes

| Id | What changed | File: function |
|---|---|---|
| B1 | The leave item report travels in the flow context, into the scout-return card, into the durable result, and back on replay. `build_scout_return_snapshot` calls `add_items`. `PendingResultService.build_snapshot` replays `items` when the stored data has it. The dispatch closure resets the field with its siblings. | `FlowContext.gd`: field `pending_scout_return_items`. `VentureController.handle_return_home`. `ResolveSnapshotBuilder.add_items` (new block 14g). `VentureResolveSnapshotBuilder.build_scout_return_snapshot`. `PendingResultService.build_snapshot`. `FlowRuntime.dispatch` closure. `StageSettlementService.card_items` (new). |
| B1 rows | Report rows now carry `source` ("held" or "gathered") and `mark_index`. One builder for leave, defeat and path end. The private `_report_row` was deleted. | `EarningsService.at_risk_row`, `EarningsService.report_row` (new). `StageSettlementService._settle_leave_items`, `_settle_item_row`. |
| L8 | The path-end report (`payout["items"]`) is kept. `handle_complete_stage` stores it in `pending_stage_clear_items` (only when non-empty). The Sanctum snapshot shows it once. The dispatch closure clears it. See ASSUMED 3. | `VentureController.handle_complete_stage`. `FlowContext.pending_stage_clear_items`. `SanctumSnapshotBuilder.build`. `FlowRuntime.dispatch` closure. |
| B2 | `lose_unsettled_packs` builds the report (item rows first, then held pieces) and puts it in `encounter_ctx.packs_lost.items`. If no Ase or Ekwan was lost, `packs_lost` is created with `lost_ase` 0 and `lost_ekwan` 0. The return value (row count) and the signature did not change. No second static was needed. The defeat card copies `items` into the `packs_lost` breakdown `params`. | `ActiveStageService.lose_unsettled_packs`. `FlowEncounterState.build_final_snapshot` (breakdown params). |
| B3 | `carry_home_preview.items_at_risk` is added only when an open item row or a held piece exists. I reuse `items_at_risk` (non-empty) and add no boolean. `nothing_new` was already false in that case (step 4), so both agree. | `StageExploreSnapshotBuilder._carry_preview`. `StageSettlementService.items_at_risk` (new). |
| B4 | `flow.echo_party` `data.inventory` = `InventoryService.snapshot(save, cfg, open rows in the save)`. | `FlowEchoPartyState.build_snapshot`. |
| M1 | `stage.return_home` is refused with `not_on_path` unless the last snapshot type is `FlowStateIds.STAGE_EXPLORE`. The refusal logs `stage.return.denied`, settles nothing, draws nothing, saves nothing. | `VentureController.handle_return_home`. |
| M2 | One static counts open item rows over every Realm and stage. Used by `record_found_items`, the Sanctum `reserved`, the `flow.echo_party` projection. The `path_open` check keeps its live-stage meaning. | `EarningsService.open_item_rows_in_save` (new). `ActiveStageService.record_found_items`. |
| M3 | `data.inventory.discard_blocked` ("path_open") is in the Sanctum snapshot only when blocked. The key is absent otherwise, so the Sanctum fingerprint is not affected. The controller and the snapshot call the same function. | `ActiveStageService.discard_block_reason` (new). `SanctumSnapshotBuilder.build`. `InventoryController.handle_discard` (its private `_path_open` was deleted). |
| M4 | The same function also blocks a live, unsettled path whose pack holds a piece. See ASSUMED 1 for the escaped exception. | `ActiveStageService.discard_block_reason`. |
| L1 | `data.inventory.mark_count` (6) with comment in `balance.json`. `InventoryService.mark_count(cfg)` reads it (fallback 6 for missing, 0, negative or wrong type). `mark_index_of(cfg, id)` is the one function for snapshot rows and report rows. | `InventoryService`. `data/balance.json`. |
| L5 | `_run_inventory_command` prints a line and returns unless `OS.is_debug_build()`. The core action is unchanged. | `ui/AppRoot.gd`. |
| L6 | A repeated `find_id` inside one `record_found_items` call is refused with `duplicate_find`. The first copy stands. | `ActiveStageService.record_found_items`. |
| L7 | Not changed. The header of `scripts/test-shard-map.sh` says shards go in descending time order. It does not say suite lists are sorted. | none |
| L2 | Fixed by M2 (Sanctum `reserved`). | |
| L3, L4 | Not in this brief. No change. | |

## New snapshot keys for the UI step

All keys hold no id. A row is called a "report row" below.

Report row (rows replayed from the durable result come back from JSON with float `quantity` and `mark_index`: the UI must read both with `int()`; the data is not changed): `{ type_id: String, kind: String, grade: String, quantity: int, source: "held"|"gathered", mark_index: int, reason_key: String }`, plus `lost_quantity: int` only when a stack surplus was lost. `mark_index` is the piece mark (0 to `mark_count` - 1). It is -1 when the item has no piece id: a stack, a lost gathered item, or an at-risk gathered item. A kept gathered unique piece has the mark of the piece intake made.
At-risk row: the same without `reason_key`.

| Where | Key | Shape | Present when |
|---|---|---|---|
| `flow.resolve`, `run_type` "scout_return" (also the replayed card) | `data.items` | `{ kept: [report row], lost: [report row] }` | at least one row. Absent for an item-free leave. Reasons: kept `ok`, `to_pack`, `stack_limit`; lost `leave_none`, `leave_some`, `overflow`, and the intake reasons. |
| `flow.stage_explore` | `data.carry_home_preview.items_at_risk` | `[at-risk row]`, open item rows first (row order), then held pieces (pack order) | an open item row or a held piece exists. `nothing_new` is then false. |
| `flow.resolve` (defeat) | `data.reward_breakdown[cause == "packs_lost"].params.items` | `[report row]`, reason `defeat`; rows first, then held pieces | an item row or a held piece was lost. The `packs_lost` row now also appears for an item-only or held-only defeat, with `params.lost_ase` 0 and `params.lost_ekwan` 0. An Ase-only defeat keeps `{ lost_ase, lost_ekwan }` exactly. |
| `flow.echo_party` | `data.inventory` | the same projection as `flow.sanctum` `data.inventory` | always (ASSUMED 2) |
| `flow.sanctum` | `data.inventory.discard_blocked` | `"path_open"` | only when the discard is refused (open item row anywhere in the save, or an entered, unsettled path with a held piece) |
| `flow.sanctum` | `data.inventory.pack_load`, `pack_free`, `warn.pack` | `reserved` is now the open item rows of the whole save | always (item-free values do not change) |
| `flow.sanctum` (after `flow.complete_stage` with destination `flow.sanctum`) | `data.stage_clear_items` | `{ kept: [report row], lost: [report row] }` | the path end banked or lost an item. One build, then gone. |

New refusal and reason keys: `not_on_path` (`stage.return_home`), `duplicate_find` (`record_found_items` `refused`), `path_open` (discard, widened by M4).

## Item-free byte equality

| Result | Evidence |
|---|---|
| Item-free `carry_home_preview` | `item_packs/carry_preview_lists_items_at_risk_only_when_any` compares the sorted key list with the old keys. |
| Item-free scout-return card | `inventory_actions/item_free_leave_card_has_no_items_key` (card keys and preview keys). |
| Defeat with Ase only, defeat with nothing lost | `item_packs/defeat_card_carries_the_lost_items` (cases 4 and 5: exact `{ lost_ase, lost_ekwan }`, empty `packs_lost`). |
| Item-free path end | `inventory_actions/path_end_item_report_reaches_the_destination_snapshot` (no `stage_clear_items`). |
| `flow.echo_party` | the only new key is `data.inventory` (`sanctum_and_party_prep_count_open_rows_of_every_realm`). |
| Sanctum | no `discard_blocked` key without a block; `snapshot_fingerprint` passes with the recorded hash. |
| Whole paths | `snapshot_fingerprint` 2 of 2, `save_integrity`, `econ_char` 103 of 103, `pending_result`, `payout_ui` pass. |
| Item rows in the leave `items` result | The step 4 whole-row assertions in `item_packs` (`held_pieces_are_rolled`, `partial_stack_keeps_the_stored_quantity`) gained `source` and `mark_index`. These are the only existing assertions that changed. They concern item results, not item-free results. |

## Stale text fixed

| Text | Fix |
|---|---|
| `FlowRuntime.gd` arm count comment | Was "75 of the 81". Counted: 81 match arms (the test regex), minus the 6 inline `flow.*` arms (`new_game`, `advance`, `go_state`, `continue`, `settings`, `quit`) = 75 routed actions; 6 of those are the combat arms FlowRuntime owns, so 69 go to a controller in one line. The old text 67 of 73 was right for 79 arms; two controller arms were added (+2). Now "69 of the 75". |
| `InventoryController.gd` header | "on no path" removed. It states the `path_open` rule and its owner. |
| `design-sr-game-designer-v2.md` | `no_room` removed; row id `item:<situation_id>:<find_id>`; `add_row` and `nothing_new` facts are marked fixed in step 4; the defeat report is `packs_lost.items`; the tile row is in 001a (D-23); the reason key list. |
| `step4-packs-rules.md` | helper names (`EarningsService.held_record`, `report_row`), test count, `record_found_items` return shape, report row shape. |
| `step1-characterization.md` | test name (renamed `nothing_new_counts_items` in step 4). |
| Not edited (docs are step 8) | `docs/MEMORY.md`, `docs/integration-map.md`, `CONVENTIONS.md`. `step5-actions.md` still describes the D-27 `path_open` rule only; this file extends it. |

## Tests

Environment: `ECHOES_TEST_SAVE_DIR=/tmp/claude-0/echoes-saves-step6fix/` (deleted before each run). Compile check `--headless --check-only --quit`: zero errors. No new suite, no `.uid`, no `--import`.

| Run | `Tests:` line |
|---|---|
| `=item_packs,item_packs_char,inventory_actions,inventory_service,inventory_save` | `Tests: 98 total, 98 passed, 0 failed` (item_packs 28, inventory_actions 21, inventory_service 23, item_packs_char 11, inventory_save 15) |
| `=flow_transaction,snapshot_purity,snapshot_contract,snapshot_fingerprint,save_integrity,pending_result` | `Tests: 63 total, 63 passed, 0 failed` |
| `=payout_ui,stop_short,foundation_ui,sanctum.layout,sanctum.party,echo_party,realm_ui,econ_char,economy` | `Tests: 300 total, 300 passed, 0 failed` |
| `=traversal,seam,venture_char` (extra: they dispatch `stage.return_home`) | `Tests: 121 total, 121 passed, 0 failed` |

The harness moved the third run to the background once, because the tool call hit its own 120 s limit while it ran the three groups in a loop. It finished with the line above. Nothing else ran in parallel.

New tests (14: 6 in `item_packs`, 1 in `inventory_service`, 7 in `inventory_actions`):

| Test | Covers |
|---|---|
| `item_packs/report_rows_carry_source_and_mark_index` | B1 rows, L1 (`mark_count` 4 and default), kept and lost cases |
| `item_packs/card_items_keeps_only_a_non_empty_report` | B1 helper |
| `item_packs/carry_preview_lists_items_at_risk_only_when_any` | B3, item-free keys, order, settled row, held only, rows only, purity |
| `item_packs/defeat_card_carries_the_lost_items` | B2: rows only, held only, both with Ase, Ase only, nothing lost, JSON round trip |
| `item_packs/a_repeated_find_id_in_one_call_is_refused` | L6 |
| `item_packs/pack_room_counts_open_rows_in_every_realm` | M2 (rows open in realm A, gather in realm B) |
| `inventory_service/mark_count_comes_from_the_config` | L1 (also the `balance.json` value and comment) |
| `inventory_actions/leave_item_report_reaches_the_card_and_survives_a_reload` | B1 chain with a real dispatch, preview, durable result, JSON reload and `PendingResultService` replay |
| `inventory_actions/item_free_leave_card_has_no_items_key` | D-28 byte rule for the card |
| `inventory_actions/return_home_is_refused_off_the_path` | M1: second `stage.return_home` and one from the Sanctum are refused; save byte-equal to after the first |
| `inventory_actions/path_end_item_report_reaches_the_destination_snapshot` | L8 |
| `inventory_actions/discard_blocked_key_and_the_live_path_rule` | M3, M4: no live stage allowed; back-route state with held pieces and 0 open rows refused; escaped, settled, empty pack allowed; open row refused |
| `inventory_actions/sanctum_and_party_prep_count_open_rows_of_every_realm` | M2 snapshot, B4 |
| `inventory_actions/the_console_producer_is_gated_to_debug_builds` | L5 (source check: the gate comes before the dispatch; no gate in `core/`) |

Mutation checks by hand (each restored, `git diff --stat` re-checked): M1 guard off makes `return_home_is_refused_off_the_path` fail; `record_found_items` back to the live-stage count makes `pack_room_counts_open_rows_in_every_realm` fail; removing the context reset in the dispatch closure makes the leave chain test fail.

## Assumptions

1. **M4 and an escaped path.** The brief says "a live, unsettled path". After an early leave the stage keeps no receipt and `flow_ctx.stage_id` stays set (only a realm end clears it). With the literal rule, a player who leaves early with surviving held pieces and a full Sanctum could not discard in the Sanctum until the next path. The leave draw already happened, so a discard there dodges nothing. I treat a party that left (`explore_map.party_state == "escaped"`) as not live. One line in `ActiveStageService.discard_block_reason` removes this exception. Test: `discard_blocked_key_and_the_live_path_rule`, case (c).
2. **B4 key is always present.** D-28 lists "party-prep inventory" among keys that appear only when they hold something. The brief for B4 says to add the projection and to check hashes. The projection holds config numbers, so it is never empty, like the Sanctum's. No test hashes `flow.echo_party` data (grep of `tests/`, only `snapshot_fingerprint` covers the Sanctum and the path). If the key must be conditional, change the one line in `FlowEchoPartyState.build_snapshot`.
3. **L8.** After `settle()` there is no result snapshot: `handle_complete_stage` returns a transition. I carried the report to the snapshot that dispatch publishes when the destination is `flow.sanctum` (the key `stage_clear_items`). With the default destination (`flow.stage_map`) or a realm end, the report is spent without being shown. I did not add the key to the stage map snapshot.
4. `mark_index` is -1 for an item without a piece id (stacks, gathered rows at risk, lost gathered rows).
5. The card block holds `{ kept, lost }` only. The counts (`kept_count`, `lost_count`) stay in the `settle_leave` result.
6. M1 uses the exact type `flow.stage_explore`. The only UI sender of `stage.return_home` is `StageExploreScreen`. The failed-escape overlay and the standoff confirmation are the same type.
7. Superseded by V3 below: `last_snapshot` loses `stage_clear_items` after it is published.
8. A duplicate `find_id` whose first copy is a row from an earlier call is skipped without a refusal (the row exists). Only a duplicate inside one call is refused.

## Verifier findings (second pass)

Source: the independent verifier on the fix pass. Decision: D-29. Environment: `ECHOES_TEST_SAVE_DIR=/tmp/claude-0/echoes-saves-step6fix2/`, deleted before each run. No recorded value moved. No fixture, hash or constant was re-recorded.

D-29 (amends D-28): `flow.echo_party` `data.inventory` is ALWAYS present. The discard guard reads saved state. `stage_clear_items` is erased from `last_snapshot` after it is published. OPEN for Jeff (UI step): where the path-end report shows when the party goes to the stage map.

| Id | Finding | Change | Test | Result |
|---|---|---|---|---|
| V1 | After "Back to the Sanctum", quit and Continue, `flow_ctx.stage_id` is empty, so `discard_block_reason` found no live stage and a discard moved held pieces to safety. | `ActiveStageService.discard_block_reason` now reads saved state only. Rule 1: `EarningsService.open_item_rows_in_save` > 0 gives `path_open`. Rule 2: the pack holds a piece, and the active realm's stage at `current_stage_index` is entered (`explore_map.locked`), has no `settlement_receipt.settled` and is not `escaped`. The stage lookup is new `FlowStageExploreState.stage_by_index(realm_model, index)`. `_get_current_stage` and `StageSettlementService._stage_ref` and `_live_stage` now call it, so there is one owner and no duplicate loop. | `inventory_actions/discard_guard_works_from_saved_state_after_a_reload` (save written, NEW `FlowRuntime` booted from the file; `stage_id` empty and `realm_id` restored are asserted first. Refused: entered path; open row with nothing held. Allowed: never entered, escaped, settled. Plus the live-session never-entered case.) The old `reserved` test now expects `path_open` for an open row in another realm. | pass; mutation (index + 7) fails 3 tests |
| V1b | Second case: select a stage, go back to the Sanctum without entering, pieces held. | PROVEN reachable: `VentureController.gd:551` sets `stage_id`; `FlowStageState.gd:137` `nav.back` goes to `flow.stage_map`; `FlowStageMapState.gd:102` goes to `flow.sanctum`. The old rule refused the discard there although no path is open. Detection of a stage never entered: `explore_map.locked` is false (`FlowStageExploreState._lock_map_if_needed` sets it true on first entry; `StageExploreModel.make` writes false). Such a stage is allowed. | case `never_entered` (reload) and the live-session case | pass |
| V2 | `econ_char/death_record_lifetime` no longer tested D-103 F4: the M1 guard refused the return home. | The test sets the last snapshot to `flow.stage_explore` and asserts the dispatch returned the scout-return card or the failed-escape overlay (`return_home_result`). | `econ_char` | 103 of 103 |
| V2b | Other tests that dispatch `stage.return_home`. | `TraversalModelTests` `_t_fog_durability_return_home` tolerated a refusal: it now asserts the dispatch ran (card or overlay). Not vacuous, no change: `EconomyCharacterizationTests` ~2362 (asserts the card and the balance), `PendingResultTests` ~221 (asserts `flow.resolve`), `Stage004SeamTests` 3844, 3877, 3906, 4159 (assert `party_state` escaped or not against the roll), `VentureCharacterizationTests` 881, 950 (assert the card or the overlay message), `ResolvePayoutUITests` (UI action capture, no runtime). | `traversal`, `seam`, `venture_char`, `pending_result`, `payout_ui` | pass |
| V3 | `stage_clear_items` stayed in `last_snapshot`, so a later dispatch that does not rebuild the snapshot sent it again. | `FlowRuntime.dispatch`: the caller gets a copy with the key; `last_snapshot` loses it (the `return_confirm_requested` pattern). | `path_end_report_is_not_resent_by_a_later_dispatch` | pass; mutation fails |
| V3b | Destination `flow.stage_map`. | No code change. Pinned behaviour: the report is dropped unseen. `pending_stage_clear_items` is cleared at the end of the dispatch, the stage map snapshot has no key, a later Sanctum has none. The settled rows stay in the save. Jeff decides where the report shows. | `path_end_report_is_dropped_when_the_party_goes_to_the_stage_map` | pass |
| V4 | D-29: the party prep inventory stays always present. | No code change. | `party_prep_inventory_is_always_present_and_a_copy`: item-free save, test config (cap 4, pack 3), exact keys and values, equal to the Sanctum projection, and writing into it changes neither the save nor a later build. | pass |
| V5a | The debug producer counted only the live stage for pack room. | `DebugController.handle_inventory_produce` uses `EarningsService.open_item_rows_in_save`. | `inventory_actions` (producer tests) | pass |
| V5b | Replayed report rows come back from JSON with float `quantity` and `mark_index`. | Documented in the report row definition above: the UI reads them with `int()`. Data unchanged. | none | n/a |
| V5c | `_t_mark_count` pinned the shipping `balance.json` value (D-25). | The test checks only that the key is a positive number with a comment. The values come from test configs. | `inventory_service/mark_count_comes_from_the_config` | pass |
| V5d | `the_console_producer_is_gated_to_debug_builds` is a source check. | Not changed: a behaviour test would need `OS.is_debug_build()` faked. OPEN. | none | n/a |
| V6 | Docs and comments. | Line reference in `design-sr-game-designer-v2.md` fixed (`ActiveStageService.gd:551`). `step4-packs-rules.md`: the `economy.earnings.items` log has a `refused` count and also fires for a call with refusals only. The `discard_block_reason` doc states the reload behaviour. The M1 rule is stated once (the `handle_return_home` docstring). Story-history tags ("V2-ITEM-001a B4:", "(L8)", "(M1)", "(M2)", "(M3)", "(L5 (D-28))") removed from the comments I touched. The `FlowRuntime` arm-count comment was verified with the `FlowTransactionTests` regex: 81 arms; inline `flow.*` arms are new_game, advance, go_state, continue, settings, quit (6); 75 routed; combat arms are combat.init, confirm_round, next_actor, encounter.advance, retreat, complete (6); so "69 of the 75" is right. No change. | `flow_transaction` | pass |

Test runs (filtered, one process at a time):

| Run | `Tests:` line |
|---|---|
| `=inventory_actions` | `Tests: 25 total, 25 passed, 0 failed` |
| `=item_packs,item_packs_char,inventory_service,inventory_save` | `Tests: 77 total, 77 passed, 0 failed` |
| `=flow_transaction,snapshot_purity,snapshot_contract,snapshot_fingerprint,save_integrity,pending_result` | `Tests: 63 total, 63 passed, 0 failed` |
| `=payout_ui,stop_short,foundation_ui` | `Tests: 124 total, 124 passed, 0 failed` |
| `=sanctum.layout,sanctum.party,echo_party,realm_ui` | `Tests: 64 total, 64 passed, 0 failed` |
| `=econ_char,economy` | `Tests: 112 total, 112 passed, 0 failed` (econ_char re-run alone after the V2 edit: 103 of 103; economy 9 of 9) |
| `=traversal` / `=seam` / `=venture_char` | 61 of 61 / 44 of 44 / 16 of 16 |

New tests: 4 in `inventory_actions`. OPEN (core duplicate): none left; `_live_stage` and `_stage_ref` in `StageSettlementService` are one-line calls to `stage_by_index` / `_get_current_stage`.


## OPEN — questions and assumptions

ASSUMED: 1. An escaped party is not a live path for the M4 discard rule (Jeff may reverse; one line).
ASSUMED: 2. Settled by D-29: `flow.echo_party` `data.inventory` is always present.
ASSUMED: 3. The path-end report is shown on the Sanctum snapshot only (`data.stage_clear_items`).
ASSUMED: 4. `mark_index` -1 means "no piece id yet".
ASSUMED: 5. Cards carry `{ kept, lost }` without counts.
ASSUMED: 6. `stage.return_home` is allowed only from `flow.stage_explore`.
ASSUMED: 7. A stage counts as entered when `explore_map.locked` is true. A stage never entered does not block a discard (V1b).
ASSUMED: 8. Any open item row in the save blocks a discard, also one in another realm (D-29).
OPEN: `the_console_producer_is_gated_to_debug_builds` stays a source check (V5d).
BLOCKED: None.
QUESTION (Jeff, UI step): where must the path-end kept and lost row show when the party goes to the stage map and not to the Sanctum? It needs a decision before the UI reads `stage_clear_items`.
