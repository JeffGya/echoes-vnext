# V2-ITEM-001a step 3: the inventory service

Author role: mechanics-developer. Date: 2026-10-28. Core only. No action wiring, no leave or defeat wiring, no UI. No commit.

## Files

| File | Change |
|---|---|
| `core/inventory/InventoryService.gd` | New. `class_name InventoryService`, pure statics. |
| `tests/InventoryServiceTests.gd` (+ `.uid`) | New suite `inventory_service`, 22 tests. |
| `tests/fixtures/inventory_placeholders.json` | New. Six `ph_` definitions, `cost: { ekwan: 0, ase: 0 }`. |
| `core/save/SaveService.gd` | `_repair_inventory_block` drops invalid and repeated-id pieces (review fix 2). Save-schema change. |
| `tests/InventorySaveTests.gd` | One new test, `repair_drops_pieces_that_fail_the_shape_check`. |
| `ui/AppRoot.gd` | One line after the `inventory_save` line. |
| `scripts/test-shard-map.sh` | `inventory_service` added to shard12 (est 100 s, now 23 suites). |
| `AGENTS.md` | Suite count 139 to 140 (two places), name added to the list and the added-since sentence. |

## API

`cfg` = `ConfigService.get_inventory_cfg(...)`. Every function takes `save` first. No function calls `SaveService`, RNG or a clock. A cfg value of the wrong type reads as 0 or as absent; it never throws.

| Function | Inputs | Output | Reason keys |
|---|---|---|---|
| `unique_count(save)` | | `items.size()` (malformed entries count) | |
| `pack_count(save)` | | `pack.size()` | |
| `sanctum_room(save, cfg)` | | `max(0, unique_cap - unique_count)` | |
| `pack_free(save, cfg, reserved=0)` | `reserved` = pack slots held by gathered item rows | `max(0, pack_capacity - pack_count - reserved)` | |
| `pack_load(save, cfg, reserved=0)` | | `{ carried, capacity, free, level }`. Level: 0 nothing carried; 3 free is 0; 2 free <= `warn_pack_free_at`; 1 else. | |
| `held_pieces(save)` | | NEW. Copies `{ id, type_id, kind, grade }` of the valid `pack` pieces, in pack order. A malformed piece and a repeated id are left out. The leave draw reads this. | |
| `snapshot(save, cfg, reserved=0)` | | Fresh tree: `unique_count, unique_cap, sanctum_room, pack_count, pack_capacity, pack_free, items[], pack[], stacks[], pack_load, warn{room,pack}`. Piece row: `id, type_id, kind, grade, mark_index, equipped`. Stack row: `type_id, kind, quantity, limit, at_limit`. Malformed entries are left out. The row `id` is for core callers only; the UI must not print it. `mark_index` = (number part of the piece id) modulo 6; 0 when the id has no valid number. It is stable: no discard changes another piece's mark. `warn.room` is `room <= warn_room_at` (`unique_cap` 0 counts as full). `warn.pack` is `carried > 0 and free <= warn_pack_free_at`. | |
| `validate(save, cfg)` | | Array of problem strings, empty when clean. | |
| `piece_problem(piece)` | | NEW public. `""` or the first problem: `not a Dictionary`, `bad id`, `bad type_id`, `bad kind`, `bad grade`, `bad held_by`. `grade` and `held_by` may be absent. The one owner of the piece shape; `SaveService` repair calls it. | |
| `intake(save, cfg, entry, mode, reserved=0, logger=null, t=0)` | `entry` = `{ type_id, kind, grade, quantity, piece_id }`; `mode` = `gathered` or `direct` | `{ result, reason_key, item_id, quantity, lost_quantity }` | see below |
| `move_pack_to_sanctum(save, cfg)` | | int moved | |
| `remove_held(save, ids)` | `ids` = Array of piece ids | NEW. Removes the valid pack pieces whose ids are listed (one piece per listed id, pack order). Unknown and non-String ids are ignored. Returns copies `{ id, type_id, kind, grade }`. No draw. No `move_pack_to_sanctum`: the caller decides. | |
| `discard(save, cfg, item_id, in_sanctum, logger=null, t=0)` | | `{ result, reason_key, item_id, moved }` | see below |
| `take_in_order(finds, free_slots)` | | `{ model: "find_order", chooser_id: "", taken, left, draws: 0 }`. A find that is not a Dictionary is skipped. | |

### `intake` outcomes

