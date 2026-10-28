# V2-ITEM-001a step 6: combined-tree QA (independent verifier, opus)

Written in STE. Verifier: an agent that built none of steps 1 to 5. Tree: HEAD `a026e8a`. Method: read-only (no Godot run by the verifier).
Fresh sharded full suite on that tree, run by the main chat: `COMBINED: 2630 total, 2630 passed, 0 failed`.

## Result

The verifier found no defect in 001a that loses an item without a record, duplicates an item, or reuses an id. Item draws are deterministic. Item-free results do not change. The conformance matrix for D-01 to D-27 shows HOLDS for every decision that belongs to 001a. D-07 and D-12 to D-15 are NOT-IN-001A (later stories or 001b). D-23 is BROKEN for the UI (B1 to B3).

## Blockers for the UI step (core data missing)

| # | Gap | Where | Fix |
|---|---|---|---|
| B1 | `settle_leave` returns `items`; the caller drops it; a reload loses it. | `VentureController.gd:365-370`, `VentureResolveSnapshotBuilder.gd:88`, `PendingResultService.gd` | Keep the leave item report in the flow context, write it into the scout-return snapshot, replay it from the stored result. Add `source: held\|gathered` to report rows. |
| B2 | An item-only defeat sets no `packs_lost`; the defeat card has no item data. | `ActiveStageService.gd:543-544`, `FlowEncounterState.gd:384` | Return a lost-item report (rows and held pieces, no ids) and put it in `packs_lost.items`. |
| B3 | The leave confirmation has no at-risk list. | `StageExploreSnapshotBuilder.gd:491-495` | Add `carry_home_preview.items_at_risk` from open rows and held pieces. |
| B4 | `flow.echo_party` has no pack data for party prep and the departure chip. | `FlowEchoPartyState` | Add the inventory projection to that snapshot. |

## Medium defects

| # | Defect | Fix |
|---|---|---|
| M1 | A second `stage.return_home` in one tick draws held pieces again. | Refuse `stage.return_home` unless the party is on a path. |
| M2 | Open item rows left in one Realm are not counted against pack room in the next Realm. | Count open item rows across all Realms for pack room, the snapshot `reserved` and `record_found_items`. |
| M3 | Discard refusals are invisible to the UI. | Put `discard_blocked` (`""`, `path_open`, ...) in the snapshot. |
| M4 | A discard on a live path with held pieces and no open rows moves held pieces to safety. | Also refuse the discard while a live, unsettled path holds held pieces (main chat decision; Jeff may reverse). |

## Low items

L1 `mark_index` repeats every 6 ids and `_MARK_COUNT` is hard-coded: move to config `data.inventory.mark_count` (default 6). L2 the Sanctum snapshot uses `reserved` 0 (fixed by M2). L3 `pack_load.level` uses a UI warning threshold: the debuff story must check it before use. L4 save repair drops malformed pieces with a note only. L5 the F1 producer is not gated in a release build: gate it with `OS.is_debug_build()`. L6 a repeated `find_id` in one call is dropped silently: report it as refused. L7 `shard12` list order. L8 the path-end item report `payout["items"]` is dropped by the caller.

## Stale text (to fix)

`FlowRuntime.gd:396` arm count; `InventoryController.gd:7` "on no path"; design file lines about `no_room`, the row id, `add_row`/`nothing_new`, the defeat item counts and tiles in 001a; `step4-packs-rules.md` helper name, test count and return shape; `step1-characterization.md` test name; plan step 4 seed path; `docs/MEMORY.md:404`, `:425` and `docs/integration-map.md:37` still quote 79 dispatch actions (now 81; docs are step 8).

## Questions the verifier raised (answers in `decisions.md` D-28)

Discard while held pieces exist on a live path (M4); gating the F1 producer in release builds (L5).
