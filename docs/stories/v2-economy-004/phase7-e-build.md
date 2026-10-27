# V2-ECONOMY-004 step 7.E build: fixes from the final Phase 7 QA (backend, D-119)

Rules: D-119 (F1, F3, F4, F5). Nothing is committed. `ui/`, `data/` values, Notion and the GDD are untouched.

## What the code does now

| Fix | Result |
|---|---|
| F1 | `FlowEncounterState.build_final_snapshot` reads the stage payout preview FIRST. A card that carries the preview gets no `encounter_gathered` row. The fight row stays in the earnings list. A mid-stage win keeps its row. |
| F3 | The standoff card has `fight_returns` (bool). `apply_retreat_return` returns `returns`: true when the engaged situation is not resolved, is revealed and has `retreat_pass_turn` (or an objective fight re-offered). `StandoffService.resolve` passes it as `fight_returns`. `add_standoff` takes it (default true); a stored card replays it (default true when the key is missing). |
| F4 | `FlowRuntime.dispatch`: when `pending_return_confirm` is true on a stage_explore snapshot, the caller gets a deep copy that still holds `return_confirm_requested`, and the key is erased from `flow_ctx.last_snapshot`. The builder is unchanged and stays pure. |
| F5 | `EarningsService.plan` `sources.<source>` has a new key `all` (every row of that source: settled and lost too). `EconomyService._base_rows` uses it for `encounters_overcome` `params.count` only. Amounts, the open-row `rows` and the show rule are unchanged. |

## F3 facts: the Claimant fight (design change NOT made)

- `ContactController.gd:~640` sets `resolved = true` on the Claimant situation BEFORE the forced fight starts.
- `find_explore_target` skips every `resolved` situation in Tier 1/2 and in Tier 4. So a stood-off Claimant fight never returns. `fight_returns` is false.
- The row id `enc:<sit>:claimant` exists so the fight can pay; no code can offer the fight again.
- Making it return needs `resolved` cleared for a Claimant whose conversation ended in hostility. That is a design change (the Claimant conversation would run again or a fight with no contact). Not done. Jeff decides.
- Harness case: a fight with no situation on the stage record gives `fight_returns` false (no situation can be found).

## Files changed

| File | Change |
|---|---|
| `core/state/flow/states/venture/FlowEncounterState.gd` | F1 order. |
| `core/realms/ActiveStageService.gd` | `apply_retreat_return` returns `returns`. |
| `core/realms/StandoffService.gd` | Facts carry `fight_returns`. |
| `core/state/flow/states/venture/ResolveSnapshotBuilder.gd` | `add_standoff(..., fight_returns = true)`. |
| `core/state/flow/states/venture/VentureResolveSnapshotBuilder.gd` | Passes it. |
| `core/state/flow/PendingResultService.gd` | Replays it. |
| `core/runtime/FlowRuntime.gd` | F4 one-shot. |
| `core/economy/EarningsService.gd`, `core/economy/EconomyService.gd` | F5 `all` count. |
| `tests/RetreatTests.gd` | 2 new tests; the standoff key list now has `fight_returns`. |
| `tests/EconomyCharacterizationTests.gd` | 2 new tests. |

## Tests

Compile check: 0 errors. Own `ECHOES_TEST_SAVE_DIR=/tmp/echoes-7e-saves`, deleted before each run (and at the end). All filters pass:

| Filter | Result |
|---|---|
| `=econ_char,seam` | 147 of 147 |
| `=objective,objective_combat` | 91 of 91 |
| `=stage,stage_stop_ui,stage_camera` | 84 of 84 |
| `=pending_result,save_integrity` | 32 of 32 |
| `=unified_resolve,foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity,realm_ui` | 72 of 72 |
| `=venture_char,flow_transaction,retreat,payout_ui,summon_price_ui,sanctum.summon` | 165 of 165 |
| `=realm,realm_prog,realm_reward,bridge,onboarding` | 59 of 59 |
| `=sit_res,contact,contact_cfg,combat_ui` | 93 of 93 |

New tests: `econ_char/packs_fight_after_last_objective_counts_once_on_the_card` (real builders; card total = `flow.complete_stage` payment; mid-stage win keeps its row), `econ_char/packs_fights_count_covers_settled_rows` (3 won, leave, 1 won: count 4, amount 6), `retreat/standoff_card_says_if_the_fight_returns` (normal, objective, claimant; each flag checked against the real `find_explore_target`), `retreat/return_confirm_is_one_shot_on_a_non_rebuilding_action` (`economy.settle_time` after the Sanctum button).

