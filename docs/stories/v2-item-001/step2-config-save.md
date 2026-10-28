# V2-ITEM-001a step 2: config block and save block

Author role: mechanics-developer (with the config part of mid-game-designer). Date: 2026-10-28.
Additive only. No intake logic. No UI. No commit.

## What changed

| File | Change |
|---|---|
| `data/balance.json` | New block `data.inventory`, appended after `data.contact`. No other block touched. |
| `core/config/ConfigService.gd` | New static getter `get_inventory_cfg(config_service)`, beside `get_rewards_cfg`. Returns `{}` for a null service, an empty balance or a wrongly typed block. |
| `core/save/SaveSchema.gd` | `make_new_save` adds `inventory: { version: 1, next_seq: 1, items: [], stacks: [], pack: [] }`. |
| `core/save/SaveService.gd` | New static `_repair_inventory_block(save, repaired_notes)`, called from `_apply_additive_defaults_and_repairs`. Stage repair adds `held_fates` next to `earnings`. |
| `core/realms/StageModel.gd` | `make` adds `held_fates: []`. |
| `tests/InventorySaveTests.gd` (+ `.uid`) | New suite `inventory_save`, 14 tests. |
| `ui/AppRoot.gd` | One line: `InventorySaveTests.register(runner)` after the `item_packs_char` line. |
| `scripts/test-shard-map.sh` | `inventory_save` added to shard10 (est 100 s, 41 suites). |
| `AGENTS.md` | Suite count 138 to 139 (two places), name added to the added-since sentence and to the suite list. |

## Config block `data.inventory`

| Key | Shipping value | Note |
|---|---|---|
| `unique_cap` | 8 | PROVISIONAL (D-25) |
| `pack_capacity` | 4 | PROVISIONAL |
| `stack_limit_default` | 20 | PROVISIONAL |
| `warn_room_at` | 2 | PROVISIONAL |
| `warn_pack_free_at` | 1 | PROVISIONAL |
| `kinds_enabled` | gear, relic, consumable, material: all true | Same pattern as `data.summoning.grade_enabled` |
| `grades` | `[]` | Ordered list, empty (catalogue story fills it) |
| `recycle_yield_ekwan` | `{}` | Keys per grade, empty (D-02) |
| `definitions` | `{}` | Empty. Entry shape and `cost: { ekwan, ase }` are described in `_definitions_comment` only |

`_numbers_comment` says PROVISIONAL (D-25). Other `_..._comment` keys follow the file's style. No `ph_` id is in the file. The word "glyph_" in the file contains the letters `ph_`, so the leak guard matches `ph_` only at a token start.

## Save block and repair rules

| Case | Result |
|---|---|
| Block missing or not a Dictionary | Default block. Note: `inventory block added (V2-ITEM-001a)`. |
| `items`, `stacks` or `pack` not an Array | `[]`. Note per field. |
| Entry in those arrays not a Dictionary | Entry dropped. Note with the count. |
| `version` or `next_seq` missing, wrong type, fractional or below 1 | Set to 1. Note. |
| `next_seq` not above the highest `it.<n>` id in `items` and `pack` | Raised to highest + 1. Note. An id is never reused. |
| Whole float (JSON load turns ints into floats) in `version`, `next_seq` or a stack `quantity` | Converted to int in place. NO note, NO repaired flag. |
| Valid block | Unchanged. The helper returns false. |

`economy.relics` is not touched. Notes go to the existing `save.schema.repair` log through `repaired_notes`.

Stage record: `held_fates` only. Design section 4 and section 6 say 001a saves `held_fates` (one record per held piece, written at a leave or a defeat). `StageModel.make` gives `[]`. The stage repair defaults a missing or non-Array value to `[]` and keeps a populated list. Nothing else is added (see ASSUMED 1 for `pick_stamps`).

## Finding during the work

My first repair version reported a whole float as a repair. `save_integrity/legacy_generation_defaults_to_zero` failed: a JSON load makes every int a float, so every load counted as repaired, and `load_from_file` rewrote the save and raised its generation to 1. Fix: a whole float is valid and converts silently (same idea as the existing `last_emotion_settle_unix` rule, which flags only a fractional value). A test now asserts that a JSON-loaded valid block reports no change.

## Tests run

Environment: `/tmp/claude-0/godot-bin/godot` (4.6), `ECHOES_TEST_SAVE_DIR=/tmp/claude-0/echoes-saves-step2/`, directory deleted before each run.

| Run | `Tests:` line |
|---|---|
| `--import` and `--check-only --quit` | Zero errors |
| `tests =inventory_save` | `Tests: 11 total, 11 passed, 0 failed` |
| `tests =save_integrity,foundation_ui,snapshot_contract,snapshot_purity,inventory_save` (19 s) | `Tests: 70 total, 70 passed, 0 failed` |
| `tests =item_packs_char,econ_char,economy` (71 s) | `Tests: 123 total, 123 passed, 0 failed` |
| `tests =realm,realm_prog,realm_reward,stage,onboarding,snapshot_fingerprint,bridge,seam,explore` (30 s) | `Tests: 130 total, 130 passed, 0 failed` |
| `scripts/check-shard-map.sh` | `SHARD MAP CHECK: OK (139 registered suites, each in exactly one of 13 shards or the merge step).` |

