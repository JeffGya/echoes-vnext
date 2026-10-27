# V2-ECONOMY-004 step 7.C build: packs in the snapshots, and every defeat loses the packs (backend)

Rules: D-113 to D-117, ANSWERS #86 and #87, design file `phase7-encounter-pay-design.md` sections 3 to 6, copy file `phase7-copy-final.md` (cause slots only). Nothing is committed. `ui/` and Notion are untouched. Config values are unchanged.

## What the code does now

| Item | Result |
|---|---|
| Defeat | `lose_unsettled_packs` runs on EVERY defeat. A lost row is not unsettled, so a repeat marks nothing. A row gathered after the first defeat is lost by the next defeat. Only the small objective consolation keeps its once-only stamp (`consolation_paid`). |
| `carry_home_preview.gathered` | New block `{ ase, ekwan, rows, has_fight_rows, has_found_rows }`. It reads the same `StageSettlementService.settle_plan` the leave uses, so `gathered.ase` and `gathered.ekwan` equal the top-level `ase` and `ekwan` and equal what an "all" leave pays. `nothing_new` and the old four keys stay. No odds, no percent. |
| Fight win card | `reward_breakdown` gets one row: label `Fight won`, `delta` = the row's base Ase, cause `encounter_gathered`, params `{ kind, gathered_ase }`. `ase_awarded` stays 0. The row is read from the packs, so a rebuilt card shows the same row. An objective fight and a defeat show no such row. No new top-level key on the combat card. |
| Money situation card | `ase_awarded` is 0. New key `ase_gathered` (only when above 0) and one ledger row: label `Found`, cause `found_gathered`, params `{ kind }`. |
| Good Claimant card | New key `ase_gathered` (20) only. The contact card has no ledger. |
| Path-end ledger | The base row splits by source. `objectives_overcome` (unchanged), `encounters_overcome` (label `Fights won`, params `{ count }`), `found_banked` (label `Found on the path`, params `{ count }`). Each part is rounded alone, the LAST part shown takes the rounding remainder, so the rows still add to the payout. A part shows when it has an open row. The objectives row also shows when no part does (old behaviour). The replay row is one row on the scaled sum. |
| Leave card | `nothing_overcome_yet` now shows only when nothing was gathered, overcome or settled on the stage (design 5.3). Before, it also showed after an earlier leave settled only a fight. A later empty leave now gives `settle_nothing_new`. |
| Replay after a quit | `resolve_data` is a copy of the card data, so the new ledger rows replay. `ase_gathered` replays through a new gated line in `PendingResultService.build_snapshot`. |

## Files changed

| File | Change |
|---|---|
| `core/economy/EarningsService.gd` | New `row_of`. `plan()` returns `sources`: `{ objective, encounter, found }`, each `{ rows, ase }` (base Ase of scaled open rows). |
| `core/economy/StageSettlementService.gd` | `settle_plan` returns `rows`, `fight_rows`, `found_rows`, `settle_count`. `_plan` passes `sources`. The path payer and `preview` pass `sources` to the ledger. |
| `core/economy/EconomyService.gd` | `stage_payout_rows` and `settle_stage_complete` take a trailing `sources` (default `{}`: one objectives row as before). New private `_base_rows`. Header comment fixed. |
| `core/realms/ActiveStageService.gd` | New `fight_row` (read only) and `_last_situation_id`. `lose_unsettled_packs` comment fixed. |
| `core/state/flow/states/venture/FlowEncounterState.gd` | Every defeat calls `lose_unsettled_packs`. A won normal fight adds the `encounter_gathered` row to a copy of the breakdown. |
| `core/state/flow/states/venture/ResolveSnapshotBuilder.gd` | New block `add_ase_gathered`. |
| `core/state/flow/states/venture/VentureResolveSnapshotBuilder.gd` | `build_situation_resolve_snapshot` takes `ase_gathered` in place of `ase_awarded`. The leave card rule for `nothing_overcome_yet`. |
| `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd` | `_carry_preview` adds `gathered`. |
| `core/state/flow/PendingResultService.gd` | Replays `ase_gathered`. |
| `core/realms/SituationEngagementService.gd` | The verdict carries `ase_gathered` (not `ase_awarded`). |
| `core/runtime/controllers/VentureController.gd` | Passes `ase_gathered` to the card builder. |
| `core/runtime/controllers/ContactController.gd` | The good-Claimant card gets `ase_gathered` (0 when the row was refused). Comment fixed. |
| `core/runtime/FlowRuntime.gd` | Stale comment fixed (it said `econ.add_ase` pays the Claimant). |
| `data/balance.json` | TEXT of two comment keys only (below). No value changed. |
| `tests/EconomyCharacterizationTests.gd`, `tests/UnifiedResolveTests.gd`, `tests/FlowSnapshotFingerprintTests.gd` | See Tests. |

