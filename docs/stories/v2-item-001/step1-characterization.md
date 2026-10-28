# V2-ITEM-001a step 1: characterization of item-free packs

Author role: mechanics-developer. Date: 2026-10-28. No production code under `core/`, `ui/` (except one registration line) or `data/` changed.

## Files

| File | Change |
|---|---|
| `tests/ItemPacksCharacterizationTests.gd` (+ `.uid`) | New suite `item_packs_char`, 11 tests |
| `ui/AppRoot.gd` | One line: `ItemPacksCharacterizationTests.register(runner)` after the `econ_char` line |
| `scripts/test-shard-map.sh` | `item_packs_char` added to shard11 (est 101 s, 21 suites) |
| `AGENTS.md` | Suite count 137 to 138 (two places), name added to the suite list |

## What the new suite pins (fixtures: realm.01, run 0, shrine 30/6, recover 24/5, protect 24/3, fight 6, five Echoes)

| Area | Test | Pinned values |
|---|---|---|
| Plan | `plan_with_zero_rows` | `settle_plan` full dict: `nothing_new` true, `ids` [], `rows` 0; `EarningsService.plan` sources all 0 |
| Plan | `plan_with_objective_rows_only` | ids `[obj:0:0, obj:0:1]`, Ase 54, Ekwan 11, rows 2, fight 0, found 0; plan does not change the save |
| Plan | `plan_with_fight_and_found_rows` | ids in write order `[obj:0:0, enc:f0, enc:f1, found:m0]`, Ase 54, Ekwan 6, fight_rows 2, found_rows 1; a settled row leaves `ids` but stays in `sources.all` |
| Leave | `leave_roll_fixed_seeds` | stream `stage.settle.stage.0.0.0`: seed 0 roll 0 none 0/0; seed 1 roll 57 some 39/7; seed 2 roll 90 all 78/14. Log fields, row marks, stage totals, balance |
| Leave | `leave_second_settle_uses_next_stream` | run 1, seed 4: first leave roll 0 none; a new fight row; second leave on `...0.1.1` roll 62 some pays 1 Ase, 0 Ekwan, marks only `enc:f0` |
| Leave | `leave_nothing_new_and_repeat_draw_nothing` | nothing_new: no `economy.settle.leave` log, byte-equal save. Repeat after a settle: nothing_new, no log, equal save, balance 78/14 |
| Defeat | `defeat_loses_unsettled_keeps_kept_and_repeats_idempotent` | returns 3; flags obj/f1/found lost, `enc:f0` settled and kept, `keep:1` kept; repeat returns 0; balance 0/0; plan then holds only `keep:1` (5 Ase) |
| Path end | `path_end_pays_unsettled_once` | 54 Ase + 10 stipend = 64, Ekwan 6; receipt `settled`, `realm.01.stage.0`, `cleared`; second settle returns `{}`; `preview()` empty |
| Path end | `path_end_pays_nothing_for_settled_or_lost_rows` | after a leave (54/6) path end pays the 10 stipend only; after a defeat path end pays the 10 stipend only |
| Known defect | `add_row_rejects_empty_currency_and_duplicate_id` | empty id and duplicate id rejected; an item-only row rejected |
| Known defect (renamed `nothing_new_counts_items` in step 4) | `nothing_new_ignores_items` | hand-built row with a `ph_char_item` and 0/0: `ids` lists it, `rows` 1, `nothing_new` true; leave draws no roll and marks nothing; defeat loses the row |

## KNOWN DEFECT lines

1. `# KNOWN DEFECT (V2-ITEM-001a will change this):` `EarningsService.add_row` rejects an item-only row (`EarningsService.gd:49`). Step 4 inverts the item-only assertion in `_t_add_row_rejects`. Empty-id and duplicate-id rejections stay.
2. `# KNOWN DEFECT (V2-ITEM-001a will change this):` `nothing_new` ignores items (`StageSettlementService.gd:295`). Step 4 inverts the `nothing_new` assertion and the no-roll assertion in `_t_nothing_new_ignores_items` (step 4 renamed it `nothing_new_counts_items`).

## Existing tests that already pin related behaviour (not duplicated)

All are in suite `econ_char` (`tests/EconomyCharacterizationTests.gd`).

