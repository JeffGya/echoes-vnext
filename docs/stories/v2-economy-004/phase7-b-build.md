# V2-ECONOMY-004 step 7.B build: encounters pay through the packs (backend)

Rules: D-113 to D-116 (addendum d is not in this step), ANSWERS #87, design file `phase7-encounter-pay-design.md` sections 1 to 4, 6, 7. Nothing is committed. `ui/` and Notion are untouched. `data/` is untouched.

## What the code does now

| Event | Result in the packs | Balance |
|---|---|---|
| Normal fight won | ONE row `enc:<situation_id>`: Ase = `data.rewards.encounter_weights.fight` (6), Ekwan 0, `scaled: true` | No change |
| Hostile-Claimant forced fight won | ONE row `enc:<situation_id>:claimant`, same amounts | No change |
| Objective fight won | No fight row. Only the objective row `obj:<stage>:<i>` (7.A) | No change |
| Retreat, standoff (forced retreat) | No row (no final card is built) | No change |
| Money situation (8 to 20) | Row `found:<situation_id>`, kind `money`, `scaled: true` | No change (was: paid at once) |
| Good Claimant (20) | Row `found:<situation_id>`, kind `claimant_good`, `scaled: true` | No change (was: paid at once) |
| Defeat | Every unsettled row gets `lost: true`, except rows with `keep_on_defeat`. Once per situation, behind the `consolation_paid` stamp | Objective consolation still paid at once, as before |
| Early leave | `settle_plan` and `settle_leave` read all rows: ONE roll for all rows, Ase and Ekwan share it | Share of the sum |
| Path end | The stage payer banks all unsettled rows, rounded once on the sum, plus the stipend | Sum + stipend |
| Replay | Rows are rebuilt with the stage (7.A). Realm scale and replay factor apply to all `scaled` rows, rounded once on the sum | |

The payers (`EarningsService.plan`, `StageSettlementService`, `EconomyService.stage_payout_rows`) did not change. They already summed every unsettled scaled row, so new rows flow through the leave roll, the preview and the path-end payout with no new code. The `settle_leave` roll stream and the rank code are untouched.

## Files changed

| File | Change |
|---|---|
| `core/economy/RewardCalc.gd` | New `encounter_weight(reward_cfg, kind, logger, t)`. It reads `encounter_weights.<kind>` through `cfg_num`. A missing table or key logs `economy.reward.missing_config_key` and counts 0. |
| `core/economy/EarningsService.gd` | New consts `SOURCE_ENCOUNTER`, `SOURCE_FOUND`, `KIND_FIGHT`, `CLAIMANT_FIGHT_SUFFIX`. New `fight_id`, `record_fight` (reads the weight only when the row is new, so a repeat logs nothing), `record_found`. |
| `core/realms/ActiveStageService.gd` | New static `record_fight_earnings(flow_ctx, claimant, t)` (returns false for an objective fight, an unknown stage or an empty situation id) and `lose_unsettled_packs(flow_ctx, t)` (runs `ensure_objective_rows` first, so the safety net cannot add a lost objective row back). |
| `core/state/flow/states/venture/FlowEncounterState.gd` | `build_final_snapshot`: on victory calls `record_fight_earnings` (claimant = `encounter_id` ends with the suffix); on a defeat that passes the consolation stamp calls `lose_unsettled_packs`. |
| `core/runtime/controllers/ContactController.gd` | Good Claimant writes a found row instead of `econ.add_ase`. The forced-fight `encounter_id` uses `EarningsService.CLAIMANT_FIGHT_SUFFIX` so the suffix has one definition. |
| `core/realms/SituationEngagementService.gd` | Money writes a found row instead of `econ.add_ase`. One stale comment about the `econ` parameter fixed. |
| `tests/EconomyCharacterizationTests.gd` | 11 new tests (below). |

## Flat-input path: NOT added, NOT used

Every new row is `scaled: true` (Jeff: found Ase takes the replay factor and the realm scale). No producer writes `scaled: false`. A `scaled: false` row would never be paid, because the payers read only `scaled_*` sums. The `sums` comment says so. If a later source needs a flat row, that step must add the `flat_*` input to `settle_plan`, `_plan` and `stage_payout_rows`.

## Tests (all in `econ_char`; the suite is now 97 tests, 11 new, all pass)