## Balance comment keys changed (text only)

| Key | Old | New |
|---|---|---|
| `_encounter_weights_comment` | `... Read through RewardCalc.cfg_num; not paid yet.` | `... Read through RewardCalc.cfg_num. A won fight adds one row to the packs; the leave roll or the path end pays it.` |
| `_contact_claimant_good_comment` | `Ase paid once for a good Claimant contact (V2-ECONOMY-004 5.15). Outside the realm scale and the replay factor.` | `Base Ase of a good Claimant contact (V2-ECONOMY-004 5.15). It goes in the packs as a found row and takes the realm scale and the replay factor like every other row (D-115).` |

`data/` normally belongs to `mid-game-designer`. The brief asked for this text fix.

## Stale code comments fixed

`EconomyService.gd` stage-payer header (victory), `FlowRuntime.gd` `_contact_controller` doc, `ContactController.claimant_good_ase` doc, `SituationEngagementService.gd` verdict doc, `ActiveStageService.lose_unsettled_packs` doc (it said the caller guards a stamp), `FlowEncounterState` defeat comment, `StageSettlementService.settle_plan` doc.

## Tests

Filtered runs, own `ECHOES_TEST_SAVE_DIR=/tmp/echoes-7c-saves` deleted before each run. Compile check: 0 errors.

| Filter | Result |
|---|---|
| `=econ_char,seam` | 144 of 144 (`econ_char` 100 tests: 3 new) |
| `=objective,objective_combat` | 91 of 91 |
| `=stage,stage_stop_ui,stage_camera` | 84 of 84 |
| `=pending_result,save_integrity` | 30 of 30 |
| `=unified_resolve,foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity,realm_ui` | 72 of 72 (after the two changes below) |
| `=venture_char,flow_transaction,retreat,payout_ui,summon_price_ui,sanctum.summon` | 139 of 139 |
| `=realm,realm_prog,realm_reward,bridge,onboarding` | 59 of 59 |
| `=sit_res,contact,contact_cfg,combat_ui` | 93 of 93 |
| extra `=economy,sanctum_pulse,consequence,explore,explore_p5` | 86 of 86 |

New tests (`econ_char`): `packs_gathered_block_uses_the_leave_plan`, `packs_path_end_rows_add_to_the_payout` (180 combinations of realm, run, fights, found and objectives: rows add to the payout), `packs_cards_carry_gathered_causes_and_replay` (fight card row, rebuilt card equal, objective fight and defeat have no row, money card, pure builder, empty card, good Claimant card, stored result replay of rows and `ase_gathered`).

Changed tests, each with its reason:

