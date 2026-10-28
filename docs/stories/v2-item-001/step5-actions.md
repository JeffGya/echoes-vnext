# V2-ITEM-001a step 5: the action path

Author role: mechanics-developer. Date: 2026-10-28. Written in STE. No commit.
STATUS: the Opus review fixes are applied (D-27). The recorded hash is unchanged. See "Moved value".

## Files and functions

| File | Change |
|---|---|
| `core/runtime/controllers/InventoryController.gd` (+ `.uid`) | New. `class_name InventoryController`. `handle_discard(action, t)`. |
| `core/runtime/FlowRuntime.gd` | Arm `"inventory.discard.apply"`, arm `"debug.inventory.produce"`, factory `_inventory_controller()`. 13 added lines. |
| `core/runtime/controllers/DebugController.gd` | `handle_inventory_produce(action, t)`, `_produce_denied`, const `_PRODUCE_FIXTURE`, `_PRODUCE_DEFAULT_IDS`, var `produce_fixture_path` (test seam), header line. |
| `core/state/flow/states/sanctum/SanctumSnapshotBuilder.gd` | `data.inventory = InventoryService.snapshot(save, cfg, 0)`. Last sub-step. |
| `tests/InventoryActionTests.gd` (+ `.uid`) | New suite `inventory_actions`, 13 tests. |
| `tests/FlowTransactionTests.gd` | `EXPECTED_ACTION_COUNT` 79 to 81. Test renamed `dispatch_action_count_is_81`. |
| `ui/AppRoot.gd` | One registration line after `item_packs`. The main chat also added the console command `inventory produce [direct\|gather]` (`_run_inventory_command`), which dispatches `debug.inventory.produce`. |
| `scripts/test-shard-map.sh` | `inventory_actions` added to shard11 (est 103 s, 22 suites). |
| `AGENTS.md` | Suite count 141 to 142 (two places), name in the list and in the "added since" sentence. |

Docs that quote the old guard count 79 (REPORT ONLY, not edited; docs are step 8): `docs/MEMORY.md:404`, `docs/integration-map.md:37`. `CONVENTIONS.md` has none. The dispatch guard checks two things: the match-arm count and that no arm label repeats. The comment in `FlowRuntime.gd` now reads `75 of the 81 actions`: 81 match arms (pinned by the guard test), minus the six combat arms that FlowRuntime owns.

## Action contracts

### `inventory.discard.apply`

| Item | Value |
|---|---|
| Owner | `InventoryController.handle_discard`, routed in `FlowRuntime.dispatch`. |
| Payload | `{ item_id: String }` in `action.payload`. |
| `in_sanctum` | `flow_ctx.last_snapshot.type == FlowStateIds.SANCTUM`. See assumption 1. |
| Calls | `InventoryService.discard(save, cfg, item_id, in_sanctum, logger, t)`. |
| Success outcome | `reenter_outcome()` with save reason `inventory.discard`. FlowRuntime reenters the Sanctum (snapshot rebuilt) and requests one save. |
| Refusal outcome | `error_outcome(reason_key)`: no save reason, no snapshot, no reenter. FlowRuntime ignores `error_code`; the reason is in the outcome (a test reads it) and in the log. |
| Refusal keys | `not_in_sanctum`, `not_unique` (a stack id), `not_found`, `equipped`, `bad_state` (from the service); `bad_payload` (controller: `item_id` missing, empty or not a String); `path_open` (controller, D-27: the last snapshot is `flow.sanctum` and the live path has an unsettled, not-lost item row; found with `FlowStageExploreState._get_current_stage` and `EarningsService.open_item_rows`; no save request, no change). |
| Logs | Success: `inventory.discard` (info, from the service, result `discarded`). Refusal: `inventory.discard.denied` (info, `reason_key`, `item_id`) and, for service refusals, the service line `inventory.discard` with result `refused`. |
| Effect | Piece leaves `items` or `pack`; held pieces move into the Sanctum while room exists (service rule). |

