# V2-ECONOMY-004 step 7.A build: the packs model, objectives moved onto rows (backend)

Rules: D-113, D-114, D-115, ANSWERS #87. Design file: `phase7-encounter-pay-design.md` (3.1 to 3.4, 6, 7, 8). Nothing is committed. `ui/` and Notion are untouched.
No fight is paid in this step (that is 7.B). No total moved.

## Files changed

| File | Change |
|---|---|
| `core/economy/EarningsService.gd` (new, pure statics) | `make_row`, `rows_of`, `has_row`, `add_row` (idempotent by id; refuses an empty id and a 0/0 row), `unsettled`, `sums`, `plan`, `mark_settled`, `mark_lost`, `objective_id`, `objective_row`, `record_objective`, `ensure_objective_rows` (the safety net). |
| `core/realms/StageModel.gd` | `make` adds `earnings: []`. A replay builds new stages, so it starts with `[]`. |
| `core/save/SaveService.gd` | Repair pass defaults `earnings` to `[]` when absent or not an Array. A populated list is kept. |
| `core/realms/ActiveStageService.gd` | `mark_stage_objective_completed` and `resolve_combat_situation_and_objective` call `EarningsService.record_objective` after `completed = true`. |
| `core/runtime/controllers/VentureController.gd` | The combat-victory branch of `handle_complete_stage` (the third site that sets `completed = true`) calls `record_objective`. |
| `core/economy/StageSettlementService.gd` | `settle_plan`, `_plan` (stage payer and `preview`) and `settle_leave` read rows. `settle_leave` marks rows, not objective dicts. `settle()` and `settle_leave()` call the safety net first. |
| `core/economy/RewardCalc.gd` | New `type_weight` (the one weight lookup; `_sum_selected` uses it too). `unsettled(objectives)` removed. |
| `data/balance.json` | `data.rewards.encounter_weights.fight = 6` and `_encounter_weights_comment`. Not read by any code yet (7.B reads it with `RewardCalc.cfg_num`). |
| `tests/EconomyCharacterizationTests.gd` | See below. |

`core/economy/EarningsService.gd.uid` is the engine's own file for the new script.

## Decisions in the code (check these)

1. A row stores the BASE weight (`ase`, `ekwan` from `objective_weights` and `objective_ekwan`) and `scaled: true`. The payers multiply the SUM of the unsettled scaled rows by realm scale and replay factor and round once. This is exactly the old order (sum weights, scale, round once). If the row stored a scaled value, the rounding would happen per row and totals would move. The brief says "value = weight x scale x replay as the plan computes it"; the plan computes it from the sum, so the row holds the weight.
2. Row id is `obj:<stage.index>:<objective position>`, for example `obj:0:1`. The stage dict knows its own `index`, so the id needs no `FlowContext`. Rows live inside one stage, so this is unique.
3. A row with 0 Ase and 0 Ekwan is not written (the boss stub, an unknown type). The invariant is therefore "every completed objective with a non-zero weight has exactly one row". The unknown-type warning `economy.reward.unknown_objective_type` is now logged when the objective completes (and when a payer runs the safety net), not at every plan.
4. `settle_plan` and `preview` stay pure. They count a completed objective with no row from a row built on the fly (no write, no log). The payers (`settle`, `settle_leave`) first call `ensure_objective_rows`, which logs `economy.earnings.missing_row` (level warn: the logger has no error level, same as 6.4) and writes the row. A preview therefore equals the payout.
5. `settle_plan` returns `ids` (row ids) in place of `indexes`. The log field `marked_indexes` is now `marked_ids`. No `ui/` code reads either.
6. `EarningsService.sums` returns `flat_*` sums for unscaled rows, but no payer reads them: no unscaled row has a producer yet. 7.B must add the flat input to `settle_plan` and `stage_payout_rows` when it adds found Ase. `mark_lost` has no caller yet (7.B defeat rule).

## Answers to the brief

| Question | Answer |
|---|---|
| Replay: rows rebuilt with the stage? | Yes. `RealmGenerator` calls `StageModel.make`, which writes `earnings: []`. Test `settle_replay_resets_marks` now also asserts empty earnings after a replay (real runtime). |
| Same behaviour as 6.1? | Yes. `settle_worked_example_74` (1 done: 64/74/84, 2 done: 40/62/84), the Scout odds tests, the roll-stream tests, `nothing_new`, config-error and exactly-once tests all pass with no change to an expected number. |
| RNG draws changed? | No. The roll stream `stage.settle.<stage_id>.<run_count>.<settle_count>` and its single draw are untouched. |
| Every `completed = true` site covered? | Three sites in `core/`: `ActiveStageService.mark_stage_objective_completed`, `ActiveStageService.resolve_combat_situation_and_objective`, `VentureController.handle_complete_stage` (combat-victory branch). `grep '"completed"] = true'` finds no other. |