| Test | Change | Reason |
|---|---|---|
| `econ_char/packs_defeat_loses_unsettled_rows_once` | Second defeat now MUST lose the new row. Same card built twice loses once. Repeat `lose_unsettled_packs` marks 0. Objective fight: second defeat loses the new row, consolation stays 5. | Jeff D-115: every defeat loses the packs. |
| `econ_char/packs_found_ase_waits_in_the_packs` | Reads `ase_gathered`; asserts `ase_awarded` 0. | Task 3. |
| `econ_char/packs_path_end_banks_rows_and_replay_scales_them` | Reads three source rows (30/6/12 at realm.01, 38/8/14 at realm.02, replay 30/6/12 and redo -31). Totals unchanged (58, 70, 22). | The base row splits. |
| `econ_char/settle_return_home_dispatch_word_outcome_no_odds` | Preview has 6 keys and the exact `gathered` block. | New key. |
| `unified_resolve/money_ase_awarded_positive` | Asserts `ase_gathered` above 0 and `ase_awarded` 0. | Task 3. Test name unchanged. |
| `snapshot_fingerprint/stage_explore` | Constant re-recorded: old `5515ca86c12db802212657908e247060f137b881ff3092b2f7925658a90b5440`, new `fe7d8a0ee91a221f0c314684ca3acb4bcb11335cadb2510c3cf3da28bd3179c4`. | One cause: the new key `data.carry_home_preview.gathered`. Proof: with only that key removed from the builder, the old hash returned (2 of 2 passed); file restored with `cmp`. |

Probe (a green suite is not proof): with the defeat gate reverted to `elif _consolation_eligible` and the fight row removed from the card, `packs_defeat_loses_unsettled_rows_once` and `packs_cards_carry_gathered_causes_and_replay` failed. File restored (`cmp` equal).

## PREDICTED moved values

I re-recorded ONE constant (the stage_explore one above, because it sits in a filter I ran and it moved by a known single cause). Please veto it if you want it recorded later. I did not run and did not re-record the heavy suites.

| Constant or baseline | Prediction | Why |
|---|---|---|
| `fingerprint_*` FINAL (`FlowFingerprintTests._final_fingerprint`) | Should NOT move | It hashes the NAMES of `data` keys and `ase_awarded`. I added NO key to the victory or defeat combat card. The only change on a combat card is one ROW inside `reward_breakdown`, and only for a normal-fight win; the fingerprint fights objective index 0, which has no fight row. The defeat path adds no key. |
| `fingerprint_seek`, `fingerprint_determinism_*` | Should NOT move | Same reason. |
| `combat_baseline`, `maturity_baseline` | Should NOT move | No combat code, RNG draw or `EchoFactory` change. |
| `combat_roundtrip`, `reward` | Should NOT move, unless a test reads the card of a normal fight win and counts `reward_breakdown` rows (one row now) | A balance moves only as 7.B predicted (a path that finishes after a normal fight: +6 x scale). |

Payloads touched: victory card (one row in `reward_breakdown`, no key), defeat card (none), situation card (new key `ase_gathered`, `ase_awarded` 0), contact card (new key `ase_gathered` on a good Claimant), stage_explore (`carry_home_preview.gathered`), leave card (row choice), path-end `stage_payout_rows` (split rows).

If a FINAL constant moves: remove the new keys from `data_keys` in the projection and compare with the old constant. If equal, the keys are the cause. If it does not match, the cause is the row content or something else: stop and attribute.

## ui/ references that break or need work (UI is the next step)

| File | Problem |
|---|---|
| `ui/screens/venture/ResolveScreen.gd:526` `_build_ledger` | `total = ase_awarded + stage_payout_ase`. On the money card the total is now +0 and the `Found` row shows +N. `ase_gathered` is read nowhere. |
| `ui/screens/venture/ResolveScreen.gd:~598` `_is_midstage_win` | A normal fight win now has one `reward_breakdown` row, so the card leaves the Direction E mid-stage layout and goes to the ledger layout with a "+0 Ase" total. The UI step must decide (use the `encounter_gathered` cause to keep the mid-stage layout). |
| `ui/components/PayoutCausePresentation.gd` | No `ROW_NAMES` / `TEXT` entries for `encounter_gathered`, `found_gathered`, `encounters_overcome`, `found_banked`. The row label falls back to the row's `label` field (copy file wording is already used there). `is_known`-style line 37 returns false for them, so no tooltip. `encounters_overcome` and `found_banked` params carry `count`. |
| `ui/components/CarriedHomePresentation.gd:22` and `ReturnHomeModal.gd:55` | Read `ase`, `ekwan`, `nothing_new` of `carry_home_preview`; still correct. `gathered` is not read. Empty-packs line (`GATHERED_EMPTY`) needs `gathered.rows` or `nothing_new`. |
| Text `nothing_overcome_yet` | Copy file replaces it with "Nothing was gathered."; UI string only. |