Save intent: the controller reports `save_reasons` on the outcome and `_apply_action_outcome` calls `flow_ctx.request_save`. This is the repo pattern (every controller header says so); the controller does not call `request_save` itself. See assumption 2.

### `debug.inventory.produce`

| Item | Value |
|---|---|
| Owner | `DebugController.handle_inventory_produce`. |
| Payload | `{ ids: Array[String], mode: "gather"\|"direct" }`. Default ids: `ph_weapon_a`, `ph_charm_a`, `ph_relic_a`, `ph_consumable_a`. Default mode `direct`. An empty `ids` array means the default. |
| Fixture | `res://tests/fixtures/inventory_placeholders.json`. The `definitions` are laid over a COPY of the inventory cfg for this call. `balance.json` and the live cfg are never written. |
| Checks (all before any write) | mode valid; fixture exists and parses; every id is in the fixture; `InventoryService.check_entry(overlay_cfg, entry)` passes. One bad id denies the whole call. |
| `direct` | `InventoryService.intake(save, overlay_cfg, entry, "direct", reserved, logger, t)` per id, in order. `reserved` = open item rows of the live stage, or 0. |
| `gather` | Needs `realm_id`, `stage_id` and a stage record. Finds get `find_id` `t<tick>.<index>`, situation id `debug`, then `ActiveStageService.record_found_items`. Rows are `item:debug:t<tick>.<index>`. Containers do not change. |
| Success outcome | Save reason `debug.inventory.produce`. `reenter_outcome()` when the snapshot is `flow.sanctum`, else `handled_outcome()`. |
| Denial outcome | `error_outcome(key)`, no save. Keys: `bad_mode`, `fixture_missing`, `fixture_bad`, `unknown_id`, `no_live_path`, plus any `check_entry` key. Log `debug.inventory.produce.denied`. |
| Piece ids | `it.<n>` like any piece. `type_id` starts `ph_`. |
| Test seam | `DebugController.produce_fixture_path` (var, default the fixture). Only a test changes it. |

## How debug gating works

There is NO gate in `core/`. `FlowRuntime.dispatch` accepts every `debug.*` type from any caller, like `debug.emotion.set` and `debug.stop_short.set`. These actions are reachable in play only because the F1 debug console in `ui/AppRoot.gd` sends them. The producer follows this pattern and adds no gate. A test (`no_other_code_calls_the_producer`) pins who may name the action and the handler: the action string only in `FlowRuntime.gd`, `DebugController.gd` and `ui/AppRoot.gd`; the handler name only in `FlowRuntime.gd` and `DebugController.gd`; `ph_` ids in `core/` only in `DebugController.gd`.

The F1 console command `inventory produce [direct|gather]` in `ui/AppRoot.gd` (added by the main chat) dispatches the action, so Jeff can trigger it in the game.

Release builds: the action is not stripped. Fixture-path dependency (D-27): the producer reads `res://tests/fixtures/inventory_placeholders.json` at runtime. If a build leaves the file out, the action is denied with `fixture_missing`.

## Snapshot field

`flow.sanctum` `data.inventory` (fresh tree on every build, `InventoryService.snapshot(save, cfg, 0)`). `reserved` is 0 in the Sanctum. It is built at `SanctumSnapshotBuilder.build`, so it is present after every enter, reenter and rebuild. `flow.echo_party` does not get it (assumption 3).

| Key | Type | Meaning |
|---|---|---|
| `unique_count`, `unique_cap`, `sanctum_room` | int | `items.size()`, cap, `max(0, cap - count)` |
| `pack_count`, `pack_capacity`, `pack_free` | int | held pieces, capacity, `max(0, capacity - count)` |
| `items` | Array of piece rows | Sanctum pieces |
| `pack` | Array of piece rows | held pieces |
| `stacks` | Array of stack rows | |
| `pack_load` | `{ carried, capacity, free, level }` | level 0 none, 1 light, 2 heavy, 3 full |
| `warn` | `{ room: bool, pack: bool }` | `room` = `sanctum_room <= warn_room_at`; `pack` = carried and `free <= warn_pack_free_at` |