Probe (a green suite is not proof): with the three fixes F1, F4, F5 each reverted, 3 tests failed with the expected messages (F1: "card total is 42, flow.complete_stage paid 36"). Files restored and compared with `cmp`.

## PREDICTED moved values

| Constant or baseline | Prediction | Why |
|---|---|---|
| `fingerprint_*` FINAL, `fingerprint_determinism_*`, `fingerprint_seek` | Should NOT move | They hash `data` key NAMES of the final card of objective 0 (no fight row; preview unchanged, only read earlier). `fight_returns` is on the standoff card, which no fingerprint payload hashes (grep: only `CombatRoundtripIntegrationTests` builds it, and it checks forbidden keys, not a key list). `return_confirm_requested` is a stage_explore key, not hashed by FINAL. |
| `combat_baseline`, `maturity_baseline` | Should NOT move | No combat code, RNG or `EchoFactory` change. |
| `combat_roundtrip` | Should NOT move | Standoff card keys checked there are forbidden-key checks only. |
| `reward` | Should NOT move | No payer amount changed. F5 changes a count only. |
| `snapshot_fingerprint` (STAGE_EXPLORE hash) | Did not move (suite passed) | `sources.all` is not in the preview. |

If anything moves: remove `fight_returns` from the standoff card and re-run; if the old value returns, that key is the cause. Otherwise stop and attribute.

## ui/ changes needed (UI agent, next)

| File | Change |
|---|---|
| Standoff card screen (`ui/screens/venture/ResolveScreen.gd` and its standoff presentation) | Show the open-fight line ("The task is still there.") only when `data.fight_returns` is true. Use `.get("fight_returns", true)`. |
| `ui/screens/venture/ResolveScreen.gd` `_build_ledger` | No change for F1: a card with `stage_payout_ase` now has no `encounter_gathered` row, so `ase_awarded + gathered + stage_payout_ase` equals the payment. The "mid-stage win" layout test must still use the `encounter_gathered` row; a final win has none. Check the final win layout (no row, with payout) still renders. |
| `StageExploreScreen.gd:~1077, ~1683` | No change. The key is delivered once to the caller as before. |
| Tooltip for `encounters_overcome` | `params.count` now counts settled fights too. Read the text for a mismatch with the amount (count 4, amount for 1). |

## Findings not changed

- The `found_banked` count still counts open rows only (the brief named `encounters_overcome`). The same issue applies if a found row is settled and a new one comes later.
- `refresh_snapshot` / `economy.settle_time` still return the same `last_snapshot` object for other one-shot keys. Only `return_confirm_requested` was made one-shot.

## Ponytail: skipped

- No new action, state or save field. `fight_returns` is part of the card data and the stored card (default true on old stored cards).
- No change to the `found_banked` count.
- No design change for the Claimant fight.
- No `sources.all` for the leave plan or the gathered block (no reader needs it).

## RUN REQUEST (main chat runs; a subagent must not)

1. Command: `rm -rf /tmp/echoes-vnext-tests && /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =fingerprint_seek,reward,combat_baseline,combat_roundtrip,maturity_baseline`, then a second run with the filter `fingerprint` (all `fingerprint_*` and `fingerprint_determinism_*`). Tool `timeout: 3700000`. Use an own `ECHOES_TEST_SAVE_DIR` if another run is active.
2. Expected duration: several minutes per run (`reward` is the longest).
3. Files edited by the runs: none.
4. Verify: `git status --short` shows only the 11 files listed above plus this document.
5. Read back: the `Tests:` line and every failing line. Expected: all pass, no value moved. For a moved value report old and new, then apply the proof method above.

## OPEN — questions and assumptions

ASSUMED: `fight_returns` is false for a fight with no situation record (harness or debug fight). | WHY: nothing can be found again. | WRONG IF: a harness test of the UI expects true by default (the builder default is true when the key is absent).
ASSUMED: `all` counts lost rows too (a defeat marks rows lost, the fight was still won). | WHY: the brief said ALL fight rows. | WRONG IF: Jeff wants lost fights not counted in "Fights won".
ASSUMED: A stored standoff card without `fight_returns` replays as true. | WHY: old behaviour; saves are disposable. | WRONG IF: an old stored Claimant standoff card matters (it would show the open-fight line).
BLOCKED: Should a Claimant fight that ended in a standoff come back (clear `resolved`)? | CHECKED: ContactController.gd:~640, ActiveStageService.find_explore_target Tier 1/2 and 4. | NEED: Jeff's design decision. Not done.