| Behaviour | Test |
|---|---|
| Plan Ase/Ekwan, ids count, overcome, plan is pure | `econ_char/settle_plan_gathered_by_realm_and_run` |
| Leave log: roll, outcome, marked ids | `econ_char/settle_leave_logs_roll_outcome_and_marks` |
| Leave pays once, marks rows, stage totals, second leave nothing_new | `econ_char/settle_pays_once_and_marks` |
| Nothing new changes nothing (equal save) | `econ_char/settle_nothing_new_changes_nothing` |
| Seeded roll distribution and stream equals real payer | `econ_char/settle_roll_seeded_distribution` |
| Cancel, reload, retry cannot re-roll | `econ_char/settle_reroll_blocked_by_cancel_reload_retry` |
| Bad carry config: nothing marked or paid | `econ_char/settle_leave_fails_visibly_on_bad_carry_config` |
| One roll settles objective, fight and found rows | `econ_char/packs_leave_settles_all_sources_with_one_roll` |
| Defeat on a real encounter: lost, settled and kept rows stay, repeat, second defeat | `econ_char/packs_defeat_loses_unsettled_rows_once` |
| Defeat card `packs_lost` row | `econ_char/packs_defeat_card_names_the_loss` |
| Path end pays unsettled only, second settle pays nothing | `econ_char/settle_stage_end_pays_unsettled_only` |
| Path end preview of fight and found rows, replay scale | `econ_char/packs_path_end_banks_rows_and_replay_scales_them` |
| Defeat after a leave keeps what the leave paid | `econ_char/settle_defeat_keeps_paid` |
| `add_row` duplicate id, empty id, 0/0 row (no label there) | `econ_char/earnings_add_row_is_idempotent_by_id` |
| Safety net writes missing objective row | `econ_char/earnings_safety_net_writes_missing_row_and_logs` |

The new suite adds: exact `ids` order, `sources.all` after a settle, fixed-seed pins with literal rolls, the run-1 count-1 stream, "nothing new writes no log", defeat return counts, exact receipt fields, path end after a leave or a defeat, and the two labelled defects.

## Surprises

1. Test registration is in `ui/AppRoot.gd:635` (a `register(runner)` call), not in `tests/CoreTestRunner.gd`. One registration line is the only `ui/` edit. The brief listed `CoreTestRunner.gd`.
2. `const X := SomeClassName` is not a constant expression in GDScript. The suite calls `EconomyCharacterizationTests` helpers by full name. Those helpers are static and compile-checked. `tests/StageObjectiveTests.gd` already does the same.
3. `settle_plan` counts a row with items and 0/0 in `ids` and `rows` but reports `nothing_new` true. The plan is therefore inconsistent with itself today. Step 4 must change both numbers together.
4. `lose_unsettled_packs` already loses an item-only row (it is unsettled and not kept). Defeat needs no rule change for gathered items. It does for held pieces (D-20).
5. `settle_leave` also calls `ensure_objective_rows` before the plan. A step 4 item draw must run after it.
6. Arithmetic note: shrine 30 + two fights 12 + found 12 = 54, not 48. The first draft of the suite used 48 and failed. The final values are correct.

## Verification

| Check | Result |
|---|---|
| Compile check (`--check-only`) | 0 errors |
| `--import` after the new `class_name` | clean |
| `tests =item_packs_char` | `Tests: 11 total, 11 passed, 0 failed` |
| `tests =econ_char,economy,item_packs_char` (71 s) | `Tests: 123 total, 123 passed, 0 failed` |
| `scripts/check-shard-map.sh` | `SHARD MAP CHECK: OK (138 registered suites, each in exactly one of 13 shards or the merge step).` |
| Full or sharded suite | Not run (RUN REQUEST rules) |

## OPEN — questions and assumptions

ASSUMED: The one-line edit to `ui/AppRoot.gd` is allowed, because the brief says "register" and the registration lives there.
ASSUMED: Shard11 is the smallest fit (est 100 s, 20 suites, tied with shards 10, 12, 13 on time, fewest suites). I set its estimate to 101 s. I did not re-measure the shard.
ASSUMED: The `AGENTS.md` suite-count edits (137 to 138, name list) are the "counts" the brief means. The "added since" prose line 105 was not extended.
BLOCKED: None.