Piece row keys: `id`, `type_id`, `kind`, `grade`, `mark_index` (0 to 5), `equipped` (bool). Stack row keys: `type_id`, `kind`, `quantity`, `limit`, `at_limit`.
Rules for the UI step: the row `id` is for the dispatch payload only; do not print it. Use `mark_index` to tell twins apart. The discard is dispatched by the row with `{ "type": "inventory.discard.apply", "payload": { "item_id": row.id } }`; `snapshot.actions` has NO inventory slot (AGENTS.md: per-row interactions are not slots). No `Thread`, `Ase` or `Ekwan` key exists anywhere in the field (a test scans every key).

## Moved value (resolved by D-27)

| Item | Value |
|---|---|
| Test | `snapshot_fingerprint/sanctum` (`tests/FlowSnapshotFingerprintTests.gd`, `SANCTUM_FINGERPRINT_HASH`) |
| Recorded hash | `a26556e1eaf749a276123e740511222676b7c27f50981573d365042059f832df` (UNCHANGED) |
| Hash before the fix | `39f8b974459a717ffca887fa8dbeaf39c9c06e024721be190097f098b50a95f5` |
| Cause | The new key `data.inventory` in the Sanctum snapshot. PROVED: with `SanctumSnapshotBuilder.gd` at HEAD, the old hash passed. |
| Decision (D-27) | `_fingerprint_projection` erases `data.inventory` only when `snap.type == FlowStateIds.SANCTUM`. Reason: the key carries tunable numbers from `balance.json` (D-25). The `inventory_actions` suite pins the key's shape with its own config. |
| Result | `snapshot_fingerprint` passes 2 of 2 with the recorded hash. Nothing was re-recorded. |

Open point: other `fingerprint_*` suites that hash a Sanctum snapshot were not run in this step (heavy suites). The sharded full suite passed on the step 5 tree (see RUN line).

## Tests

Environment: `/tmp/claude-0/godot-bin/godot`, `ECHOES_TEST_SAVE_DIR=/tmp/claude-0/echoes-saves-step5/` (deleted before each run). `--import` run once (new `class_name` files). Compile check `--check-only`: zero errors.

| Run | `Tests:` line |
|---|---|
| `=inventory_actions` | `Tests: 13 total, 13 passed, 0 failed` (14 after the fixes: `discard_with_an_open_path` added) |
| `=flow_transaction,inventory_service,item_packs,item_packs_char,inventory_save` | `Tests: 79 total, 79 passed, 0 failed` |
| `=sanctum.layout,sanctum.party,sanctum.summon,foundation_ui` | `Tests: 89 total, 89 passed, 0 failed` |
| `=snapshot_purity,snapshot_contract,snapshot_fingerprint,save_integrity` (before the D-27 fixes) | `Tests: 44 total, 43 passed, 1 failed` (the then-moved value) |
| Same run after the D-27 fixes | `Tests: 44 total, 44 passed, 0 failed` |
| `=econ_char,economy` | `Tests: 112 total, 112 passed, 0 failed` |
| `scripts/check-shard-map.sh` | `SHARD MAP CHECK: OK (142 registered suites, each in exactly one of 13 shards or the merge step).` |

The `ERROR: [SaveService] Invalid save` lines in `save_integrity` come from its own invalid-save tests.

### `inventory_actions` tests (14)