## Tests

New (all in `econ_char`, all pass):

| Test | Proves |
|---|---|
| `earnings_add_row_is_idempotent_by_id` | Same id writes once; empty id and 0/0 row refused; row has all 11 keys; `items` empty. |
| `earnings_safety_net_writes_missing_row_and_logs` | Pure plan counts the row and writes nothing; the leave logs `missing_row` twice, writes two rows, pays 54/11; a second leave logs nothing and adds no row. |
| `earnings_rows_survive_save_and_reload` | Plan equal after a JSON round trip; row marks hold after a leave and a second reload (`nothing_new`). |
| `earnings_repair_defaults_and_new_stage_is_empty` | Repair gives `[]`; keeps a populated list; `StageModel.make` gives `[]`. |
| `earnings_every_completion_hook_writes_one_row` | Each of the three real hook sites writes exactly one row with the right id, kind, weights and flags, with the safety net unable to help (site C runs with the receipt already stamped). Includes the invariant check "every completed objective has exactly one row". |

Probe: with the three `record_objective` calls removed, only `earnings_every_completion_hook_writes_one_row` fails, and it reports sites A, B and C. Files restored (`git diff --stat` shows the 2 + 1 lines).

Rewritten tests, each with its reason:

| Test or helper | Change | Reason |
|---|---|---|
| `_settle_cell` | Resets `stage["earnings"]` per cell; records rows for completed objectives through `record_objective`; new trailing parameter `settled_objectives` marks rows settled | The helper reuses one stage across cells. Stale rows from an earlier cell broke 7 tests (`stage_payer_matrix`, `ekwan_replay_rounds_once_on_the_sum`, and others) until it reset them. Rows replace the `settled` flag on objective dicts. |
| `_carry_ctx` | Stage gets `earnings: []`; rows recorded for completed objectives | Same fixture rule: a hand-set `completed` needs the row the hook would write, so the tests show the hook path and not the safety net. |
| new helpers `_record_rows`, `_complete` | Added | Mirror the production hook. |
| `settle_plan_gathered_by_realm_and_run` | `indexes` becomes `ids` | Key renamed (decision 5). Same counts asserted. |
| `settle_leave_logs_roll_outcome_and_marks` | `marked_indexes [0, 1]` becomes `marked_ids [obj:0:0, obj:0:1]` | Log field renamed. Roll, outcome, Ase asserted as before. |
| `settle_pays_once_and_marks` | Reads row marks (3 rows settled with share 100/50/0; boss has no row). New assert: no objective dict carries `settled` or `settled_share` | The marks moved from objectives to rows (D-115 item 5). Totals and counts unchanged. |
| `settle_nothing_new_changes_nothing` | Pre-settled case marks the row | Same reason. |
| `settle_reroll_blocked_by_cancel_reload_retry` | Later objective completed with `_complete`; first-result check reads the row | Same reason. |
| `settle_stage_end_pays_unsettled_only` | The settled objective is marked through `settled_objectives: [0]` | Same reason. Expected 56/11, 54 base, memo 10/1 unchanged. |
| `settle_worked_example_74` | Finishing objectives uses `_complete` | A hand-set `completed` would have relied on the safety net. Expected 64/74/84 and 40/62/84 unchanged. |
| `settle_replay_resets_marks` | First run uses rows and `mark_settled`; asserts empty earnings after the replay | Marks live on rows now. The old objective-mark assertions stay. |

No assertion was weakened. No expected number changed.

## Filtered runs (own `ECHOES_TEST_SAVE_DIR=/tmp/echoes-7a-saves`, deleted before each run). Compile check: 0 errors.