| Test | Proves |
|---|---|
| `packs_fight_win_adds_one_row_once` | One row, all fields, 6 Ase from config, balance 0, card `ase_awarded` 0; two more card builds add no row |
| `packs_objective_fight_adds_no_fight_row` | Objective fight win: rows are exactly `[obj:0:0]` |
| `packs_claimant_fight_has_its_own_row_id` | Claimant fight (situation resolved before the fight): row `enc:sit.fight:claimant`, once |
| `packs_retreat_and_standoff_write_no_row` | `apply_retreat_return` and `_resolve_forced_retreat` write no row and pay nothing |
| `packs_defeat_loses_unsettled_rows_once` | Unsettled objective and found rows lost; a settled row and a `keep_on_defeat` row stay; a second defeat at the same situation loses no new row; objective-fight defeat still pays the 5 Ase consolation |
| `packs_found_ase_waits_in_the_packs` | Real money engage and real good-Claimant contact write rows; the balance stays 0; a second found row for one situation is refused |
| `packs_leave_settles_all_sources_with_one_roll` | Shrine 30 + fight 6 + found 12 = 48, Ekwan 6: all/some/none give 48/24/0 with one share on every row, `settle_count` 1; a later fight forms a new row (6) |
| `packs_path_end_banks_rows_and_replay_scales_them` | Preview pays 58 (realm.01), 70 (realm.02, 48 x 1.25 = 60), 22 (replay: 48 x 0.35 = 16.8 -> 17, plus stipend cap 5); after a leave only the new fight pays (6 + 10) |
| `packs_realm01_worked_total_matches_design` | Objective mean 24.86, fights 4.5, before 39.4, after 43.9, fight share 10% (design 2.2) |
| `packs_fight_weight_reads_config_and_fails_visibly` | Weight 6 from config; `{}`, empty table and non-table each log one `missing_config_key` and count 0; empty situation id writes no row |
| `packs_rows_survive_save_and_reload` | JSON round trip keeps the plan; settled marks hold after a second reload |

The 6.1 tests and the worked example G=74 pass unchanged (no expected number changed in any existing test).

Probe (a green suite is not proof): with the fight call, the defeat call, the Claimant row and the money row each reverted to the old code, four of the new tests failed (`fight_win`, `claimant_fight`, `defeat`, `found`). Files restored; `git status` shows only the seven files above.

## Filtered runs (own `ECHOES_TEST_SAVE_DIR=/tmp/echoes-7b-saves`, deleted before each run). Compile check: 0 errors

| Filter | Result |
|---|---|
| `=econ_char,seam` | 141 of 141 |
| `=objective,objective_combat` | 91 of 91 |
| `=stage,stage_stop_ui,stage_camera` | 84 of 84 |
| `=pending_result,save_integrity` | 30 of 30 |
| `=unified_resolve,foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity,realm_ui` | 72 of 72 |
| `=venture_char,flow_transaction,retreat,payout_ui,summon_price_ui,sanctum.summon` | 139 of 139 |
| `=realm,realm_prog,realm_reward,bridge,onboarding` | 59 of 59 |
| extra: `=sit_res,contact,contact_cfg,combat_ui` | 93 of 93 |

## PREDICTED moved values

No existing constant moved in any suite I ran. For the suites I did not run:

| Constant or baseline | Prediction | Why |
|---|---|---|
| `fingerprint_*`, `fingerprint_determinism_*`, `fingerprint_seek` | Should NOT move | They fight objective index 0 (no fight row) and hash the card shape. No key, ledger row, `ase_awarded` or draw changed. |
| `combat_baseline`, `maturity_baseline` | Should NOT move | No combat code, RNG draw or `EchoFactory` change. |
| `combat_roundtrip` | Should NOT move | A won fight pays 0 to the balance as before (the row waits in the packs). It moves only if a path finishes after a NORMAL fight win: then the path payout is +6 x realm scale (rounded once on the sum). |
| `reward` | Should NOT move | It reads `RewardCalc.compute` and `reward_encounter_complete`, which did not change. Same rule as `combat_roundtrip` for a path that ends after a normal fight. |
| Balance in a fixture that wins a normal fight and then completes the path | MOVES by +6 x scale (replay x 0.35), rounded with the sum | Fight row joins the base. Fixtures that only win the fight do not move. |
| Balance in a fixture that resolves a money situation or a good Claimant and reads the balance at once | MOVES: no longer rises at the event (it rises at a leave or the path end, with the scale) | Rule D-114. No such assertion was found in the suites I ran. |

