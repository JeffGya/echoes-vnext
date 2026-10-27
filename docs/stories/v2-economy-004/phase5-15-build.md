# V2-ECONOMY-004 step 5.15 — F3a, F3b, failed-escape message

No fingerprint hash moved in the filtered runs. No recorded value moved. `ui/` untouched.

## Changes
| Place | Change |
|---|---|
| `data/balance.json` `data.rewards.contact_claimant_good_ase` | New key, value 20 (same as the old literal). Additive. |
| `ContactController.claimant_good_ase(reward_cfg, log, t)` | New static reader through `RewardCalc.cfg_num`. Missing key: `economy.reward.missing_config_key` warning, pays 0. The literal `_ase_reward := 20` is gone. |
| `SummonService.price_for` | Missing `<grade>_extra`: `push_error`, base price only (same pattern as `village_ceiling`, 5.13). |
| `VentureController` failed-escape `return_home_result.message` | Now: `It was not possible to escape at the moment. Move on, we can try again later.` Jeff's text, unchanged. |
| `scripts/screenshot.gd:378` | Fixture string updated to the same text. |

## Audit: other literals in ContactController (report only, not fixed)
- No other Ase or Ekwan payout literal.
- Morale literals via `apply_morale_to_party`: +8 (charge good), +4 (charge partial), +5 (claimant good), +3 (claimant partial). These are emotion, not payouts.
- Config reads with a code fallback: `continuity_temporary_ally_good` default 5, `combat_fear_bleed` default 8, `fear/morale` default 50 on a contact.

## Old text search (whole repo)
- Exact old text: only `VentureController.gd` and `scripts/screenshot.gd` (both updated).
- `tests/ResolvePayoutUITests.gd:921,1217` and `tests/VentureCharacterizationTests.gd:1064` use "The way is blocked." as injected fixture data. They pin nothing. Not changed.
- `docs/stories/v2-economy-004/phase5-14-build.md:22` names the old text in a past note. History, not changed.
- `ui/`: no reference to the old text.
- No old text in `CONVENTIONS.md`.

## New tests
| Test | Checks |
|---|---|
| `econ_char/contact_claimant_good_ase_is_20_and_missing_key_logs` | Shipped value 20, no log. Empty config: 0, one log at injected `t` with the key name. |
| `sanctum.summon/missing_grade_surcharge_pays_base_only` | called 150, chosen with no key 60. The runner cannot capture `push_error`. Probe: the run output shows `ERROR: SummonService: data.summoning.chosen_extra is missing; no surcharge applied` (seen once). |
| `venture_char/return_home_failed_escape_message` | A failed escape roll publishes `success=false` and the exact message. |

## Measured (filtered, own `ECHOES_TEST_SAVE_DIR`, deleted before each run)
| Run | `Tests:` line |
|---|---|
| econ_char, objective, seam | 143 total, 143 passed |
| stage, pending_result, save_integrity | 40 total, 40 passed |
| unified_resolve, foundation_ui, snapshot_contract, snapshot_fingerprint, snapshot_purity | 52 total, 52 passed |
| sanctum.summon, venture_char, retreat | 63 total, 63 passed |
| flow_transaction, payout_ui, summon_price_ui | 55 total, 55 passed |
| contact, contact_cfg, contact_actor, economy | 37 total, 37 passed |
| econ_char alone (first check) | 73 total, 73 passed |

Not run (by order): `reward`, fingerprint suites, full suite. Compile check: zero errors.

## RUN REQUEST
1. Command: `export ECHOES_TEST_SAVE_DIR=/tmp/echoes-5-15-b/; rm -rf $ECHOES_TEST_SAVE_DIR; /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <worktree> -- tests =fingerprint_seek,reward,combat_baseline,combat_roundtrip,maturity_baseline,fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue,fingerprint_guide_spirit,fingerprint_determinism_combat,fingerprint_determinism_purify_shrine,fingerprint_determinism_recover,fingerprint_determinism_protect,fingerprint_determinism_endure,fingerprint_determinism_pursue,fingerprint_determinism_guide_spirit` with tool timeout 3700000.
2. Duration: several minutes.
3. Files edited by the run: none.
4. Verify: `git status --short` shows only the step 5.15 edits.
5. Read back: every `Tests:` line and each failed test name. Expected: no moved hash, no moved constant.