| Filter | Result |
|---|---|
| `=econ_char,seam` | 130 of 130 (5 new tests) |
| `=objective,objective_combat` | 91 of 91 |
| `=stage,stage_stop_ui,stage_camera` | 84 of 84 |
| `=pending_result,save_integrity` | 30 of 30 |
| `=unified_resolve,foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity,realm_ui` | 72 of 72 (`snapshot_fingerprint` passes) |
| `=venture_char,flow_transaction,retreat,payout_ui,summon_price_ui,sanctum.summon` | 139 of 139 |
| `=realm,realm_prog,realm_reward,bridge,onboarding` (extra: a stage dict has a new key) | 59 of 59 |

## PREDICTED moved values: NONE

| Constant or baseline | Prediction | Why |
|---|---|---|
| `snapshot_fingerprint`, `snapshot_*` | Does not move (measured: passes) | No snapshot key changed. `carry_home_preview` keeps its five keys. |
| `fingerprint_seek`, `fingerprint_*`, `fingerprint_determinism_*` | Should not move | They hash combat results and `flow.resolve` shape. The stage dict gains `earnings: []`, which a snapshot does not carry. If one moves, check first whether it hashes a whole stage dict or save. |
| `combat_baseline`, `combat_roundtrip`, `maturity_baseline` | Should not move | No combat, RNG draw or `EchoFactory` change. |
| `reward` | Should not move | Reads `RewardCalc.compute` and the encounter payer, which are unchanged. It may read `unsettled` or a balance key list: see OPEN. |

If any value in this table moves, STOP and attribute it. It would be a regression.

## ui/ references that break

None found. `ui/` reads no objective `settled` or `settled_share`, no `earnings`, no `indexes` and no `marked_indexes`. The only `ui/` reader of this area is `StageExploreScreen.gd:619` (`carry_home_preview`), whose keys are unchanged.

## Findings not changed (out of scope)

- `RewardCalc.base_reward` header comment still says "stage payer, partials" for `MODE_COMPLETED`. No payer uses that mode now; only `ActiveStageService.get_stage_base_reward` (no caller) and tests do. Not touched.
- `ActiveStageService.get_stage_base_reward` has no caller in `core/`. Dead code; left.
- The `.get("type", "combat")` guard text scan in `econ_char` (line ~920) reads `StageSettlementService.gd`; it still passes.

## Ponytail: skipped

- No separate service for the safety net or a row class: one pure static file.
- No reader for `encounter_weights` and no flat-row payer input: 7.B owns both.
- No change to `RewardCalc.compute` or the encounter payer.
- No change to docs `CONVENTIONS.md`, `MEMORY.md`, `integration-map.md`: step 7.9.

## RUN REQUEST (main chat runs; a subagent must not)

1. Command: `rm -rf /tmp/echoes-vnext-tests && /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =fingerprint_seek,reward,combat_baseline,combat_roundtrip,maturity_baseline`, then a second run with the filter `fingerprint` (covers all `fingerprint_*` and `fingerprint_determinism_*`). Tool `timeout: 3700000`. Use an own `ECHOES_TEST_SAVE_DIR` if another run is active.
2. Expected duration: several minutes per run (`reward` alone is the longest suite).
3. Files edited by the runs: none.
4. Verify: `git status --short` shows only the 8 modified files above, `core/economy/EarningsService.gd`, its `.uid` and the two docs.
5. Read back: the `Tests:` line and every failing line. Expected: all pass, except the two `combat_baseline` retreat constants from 6.2b if they are still open. Any other failure is new: read its raw line and trace it to the table above.

## OPEN — questions and assumptions

ASSUMED: A row stores the base weight with `scaled: true`; the payers scale the sum and round once. | WHY: it keeps every 6.1 total identical (rounding once on the sum); the design file 3.2 defines `ase` as "Base Ase before scale". | WRONG IF: Jeff or the designer wants the row to hold the scaled value. Then the rounding moves to per row and totals can change by 1.
ASSUMED: Row id uses the stage `index` and the objective position (`obj:0:1`), not the `stage_id` string. | WHY: the stage dict carries its own index, and rows are unique inside one stage. | WRONG IF: a later source needs ids that are unique across stages (for example a combined ledger). Then prefix with the realm and stage id.
ASSUMED: `economy.earnings.missing_row` is logged at warn level (`logger.warn`). | WHY: `StructuredLogger` has no error level; 6.4 made the same choice. | WRONG IF: an error level is added to the logger.
ASSUMED: A 0 Ase and 0 Ekwan row is never written, including through `add_row`. | WHY: design 3.2. | WRONG IF: a later row kind (items only) needs a currency-free row. Then `add_row` must test `items` too.
BLOCKED: none.