## Findings not changed (out of scope)

- The defeat card has no key that says the packs were lost (design 5.1 names a `packs_lost` cause with `{ lost_ase, lost_ekwan }`; copy slot `defeat.packs_lost`). The brief did not list it. The UI step cannot show "the packs were lost" without it. See OPEN.
- `ResolveSnapshotBuilder.add_ledger` header block list and `docs/resolve-snapshot-block-spec.md` do not list block 14f. Docs are step 7.9.
- Existing debug path: `DebugController` was not read for claimant branches.

## Ponytail: skipped

- No `packs_lost` row or key on the defeat card (not in the brief).
- No `has_objective_rows` boolean in `gathered` (nothing needs it).
- No scaled amount on event cards (see OPEN).
- No new snapshot key on the combat victory card, so no FINAL constant moves.
- No change to the payers' roll, `EchoFactory`, or any RNG stream.
- No ledger on the contact card for the Claimant (the contact renderer has none).

## RUN REQUEST (main chat runs; a subagent must not)

1. Command: `rm -rf /tmp/echoes-vnext-tests && /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =fingerprint_seek,reward,combat_baseline,combat_roundtrip,maturity_baseline`, then a second run with the filter `fingerprint` (all `fingerprint_*` and `fingerprint_determinism_*`). Tool `timeout: 3700000`. Use an own `ECHOES_TEST_SAVE_DIR` if another run is active.
2. Expected duration: several minutes per run (`reward` is the longest suite).
3. Files edited by the runs: none.
4. Verify: `git status --short` shows only the 17 files listed above plus this document and the earlier-step files.
5. Read back: the `Tests:` line and every failing line. Expected: all pass. Report old and new for any moved value, and apply the hash proof method above.

## OPEN — questions and assumptions

ASSUMED: Every defeat loses the unsettled packs, with no guard other than idempotent marking. | WHY: Jeff D-115 and the brief. | WRONG IF: a defeat card can be built a second time for a defeat the player already saw and rows were gathered in between (a pending-result replay does not rebuild, so none found).
ASSUMED: The event cards show the BASE amount (fight 6, found 12, Claimant 20), not the amount after realm scale and replay factor. | WHY: the card says what was earned or found; the leave panel and the path-end ledger show the scaled sums, and the scale is rounded once on the sum, so a per-row scaled number would not add up. | WRONG IF: Jeff wants the card to show the replay-reduced amount (a replay run would show 2 for a fight worth 6).
ASSUMED: I re-recorded `STAGE_EXPLORE_FINGERPRINT_HASH` (cause: key `gathered`, proof by removal). | WHY: the brief forbids re-recording FINAL constants of the heavy suites; this one is in a filter I ran, and steps 5.8 and 6.1 re-recorded it the same way. | WRONG IF: the orchestrator wants it recorded in a later step. Revert the one constant and its comment.
ASSUMED: The fight row on the card has label `Fight won`; the found row has label `Found`; the path-end rows have `Fights won` and `Found on the path`. | WHY: `phase7-copy-final.md` section 4. | WRONG IF: Jeff edits the copy after the play test.
ASSUMED: I fixed the `nothing_overcome_yet` rule on the leave card (design 5.3) in this step. | WHY: a won fight now creates a row, and an earlier fight-only leave would show "Nothing overcome yet" on the next empty leave. | WRONG IF: this belongs to the UI step. It is 3 lines in `VentureResolveSnapshotBuilder`.
ASSUMED: The good-Claimant card gets the key `ase_gathered` but no ledger row. | WHY: the contact renderer has no ledger. | WRONG IF: the UI step wants a `found_gathered` row on that card too.
BLOCKED: Does Jeff want a `packs_lost` signal on the defeat card (design 5.1, copy slot `defeat.packs_lost`)? | CHECKED: brief task list, design 5.1, copy file section 5. | NEED: Jeff or the orchestrator to say yes. Then add a conditional ledger row `packs_lost` with `{ lost_ase, lost_ekwan }` (it changes no combat key list).