`discard_a_sanctum_piece` (dispatch, held piece moves in, one flush, snapshot rebuilt, controller outcome has reason `inventory.discard` and reenter); `discard_a_pack_piece`; `discard_with_an_open_path` (D-27: `path_open` with an open item row, allowed when settled or lost or with no live path, second discard of one id is `not_found`); `discard_refusals_change_nothing` (unknown id, stack id, missing, absent, non-String and empty id, equipped, away from the Sanctum: save and snapshot byte-equal, no flush, one denied log, exact reason key); `producer_direct` (defaults, explicit ids with pack overflow, cfg keeps no overlay); `producer_denials_change_nothing`; `producer_gather_needs_a_live_path` (rows, full pack takes none, no stage id, no realm); `producer_with_a_missing_fixture`; `placeholders_appear_only_after_the_producer`; `no_other_code_calls_the_producer` (file walk over `core/` and `ui/`); `snapshot_field_shape` (exact keys, counts, no `Thread`/`Ase`/`Ekwan` key, no action slot); `snapshot_field_is_a_copy`; `discard_then_json_round_trip`; `same_dispatches_give_the_same_json` (two runs equal, pinned literal).
Mutation checks by hand (each restored, `cmp` equal): `in_sanctum` forced true makes `discard_refusals_change_nothing` fail; removing `with_save_reason` makes `discard_a_sanctum_piece` fail. (First draft of the second check passed because re-entering the Sanctum already queues a save; the test now reads the outcome.)
Tests use their own cfg (`InventoryServiceTests._cfg`, empty definitions) and never read the provisional numbers.

## Assumptions

1. `in_sanctum` = the last snapshot is `flow.sanctum`. The other Sanctum-only action (`sanctum.party.toggle`) also allows `flow.echo_party`; discard allows only `flow.sanctum` because the inventory view lives there and the reenter rebuilds that snapshot. No `FlowContext` field says "on a path"; the snapshot type is the Sanctum family check the repo uses.
2. Save intent goes through the outcome (`with_save_reason("inventory.discard")`), not a direct `flow_ctx.request_save` call in the controller, as the other controllers do.
3. `data.inventory` is added to `flow.sanctum` only. `flow.echo_party` has its own builder (`FlowEchoPartyState.build_snapshot`); adding there moves more snapshot hashes. The pack row at party prep is step 7: add it then.
4. The producer reads `payload.ids` / `payload.mode` (as the brief says). Other `debug.*` actions read top-level keys.
5. `gather` pre-checks finds against the overlay cfg, but `record_found_items` reads the live cfg. With shipping `definitions` empty this accepts the placeholders. If shipping `definitions` ever becomes non-empty, `record_found_items` and the path-end bank refuse `ph_` ids (`unknown_type`). Then `direct` still works.
6. Re-entering the Sanctum already queues a save (layout). So one discard in the Sanctum gives one flush either way; the controller still names its own reason.
7. `error_outcome` is used for refusals so the reason travels in the outcome. `_apply_action_outcome` ignores it, so a refusal changes nothing.

## What an Opus reviewer must attack

1. The `in_sanctum` rule: can the last snapshot be `flow.sanctum` while a path is live (packs open)? A discard then would change held pieces under an open stage. The service does not check the stage.
2. The fingerprint dependency on provisional numbers (see "Moved value", note 1), and whether other `fingerprint_*` suites hash a Sanctum snapshot.
3. `gather` writes rows with a tick-based `find_id`: a repeat dispatch at a new tick is a new find (by design). Check that a reload between ticks cannot reuse a tick value for a different find.
4. The overlay: confirm no code path keeps the `definitions` copy (the copy is local; `duplicate(true)` on the fixture entries).
5. The `no_other_code_calls_the_producer` test lets `ui/AppRoot.gd` name the action before it does. Decide whether to keep that allowance.
6. `reenter_outcome` after a debug produce in the Sanctum re-runs `FlowSanctumState.enter` side effects (vow release, layout). Same as `sanctum.party.toggle`; check no double effect.

## OPEN — questions and assumptions

ASSUMED: 1. `in_sanctum` = last snapshot is `flow.sanctum` (not `flow.echo_party`). `path_open` (D-27) closes the live-path gap for it.
ASSUMED: 2. Save intent is carried on the outcome, as the other controllers do.
ASSUMED: 3. `data.inventory` is only in `flow.sanctum`; `flow.echo_party` waits for step 7.
ASSUMED: 4. Producer payload is read from `action.payload`.
ASSUMED: 5. `gather` uses the live cfg inside `record_found_items`; the overlay applies to the pre-check and to `direct`.
