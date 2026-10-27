# V2-ECONOMY-004 step 5.13 — config is the only source of economy numbers

Follow-ups closed: 15, 16, 17, 29, 31. No `data/` file changed. No recorded value moved.

## Changes
| Place | Change |
|---|---|
| `RewardCalc.cfg_num(cfg, key, safe, logger, t)` | New. One reader of a numeric `data.rewards` key. Missing key: `logger.warn("economy.reward.missing_config_key", {key, safe})`, or `push_error` when no logger. Returns `safe` (a neutral value, not a design number). |
| `RewardCalc` | `realm_scale_step`, `replay_factor`, `pace_full_ratio`, `pace_zero_ratio`, `rank_points`, `rank_thresholds` lose their code defaults. `realm_scale`, `replay_factor`, `rank_score`, `_compute_rank` take optional `logger, t`. Pace ratios are read only in a pace mode. |
| `EncounterSetupService._setup_pace` | Pace ratios read through `cfg_num`. |
| `StageSettlementService` | `partial_intel_reward_factor` (0.12) through `cfg_num`; logger passed to the factors. |
| `ActiveStageService.get_payout_factors` | Optional `logger, t`. |
| `EconomyService.reward_encounter_complete` | New last parameter `defeat_factor`. The two literal 0.25 are gone. `FlowEncounterState` passes `data.rewards.defeat_factor` (read only on a defeat). |
| `SummonService.village_ceiling` | No default 14. Missing key: `push_error`, no cap. |
| `RetreatService.get_ase_cost` | No fallback 10. Missing key: `push_error`, cost 0. |
| `FlowSummonState` | Removed unread key `ase_cost_per_summon`. |
| Comments | Block-count comments (`ResolveSnapshotBuilder`, `PendingResultService`, `FlowSnapshotFingerprintTests`) now name no number (the builder has 21 `add_*`). `VowService` comment now says a spend above the balance is denied whole and the result is ignored. |

## Checks
- `data.rewards.defeat_factor` is 0.25 (new test `econ_char/balance_defeat_factor_is_one_quarter`). All other code defaults already equal the `balance.json` values (0.25, 0.35, 1.1, 1.6, 0.4/0.4/0.2, S 0.9 / A 0.75 / B 0.55 / C 0.35 / D 0.15, 0.12, 14, 10). No key added.
- `ase_cost_per_summon` is read nowhere: grep of `core/`, `ui/`, `tests/`, `docs/` (outside story notes) finds only the producer and its test pin. The summon snapshot is in no fingerprint test. The pin now asserts the key is absent.
- New test `econ_char/missing_rewards_key_logs_and_returns_safe_value`: missing key logs the error at the injected `t`; a full config logs nothing.

## Finding
`retreat/price_is_10_from_config` built `ConfigService.new()` with no balance loaded. It passed through the old fallback 10, so it never read the config. It now calls `load_balance()`.

## Measured (filtered, own `ECHOES_TEST_SAVE_DIR`, deleted before each run)
| Run | `Tests:` line |
|---|---|
| econ_char, objective, seam, stage, pending_result, save_integrity | 181 total, 181 passed |
| unified_resolve, foundation_ui, snapshot_contract, snapshot_fingerprint, snapshot_purity | 52 total, 52 passed |
| venture_char, flow_transaction, payout_ui, summon_price_ui (retreat failed once, see Finding) | 82 passed, 1 failed (the retreat test above) |
| retreat after the fix | 15 total, 15 passed |
| sanctum.summon, realm_reward, economy, econ_char | 114 total, 114 passed |

Not run (by order): `reward`, fingerprint suites, full suite.

## Not done
- `ContactController.gd:617` literal 20: left alone, report only.
- Safe values are neutral by choice: factors 1.0, bonuses 0.0, rank thresholds 2.0 (unreachable, so rank F), pace zero ratio 2.0.

## RUN REQUEST
1. Command: `ECHOES_TEST_SAVE_DIR=/tmp/echoes-5-13-b/ ; rm -rf $ECHOES_TEST_SAVE_DIR; /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <worktree> -- tests =fingerprint_seek,reward,combat_baseline,combat_roundtrip,maturity_baseline,fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue,fingerprint_guide_spirit` with tool timeout 3700000.
2. Duration: several minutes.
3. Files edited by the run: none.
4. Verify: `git status --short` shows only the step 5.13 edits.
5. Read back: every `Tests:` line and each failed test name. Expected: no moved hash, no moved constant.