If `fingerprint_*`, `combat_baseline` or `maturity_baseline` moves, stop and attribute it: it is not expected.

## ui/ references that break

None break. `ResolveScreen.gd:526` reads `data.ase_awarded` as a total. The money situation card still reports `ase_awarded` = the found amount, so the card shows "Found +N" while the balance has not risen. That is wrong for the packs model and belongs to step 7.C and 7.D (card wording and a gathered key). The stage payout ledger row "Base objectives" now includes fight and found Ase in its delta (the sum of rows equals the payout, as the 3c rule needs). Its label is wrong until 7.C splits "Fights" and "Found".

## Findings not changed (out of scope)

- `data/balance.json:1569` `_encounter_weights_comment` says "not paid yet". `data/balance.json:1610` `_contact_claimant_good_comment` says "Outside the realm scale and the replay factor". Both are now false. `data/` belongs to `mid-game-designer`.
- Exactly-once defeat hole (by the brief: "use the existing stamp"): the stamp is per situation. If a player loses at situation X, goes to the Sanctum, re-enters the path, gathers new rows and loses at X again, the second defeat loses nothing. See OPEN.
- `ActiveStageService` header comments still list helper names from before the decomposition. Not touched.

## Ponytail: skipped

- No flat-row payer input (no producer).
- No `keep_on_defeat` row for the objective consolation: it keeps paying the balance at once, as the brief says. `mark_lost` already honours the flag for a future producer.
- No change to `reward_encounter_complete` and no `gathered_ase` key: snapshots are step 7.C.
- No new test file or suite: the new tests live in `econ_char`, so no shard-map change.
- No change to the payers (`plan`, `settle_plan`, `stage_payout_rows`).

## RUN REQUEST (main chat runs; a subagent must not)

1. Command: `rm -rf /tmp/echoes-vnext-tests && /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =fingerprint_seek,reward,combat_baseline,combat_roundtrip,maturity_baseline`, then a second run with the filter `fingerprint` (all `fingerprint_*` and `fingerprint_determinism_*`). Tool `timeout: 3700000`. Use an own `ECHOES_TEST_SAVE_DIR` if another run is active.
2. Expected duration: several minutes per run (`reward` is the longest suite).
3. Files edited by the runs: none.
4. Verify: `git status --short` shows only the seven files in the table above and this document.
5. Read back: the `Tests:` line and every failing line. Expected: all pass. Report old/new for any moved value and trace it to the prediction table.

## OPEN — questions and assumptions

ASSUMED: The objective defeat consolation stays a direct balance payment (no `keep_on_defeat` row). | WHY: the brief says "the small objective consolation stays as today". ANSWERS #87 says no source pays the balance directly. | WRONG IF: Jeff wants the consolation as a banked `keep_on_defeat` row. Then `reward_encounter_complete` writes a row instead of calling `add_ase`.
ASSUMED: The defeat loss runs once per situation behind the existing `consolation_paid` stamp. | WHY: the brief said to use the existing stamp. | WRONG IF: Jeff wants every defeat to lose the packs. A second defeat at the same situation, after new rows were gathered, loses nothing today. A separate stamp or a per-defeat counter would close it.
ASSUMED: The normal-fight row id uses `explore_map.last_situation_id`. A fight with no situation id (debug spawn) writes no row. | WHY: the objective resolve and the consolation stamp use the same key. | WRONG IF: a path starts fights without setting `last_situation_id`.
ASSUMED: The stage payout row "Base objectives" carries the fight and found Ase until step 7.C adds "Fights" and "Found" rows. | WHY: the row sum must equal the payout. | WRONG IF: Jeff wants the label fixed before 7.C.
ASSUMED: The money and Claimant cards keep `ase_awarded` = the found amount in step 7.B. | WHY: snapshots and `ui/` belong to 7.C and 7.D. | WRONG IF: the card must not show a gain before 7.C ships (play test would then read "Found +N" with an unchanged balance).
BLOCKED: none.