| `result` | `reason_key` | When |
|---|---|---|
| `stored` | `ok` | Stack fully added, or unique piece put in `items`. |
| `packed` | `to_pack` | Unique piece put in `pack` (Sanctum has no room). `gathered` always; `direct` needs `pack_free(reserved) > 0`. |
| `partial` | `stack_limit` | Some of a stack added; `lost_quantity` > 0. |
| `lost` | `stack_limit` | Stack at or above its limit; nothing added. |
| `lost` | `overflow` | `direct` unique piece, Sanctum and pack full. No id is minted. |
| `rejected` | `duplicate` | CHANGED (was result `duplicate`). Supplied `piece_id` already in `items` or `pack`. Nothing changes. |
| `rejected` | `unknown_kind` | Kind missing, not one of the four, or not a key of `kinds_enabled` (also when `kinds_enabled` is not a Dictionary). |
| `rejected` | `kind_disabled` | `kinds_enabled[kind]` is anything but the Boolean `true`. |
| `rejected` | `unknown_type` | `definitions` is a non-empty Dictionary and has no Dictionary entry for `type_id`. |
| `rejected` | `bad_entry` | Internal key. Bad `mode`; empty or non-String `type_id`; entry `kind` differs from the definition `kind`; stack `quantity` < 1; unique `quantity` present and not 1; non-String `piece_id`; `piece_id` not matching `^it\.[1-9][0-9]{0,14}$`. |
| `rejected` | `bad_state` | Internal key. `save.inventory` missing or its arrays are not Arrays. Nothing changes. |

Check order: block, mode, kind (`unknown_kind`, `kind_disabled`), `type_id`, `unknown_type`, definition kind, then stack or unique path. Unique path: `quantity`, `piece_id` type and form, `duplicate`, then `move_pack_to_sanctum`, then placement. Every refusal happens before the move, so a refusal changes nothing. A supplied `piece_id` raises `next_seq` above its number; a minted id skips any `it.<n>` already present; `next_seq` is written back as an int. A stack limit comes from the definition `stack_limit` when above 0, else `stack_limit_default`. A stack above a lowered limit stays as it is; the intake is `lost`.

### `discard` outcomes

`not_in_sanctum`, `bad_state`, `equipped` (`held_by` is anything but the empty String), `not_unique` (the id equals a stack `type_id`), `not_found`: result `refused`, nothing changes. Success: result `discarded`, key `ok`, then ALWAYS `move_pack_to_sanctum` (`moved`), for a pack piece and for a Sanctum piece.

## Invariants

Asserted after every step of a 160-step scripted sequence (`invariants_hold_after_every_mutation`; it uses `gathered` intake, supplied ids, and a cap lowered at step 80):

1. Piece ids are unique across `items` and `pack`.
2. `intake` never puts a piece in `items` above `unique_cap`.
3. `intake` never puts a piece in `pack` while `sanctum_room > 0`.
4. After `discard`, `move_pack_to_sanctum` and a unique `intake` that passes the entry checks: `pack` is empty or `sanctum_room == 0`.
5. `validate` is empty (also covers: `next_seq` above every `it.<n>` id, stack `quantity` within the limit, no second stack of a type), except the two expected lines: `gathered` pieces above `pack_capacity`, and items above a lowered `unique_cap`.

Not enforced: a cap raised in `data/balance.json` after a save leaves pieces in `pack` with Sanctum room until the next `discard`, `move_pack_to_sanctum` or unique `intake`. A cap lowered leaves more pieces than the cap; no mutation drops a piece. `gathered` mode can put the pack above `pack_capacity`; `validate` reports it, so call `validate` after a flow ends, not in the middle.

## Review fixes (Opus review of step 3)

| # | Fix | File | Test | Result |
|---|---|---|---|---|
| 1 | `kinds_enabled` value not a Boolean no longer crashes: absent key `unknown_kind`, value not exactly `true` `kind_disabled`. All cfg reads tolerate wrong types. | `InventoryService.gd` | `cfg_of_the_wrong_type_does_not_crash` (String, Array, Dictionary, int, null) | pass |
| 2 | One owner of the piece shape: public `piece_problem`. `_repair_inventory_block` drops pieces that fail it and repeated ids (first kept), one note with the count, `changed` true; second pass reports no change. Stacks unchanged. SAVE-SCHEMA CHANGE: an Opus reviewer must re-check it. | `InventoryService.gd`, `SaveService.gd` | `inventory_save/repair_drops_pieces_that_fail_the_shape_check` | pass |
| 3 | `discard` always runs `move_pack_to_sanctum` after a success. | `InventoryService.gd` | `discard_outcomes` (pack piece with room) | pass |
| 4 | Unique `intake` runs `move_pack_to_sanctum` first, then places the new piece. | `InventoryService.gd` | `intake_moves_held_pieces_first` (reviewer case, caps 1 to 3) | pass |
| 5 | Entry kind differs from definition kind: `rejected`/`bad_entry`. | `InventoryService.gd` | `rejections` | pass |
| 6 | Unique `quantity` other than 1 and malformed `piece_id` are `bad_entry`. | `InventoryService.gd` | `rejections` (`it.007`, `it.+5`, 16 digits, others) | pass |
| 7 | `warn.pack` false when nothing is carried. `unique_cap` 0 gives `warn.room` true. | `InventoryService.gd` | `pack_load_levels` | pass |
| 8 | New `remove_held` and `held_pieces`. | `InventoryService.gd` | `remove_held_and_held_pieces`, `malformed_entries_do_not_throw` | pass |
| 9 | Stronger tests: full-JSON before/after on each refusal; exact `validate` strings; invariants with `gathered`, supplied id and lowered cap; `pack_load` at capacity 0 and with a large `warn_pack_free_at`; stack limit below stack; `unique_cap` missing; `gathered` above capacity; `take_in_order` with non-Dictionary finds; `next_seq` invalid or missing; pinned JSON replaces the two-run determinism test. | `InventoryServiceTests.gd` | see names in the suite | pass |
| 10 | Story and process text removed from code comments. | `InventoryService.gd` | none | done |
| decision | Piece ids are minted at intake. `mark_index` = id number modulo 6. A repeated id gives `rejected`/`duplicate`. `bad_entry` and `bad_state` stay as internal keys. | service, design file | `twins_get_different_ids_and_marks` | pass |

