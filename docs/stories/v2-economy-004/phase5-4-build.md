# Phase 5.4 build: combat retreat price and denial (D-46, D-79)

## Design

| Item | Result |
|---|---|
| Price | `data.combat.retreat_ase_cost` = 10 (was 30). |
| Price reader | `RetreatService.get_ase_cost(config_service)`. The snapshot builder and the handler both call it. |
| Missing key | `push_error`, then fall back to 10. The fallback is not 30. |
| Price in the action | The handler ignores `ase_cost` in the action dict. A UI action cannot set its own price. |
| Denial | Balance below price: `_handle_encounter_retreat` logs `encounter.retreat.denied` (info), spends nothing, gives no partial, does not roll, and returns. The fight stays at pre-combat. |
| Denial outcome | The returned snapshot `data.retreat_denied = {reason: "insufficient_ase", ase_cost, ase_balance}`. It lasts until the next snapshot rebuild. |
| Paid retreat | Spends the price, win or lose. A failed retreat still spends (rule kept). |
| Stipend | A retreat pays no Echoes stipend. Nothing in the retreat path pays one. |
| Partial 12% | Not changed (step 5.8). |
| `stage.return_home` | Not changed. It stays free. |

New snapshot data keys (`EncounterSnapshotBuilder.build_round_snapshot`, always present):
`retreat_affordable` (bool, balance >= price, computed in pre_combat only; `false` in other phases, like `retreat_eligible`).
`retreat_ase_cost` already existed. It now holds 10.
`FlowKeeperIntroState` fixture snapshot also carries `retreat_affordable: false`.

## Tests (suite `retreat`, 15 tests, all pass)

New: `price_is_10_from_config`, `denied_below_price` (balance 9), `allowed_at_exact_price` (10 -> 0), `allowed_above_price` (25 -> 15), `failed_retreat_still_spends`, `snapshot_affordable_and_price` (9, 10, 11), `return_home_free_at_zero_ase`.
Updated: `venture_char/retreat_success_spends_ase_and_awards_intel` (cost read from config, not 40); `venture_char/retreat_without_ase_awards_intel_but_spends_nothing` is now `retreat_without_ase_is_denied`; `combat_roundtrip` retreats set balance 500; `snapshot` key list adds `retreat_affordable`; `PendingResultTests._drive_withdrawal` takes an optional `ase_before`.

## Tests run (filtered)

| Group | `Tests:` line |
|---|---|
| retreat | 15 total, 15 passed |
| econ_char,realm_reward,economy,objective | 82 total, 82 passed |
| retreat,venture_char,pending_result,save_integrity,unified_resolve | 74 total, 74 passed |
| foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity | 39 total, 39 passed |
| flow_transaction,seam,stage,combat_ui | 116 total, 116 passed |
| snapshot | 12 total, 12 passed |
| combat_roundtrip | 47 total, 47 passed |

`combat_baseline` was not completed in 115 s (timed out). `reward` and the full suite were not run.

## PREDICTED moved values

| Value | Cause |
|---|---|
| `data_keys` list in `snapshot` and the pre-combat snapshot fingerprints (if recorded) | One cause: the new key `retreat_affordable`. |
| `combat_baseline` retreat tick table | None expected: the roll seed is the tick, and no dispatch was added. |
| Balances in runs that retreat | One cause: the price is 10, not 30 (and was 0 for the old tests that passed `ase_cost: 0`). |
| Fingerprints, seek, baseline, roundtrip, maturity_baseline | None expected. Fights that do not retreat are not touched. |

Seen in the filtered runs: no fingerprint or key-list constant moved except the one `snapshot` list I extended by hand.

## What the UI must read (`ui/` not edited)

`ui/screens/combat/CombatBoardScreen.gd` ~1199-1210 builds the retreat button from `retreat_eligible` only. It must also read:

1. `data.retreat_affordable` (bool): when false, disable the button.
2. `data.retreat_ase_cost` (int): show the price in the reason.
3. `data.retreat_denied` (optional dict): shown only if a dispatch was refused; `reason` = `insufficient_ase`.

The reason text is Jeff's copy. This session proposes none.

## RUN REQUEST (main chat runs this)

1. Why: confirm no fingerprint, seek, baseline, roundtrip or maturity value moved; run `reward` alone.
2. Commands (each: delete the save dir first, one group per run):
```
rm -rf /tmp/echoes-econ004-phase54-run && ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase54-run /usr/bin/perl -e 'alarm shift; exec @ARGV' 900 /opt/homebrew/bin/godot --headless --quit --path "$(git rev-parse --show-toplevel)" -- tests =combat_baseline,fingerprint,seek,baseline,roundtrip,maturity_baseline
rm -rf /tmp/echoes-econ004-phase54-run && ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase54-run /usr/bin/perl -e 'alarm shift; exec @ARGV' 900 /opt/homebrew/bin/godot --headless --quit --path "$(git rev-parse --show-toplevel)" -- tests =reward
```
Use the exact suite names from the runner if a name does not match (`combat_roundtrip`, `combat_baseline`).
3. Files edited by the run: none.
4. Restore check: `git status --short` shows only the Phase 5.4 files.
5. Read back: every `Tests:` line, every failed test name with its message, and any `CB_RECORD` or `FP_DEBUG` line that differs from the recorded constants.