Before the float fix, the 70-test run gave `69 passed, 1 failed` (`save_integrity/legacy_generation_defaults_to_zero`). A stash of my changes gave 22 of 22 passed, so my change caused it. The fix cleared it. No recorded value (fingerprint, hash) moved. Nothing was re-recorded.

The new suite covers: new-save shape and independent arrays; old save repaired and the repair log note; wrong types (five non-Dictionary values, wrong field types, partial block, fractional counters); valid contents kept; `next_seq` floor and dropped junk; JSON round trip keeps ints and reports no change; `get_inventory_cfg` provisional values, `PROVISIONAL` text, empty lists; null and empty-balance getter result; `held_fates` default, keep and repair; no `ph_` id in `balance.json` or a new save (with a matcher self-check); `economy.relics` unchanged.

Sharded full suite on the step 2 tree: COMBINED 2568 total, 2568 passed, 0 failed (run by the main chat).

## Review fixes

| Fix | File | Test | Result |
|---|---|---|---|
| A. Piece id above 15 digits is ignored for `next_seq`. The entry stays. A note is added but no change flag, so a second repair reports no change. | `core/save/SaveService.gd` | `inventory_save/long_piece_id_is_ignored_for_next_seq` | Pass |
| B. Test no longer checks the five PROVISIONAL numbers (D-25). It checks key types only. Renamed `config_shape`. | `tests/InventorySaveTests.gd` | `inventory_save/config_shape` | Pass |
| C. A stack is kept only if `quantity` is a whole number of 1 or more. Fractional, String, negative, 0, null, missing and 1e19 are dropped. The note gives the count. Comment updated. | `core/save/SaveService.gd` | `inventory_save/bad_stack_quantity_is_dropped` | Pass |
| D. New helper `_safe_whole_int`: int or finite whole float within 2^53. `version` and `next_seq` outside it reset to 1 with a note. An int above 2^53 is also invalid (extra, small). | `core/save/SaveService.gd` | `inventory_save/huge_or_non_finite_counter_resets` (1e19, INF, -INF, NAN) | Pass |
| F. Not done, by choice. Entries in `stage.held_fates` can hold a piece id, but nothing writes entries in 001a step 2 (the list is always empty). The step that writes entries adds the floor. | none | none | Not needed now |
| G. `stage.pick_stamps` removed from the saved list and from the writer sentence (D-26). | `docs/stories/v2-item-001/design-sr-game-designer-v2.md` | none | Done |

Runs (`ECHOES_TEST_SAVE_DIR=/tmp/claude-0/echoes-saves-step2fix/`): compile check zero errors.

| Suites | `Tests:` line |
|---|---|
| `inventory_save` | `Tests: 14 total, 14 passed, 0 failed` |
| `save_integrity,foundation_ui,snapshot_contract,snapshot_purity` | `Tests: 59 total, 59 passed, 0 failed` |
| `item_packs_char,econ_char,economy` | `Tests: 123 total, 123 passed, 0 failed` |

No recorded value moved. The suite `inventory_save` now has 14 tests (was 11).

## What an opus reviewer should attack in the save change

1. `_repair_inventory_block` in `core/save/SaveService.gd`: does any input make it throw (a Variant compared with `floorf`, `substr(3).is_valid_int()` on odd ids)?
2. The "whole float is valid" rule: is a silent in-place conversion safe? It mutates the loaded dict without the repaired flag. Check that nothing compares the loaded dict with the file bytes.
3. Dropping non-Dictionary entries destroys data silently except for a note. Is dropping correct, or should the repair keep and flag?
4. Piece records are not deep-checked (no test of `id` String, `kind`, `grade`, `held_by`). A malformed piece passes. Step 3 must validate on read, or this repair must grow.
5. `next_seq` floor uses ids in `items` and `pack` only. A piece id that exists only in `stage.held_fates` is not counted.
6. Load order: the repair runs before `validate`. Confirm `validate` does not need an `inventory` rule, and that a block with a non-Dictionary value cannot reach a reader.
7. `StageModel.make` now emits `held_fates`. Look for any code or hash that serializes the whole stage dict (realm fingerprints, `realm.*` golden strings). The short suites pass. The heavy suites are in the RUN REQUEST.
8. Repair of a wrongly typed block resets contents to empty. A fully corrupt block loses pieces. Decide if that is acceptable (the save also has backups: `.bak1` to `.bak3`).

## OPEN — questions and assumptions

ASSUMED: 1. `stage.pick_stamps` is NOT added in this step. The brief says to add stage fields only for `held_fates`. Design section 3 and section 6 list `pick_stamps` as saved in 001a. Add it in step 3 or 4, with the same default and repair, if the main chat agrees.
ASSUMED: 2. The block sits at the end of `data` (after `contact`). Order inside `data` has no meaning to the code.
ASSUMED: 3. `kinds_enabled` keys are `gear`, `relic`, `consumable`, `material`, as in D-06. `grades` is a list of grade id strings, ordered lowest first.
ASSUMED: 4. A repair that finds a whole float converts it silently. The brief asks for "the repair is reported" only for a missing or wrongly typed block.
ASSUMED: 5. `inventory_save` sits in shard10 (est 100 s, tie with shards 12 and 13; the suite takes 58 ms).
BLOCKED: None.