## Tests

Environment: `/tmp/claude-0/godot-bin/godot`, `ECHOES_TEST_SAVE_DIR=/tmp/claude-0/echoes-saves-step3fix/` (deleted before each run). Compile check (`--check-only`): zero errors. No `--import` (no new `class_name` file).

| Run | `Tests:` line |
|---|---|
| `=inventory_service` | `Tests: 22 total, 22 passed, 0 failed` |
| `=inventory_save,item_packs_char` | `Tests: 26 total, 26 passed, 0 failed` |
| `=save_integrity,snapshot_contract` | `Tests: 30 total, 30 passed, 0 failed` |
| `=foundation_ui` | `Tests: 17 total, 17 passed, 0 failed` |
| `=snapshot_purity,econ_char` | `Tests: 115 total, 115 passed, 0 failed` |
| `=economy` | `Tests: 9 total, 9 passed, 0 failed` |

No recorded value moved. Nothing was re-recorded. The `ERROR: [SaveService] Invalid save: missing schema_version` lines in `save_integrity` come from its own invalid-save tests. Not run (by instruction): the full and sharded suites. Not re-run after the review fixes: `scripts/check-shard-map.sh` (no suite added or removed).

## Exact calls step 4 must make

1. A gathered item row holds one pack slot. Pass `reserved` = count of unsettled, unlost item rows of the live stage to `pack_free`, `pack_load`, `snapshot` and to every `direct` intake.
2. Read held pieces for the leave draw with `held_pieces(save)` (copies, pack order). The gathered pieces have no id before intake.
3. Path end (cleared): for each item row in row order call `intake(save, cfg, entry, "gathered", reserved)`. `entry.piece_id` is `""` (the id is minted at intake) unless the row already carries one. The first unique intake moves held pieces into the Sanctum itself, so a separate `move_pack_to_sanctum` call is needed only if the path has no unique item row. A stack entry uses `kind` consumable or material and `quantity`. Read the result: `packed` keeps the piece held; `lost`/`stack_limit` is the surplus.
4. Early leave: draw per piece (held and gathered) in step 4. Held pieces that lose their draw: call `remove_held(save, lost_ids)` and write the returned rows to `stage.held_fates`. Survivors stay in `inventory.pack`. Then call `move_pack_to_sanctum(save, cfg)` once, then `intake(... "gathered" ...)` for each surviving gathered row.
5. Defeat: `remove_held(save, all_held_ids)` with the ids from `held_pieces(save)`; write the returned rows to `stage.held_fates`. Do not call `move_pack_to_sanctum` afterwards (the pack is empty).
6. Request the save with `flow_ctx.request_save(reason)` after the mutation succeeds. Never call `SaveService`.
7. Pass `logger` and `t` for a log line, or omit them.

## OPEN — questions and assumptions

ASSUMED: 1. `piece_problem` treats `grade` and `held_by` as optional (absent reads as ""), and a wrong type as a problem. The repair therefore keeps a piece with no `held_by` and drops a piece with a non-String `held_by` or `grade`. The brief said "String grade, String held_by".
ASSUMED: 2. `remove_held` removes one piece per listed id. A repeated id in `pack` (corrupt save) leaves the second piece in place.
ASSUMED: 3. `warn.pack` no longer needs `pack_capacity > 0`: capacity 0 with a carried piece warns.
ASSUMED: 4. A unique `intake` that ends in `lost`/`overflow` still moves held pieces first (the move is a mutation on a non-refusal).
ASSUMED: 5. `definitions` of the wrong type (not a Dictionary) counts as "no definitions": any type id is accepted. An empty Dictionary entry for a type counts as `unknown_type`.
ASSUMED: 6. The repair note text is `inventory dropped N invalid pieces` (one note for `items` and `pack` together). The old per-key text `inventory.items dropped N invalid entries` is gone for pieces; stacks keep theirs.
ASSUMED: 7. The repair keeps its own loose `it.<n>` parse for `next_seq` (e.g. `it.007` raises `next_seq` above 7), while the service reads only strict ids. This is safe (the counter only rises).
BLOCKED: None.
