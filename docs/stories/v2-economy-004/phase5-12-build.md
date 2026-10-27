# Phase 5.12 build: fix D1 (stipend after a reload) and two comment notes

## Fix
- File: `core/economy/StageSettlementService.gd`, `_echo_home`.
- Cause: with no `encounter_ctx` (after a quit and reload) the branch counted every active-party Echo as home. It ignored the stage death record.
- Change: the no-encounter branch now builds the active-party list (`faction` "echo", `name`) and calls the same helper as the fight branch, `RewardCalc.echo_tally(party, stage_lost)`. `stage_lost` is `ActiveStageService.stage_lost_echo_names`. `lost` is that list. `alive` is started minus the named Echoes.
- No second copy of the union logic. Cap and rate rules are unchanged.
- Contact path: `ContactController` (good charge) calls `mark_stage_objective_completed`. It makes no fight context. `flow.complete_stage` then reaches the same branch. Covered by test (d).

## Tests (`tests/EconomyCharacterizationTests.gd`, suite `econ_char`)
| Test | Covers |
|---|---|
| `stipend_reads_death_record_without_encounter` | (c) empty record: all home; (e) old save without the field: all home; record `[Name e1]`: 2 of 3, 4 Ase, stage 24 |
| `reboot_after_death_pays_what_the_card_showed` | (a) fight 1 kills an Echo, record written, save, new `FlowRuntime`: preview = paid = card (58), 4 of 5, `lost` has the name |
| `reboot_replayed_card_pays_what_it_showed` | (b) same, with `flow.continue` and the replayed Resolve card: card = paid (58) |
| `charge_completion_after_death_pays_with_record` | (d) last objective completed by `mark_stage_objective_completed` with no fight context: preview = paid, 4 of 5 |

- Proof the tests see the defect: with the fix reverted, 4 tests fail (paid 60 against card 58; the same numbers as the QA probe). With the fix, 69 of 69 pass.
- Limit for (a) and (d): without a pending card, `flow.continue` does not restore `realm_id` and `stage_id`. The tests set them by hand. Test (b) uses the real path.
- Limit for (d): it calls `mark_stage_objective_completed`, the method that `ContactController` calls. It does not dispatch a full charge contact.

## Comment notes (comments only; no constant changed)
- `tests/FlowFingerprintSeekTests.gd`: one re-record line per mode and cause. Steps 5.1 (pace bonus, five modes; protect and guide_spirit held), 5.2 (all seven modes, FINAL and SAVE), 5.11 (all seven modes, FINAL).
- `tests/VentureCharacterizationTests.gd`: removed "the realm-virtue bonus" from the comment above `_t_complete_stage_no_encounter` (the bonus is gone, D-40). I took D-40 from the brief; I did not re-read it.

## PREDICTED moved values
None. The stage payer is not in any fingerprint. Fingerprints use a fight context, so they take the fight branch, and it is unchanged. Comment edits change no hash.

## MEASURED (short suites, `ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase512`, deleted before each run)
- Compile check: no errors.
- `econ_char,objective,seam,stage,pending_result,save_integrity`: 179 of 179.
- `unified_resolve,foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity`: 52 of 52.
- `venture_char,flow_transaction,retreat,payout_ui,summon_price_ui`: 83 of 83.
- `reward` and the full suite were not run.

## RUN REQUEST
Run `fingerprint_seek` and the other fingerprint suites to confirm no hash moved (PREDICTED: none). Run `reward`, and the sharded suite on CI.
1. Command: `ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase512 /usr/bin/perl -e 'alarm shift; exec @ARGV' 900 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =fingerprint_seek,reward` (timeout 1000000 ms). Delete the save directory first.
2. Duration: about 1 to 3 minutes.
3. Files the run edits: none.
4. Check: `git status --short` shows only the four files of this step.
5. Read back: the `Tests:` line and any failure line.
