# V2-ECONOMY-004 Phase 5.3: objective weights, realm scale, replay factor

Status: built, short suites green, not committed. Decisions: D-13, D-29 to D-31, D-53, D-54, D-62, D-63, D-72 (note), D-87.

## 1. What changed

| Item | Change |
|---|---|
| `data.rewards.objective_weights` | pursue 16, combat 20, recover 24, protect 24, endure 28, shrine 30, guide_spirit 32, boss 0 (D-62). |
| `data.rewards.realm_scale_step` | New. 0.25 (D-63). |
| `data.rewards.replay_factor` | New. 0.35 (D-54). |
| `redo_penalty_per_run`, `redo_penalty_floor` | Removed from `balance.json` (section 3). |
| `RewardCalc.redo_multiplier` | Removed (section 3). |
| `RewardCalc.realm_scale(realm_id, realm_order, reward_cfg)` | New. `1 + step x position`, position 0-based in `realm_order`. A realm not in the list (the prologue) gives 1.0. |
| `RewardCalc.replay_factor(run_count, reward_cfg)` | New. 1.0 when `run_count` is 0 or less. Else `replay_factor`. |
| `RewardCalc.round_payout(amount)` | New. `roundi(amount + 1e-9)`, so a true x.5 never falls to x.4999. One rounding rule for every payer. |
| `ConfigService.get_realm_order(config_service)` | New static reader of `realm_order` (the only reader of that key in `core/` besides `FlowRealmSelectState`, which keeps its own inline read: out of scope). |
| `ActiveStageService.get_payout_factors(flow_ctx, config_service)` | New. Returns `{ realm_scale, replay_factor }` for the active realm. Used by the three payers that do not hold the realm model. |

### One producer

`EconomyService.stage_payout_rows(base, realm_scale, replay_factor, counts, ekwan_base, echo_home)` is the only producer for the stage payout. `settle_stage_complete` pays from it. `StageSettlementService.preview` shows it. Both read `StageSettlementService._plan`, which now returns `realm_scale` and `replay_factor` in place of `redo_mul`.

- Objective Ase = `round_payout(base x realm_scale x replay_factor)`. Rounded once on the stage sum.
- Ekwan = `round_payout(ekwan_base x realm_scale x replay_factor)`. Rounded once on its own sum.
- The stipend is `mini(alive x rate, cap)`. It is not scaled and ignores the replay factor. Its own replay cap (5) is unchanged (step 5.2).
- The rank is not read here (5.1b).

### Rows

| Row | Delta | Present when |
|---|---|---|
| `objectives_overcome` ("Base objectives") | `round_payout(base x realm_scale)` | Always. New param `realm_scale`. |
| `replay` ("Redo penalty" label kept) | Objective Ase minus the base row. Param `factor` = 0.35. | Only when the factor lowers the amount (run_count > 0 and base above 0). |
| `echoes_alive` | Stipend | `started` > 0 (unchanged). |

The rows add up to the Ase total. A test checks this.

### Defeat consolation

`reward_encounter_complete(victory, base_reward, realm_scale, replay_factor, rank, ...)` pays `round_payout(base x realm_scale x 0.25 x replay_factor)`. The 0.25 is unchanged. The `defeat_consolation` base row shows `round_payout(base x realm_scale)`. The penalty row is the step to the 25% amount. The `replay` row is the last step. The rows add up to the payout.
`RewardCalc.compute` now takes a last parameter `realm_scale_in` (default 1.0). It returns `realm_scale` (passed through) and `replay_factor`, in place of `redo_multiplier`. `FlowEncounterState` reads the scale from `ActiveStageService.get_payout_factors`.

### Retreat and return home: how they read today

Both read `ActiveStageService.get_stage_base_reward` (completed objectives, `RewardCalc.base_reward`) and multiply by `partial_intel_reward_factor` (0.12). Retreat is in `FlowRuntime.gd` (about line 1204). Return home is in `VentureController.gd` (about line 376; it also multiplies by `intel_retention_bonus`). Both now also multiply by `realm_scale` and `replay_factor` and round once with `round_payout`. The "carried home as an advance" rule is step 5.8 and is not built here.

## 2. Stage Ase and Ekwan per type (one completed pre-boss objective, plus the stipend of 2 Ase for one Echo not shown)

Format: Ase / Ekwan. Computed from the weights and the rules above. The test `econ_char/stage_payer_matrix` pins every cell through the real `StageSettlementService.settle`, and checks that the preview equals the payment.

| Type | realm.01 run 0 | realm.01 run 1 | realm.02 run 0 | realm.02 run 1 |
|---|---|---|---|---|
| pursue | 16 / 2 | 6 / 1 | 20 / 3 | 7 / 1 |
| combat | 20 / 2 | 7 / 1 | 25 / 3 | 9 / 1 |
| recover | 24 / 5 | 8 / 2 | 30 / 6 | 11 / 2 |
| protect | 24 / 3 | 8 / 1 | 30 / 4 | 11 / 1 |
| endure | 28 / 4 | 10 / 1 | 35 / 5 | 12 / 2 |
| shrine | 30 / 6 | 11 / 2 | 38 / 8 | 13 / 3 |
| guide_spirit | 32 / 3 | 11 / 1 | 40 / 4 | 14 / 1 |
| boss (stub alone) | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |

realm.03 has no config. The rule gives scale 1.50 (a pure test uses a four-realm `realm_order`). The shipped `realm_order` has two realms.

x.5 cells pinned (test `econ_char/stage_ase_rounds_once_on_the_sum`):

| Cell | Exact | Paid | If rounded per objective |
|---|---|---|---|
| shrine, realm.01, run 1 (Ase) | 10.5 | 11 | same |
| recover, realm.02, run 1 (Ase) | 10.5 | 11 | same |
| shrine, realm.02, run 0 (Ase and Ekwan) | 37.5 and 7.5 | 38 and 8 | same |
| endure + endure + combat, realm.01, run 1 (Ekwan 10) | 3.5 | 4 | 3 |
| recover + recover, realm.02, run 0 (Ekwan 10) | 12.5 | 13 | 12 |
| recover + protect, realm.01, run 1 (Ase 48) | 16.8 | 17 | 16 |

## 3. Removal audit (AGENTS.md removal exception, V2-PROG-012 precedent)

Names: `redo_penalty_per_run`, `redo_penalty_floor`, `redo_multiplier` (function, parameter, result key). Searched: `core/`, `ui/`, `tests/`, `scripts/`, `data/`, `docs/`, `CONVENTIONS.md`, `AGENTS.md`, `ANSWERS.md`. Grep `-i redo` over `core ui scripts data` after the change: only the label string "Redo penalty" (kept, legacy field `label`) and one `.tscn` node name `PressureDot` (not a hit of the key).

| Hit (before) | Action |
|---|---|
| `data/balance.json` `redo_penalty_per_run`, `redo_penalty_floor` | Removed. |
| `core/economy/RewardCalc.gd` `redo_multiplier()` and its use in `compute`, result key | Function removed. Result key replaced by `realm_scale` and `replay_factor`. |
| `core/economy/EconomyService.gd` parameter `redo_multiplier` in `reward_encounter_complete`, `settle_stage_complete`, `stage_payout_rows` | Replaced by `realm_scale` and `replay_factor`. |
| `core/economy/StageSettlementService.gd` `plan["redo_mul"]` and the log field `redo_multiplier` in `economy.stage.reward` | Replaced by `realm_scale` and `replay_factor`. Log field changed with them. |
| `core/state/flow/states/venture/FlowEncounterState.gd:203` | Migrated. |
| `tests/EconomyRewardTests.gd` config keys, tests `reward/redo_multiplier_floor` and `reward/redo_multiplier_partial`, call sites | Config keys replaced. The two tests are renamed `reward/replay_factor_flat` and `reward/replay_factor_first_run`. Call sites migrated. |
| `tests/EconomyCharacterizationTests.gd` test `econ_char/redo_multiplier_by_run_count`, call sites | Test replaced by `econ_char/realm_scale_and_replay_factor`. Call sites migrated. |
| `tests/RealmRewardTests.gd`, `tests/EconomyTests.gd` | Call sites migrated. |
| `tests/FlowFingerprintTests.gd:485` | Comment only. Reworded. No constant touched. |
| `ui/` | No hit. No `ui/` file edited. |
| `scripts/` | No hit. |
| `docs/` (live), `CONVENTIONS.md`, `AGENTS.md`, `ANSWERS.md`, `docs/MEMORY.md` | No hit. |
| `docs/stories/**` (records) | Not rewritten. They describe the past. |

No alias is left. `econ_char/removed_bonus_keys_absent` now also lists the three names and scans `data.rewards` and every `.gd` file in `core/`.

## 4. Tests

Edited (the `reward` group is listed; it was NOT run):

| File | Edit |
|---|---|
| `tests/EconomyRewardTests.gd` (`reward`) | Config: weights doubled, ladder keys replaced by `realm_scale_step` and `replay_factor`. Tests 7 and 8 replaced (renamed, see above). Call sites of `reward_encounter_complete` (4) and `settle_stage_complete` (1) take the extra argument. Header text. |
| `tests/EconomyCharacterizationTests.gd` (`econ_char`) | Weight table, stage cell table (`_STAGE_CELLS`), stage matrix now covers realm.01 and realm.02 at run 0 and run 1 with preview equal to paid and the replay row rule. Defeat table, ekwan replay cells, partial cells, pace-base cells, first defeat, completed-only, preview, real stage-ending card (50 + 10 and 50 + 8), stipend cells (base 20, replay base 7). `_settle_cell` takes `realm_id`. `_encounter_pay` takes `realm_scale`. |
| `tests/RealmRewardTests.gd` (`realm_reward`) | Signature of `stage_payout_rows`. |
| `tests/EconomyTests.gd` (`economy`) | Signature of `settle_stage_complete`. |
| `tests/FlowFingerprintTests.gd` | Comment only. |

New tests in `econ_char`:

| Test | Proves |
|---|---|
| `realm_scale_and_replay_factor` | Scale rule (realm.01 to realm.04 by rule), prologue 1.0, step read from config, replay 0.35 flat, `get_payout_factors` on a real context. |
| `stage_ase_rounds_once_on_the_sum` | The x.5 cells and multi-objective sums above, and that the rows add to the total. |
| `stage_payout_realm_scale_not_on_stipend` | Stipend unchanged by scale and replay. Replay row absent without a factor and on a base of 0. Row delta and `factor` param. |
| `consolation_takes_scale_and_replay` | Consolation cells, rows add up, a replay never pays more than a first run. |
| `partial_factors_follow_the_realm` | The partial formula with the factors (it mirrors the production formula; see "Could not verify"). |

## 5. Assumptions and findings

- ASSUMED: the "Base objectives" row shows the amount after the realm scale and before the replay factor. This keeps the rows adding up to the total with no new row. The brief names no scale row.
- ASSUMED (as the brief says): the defeat consolation takes the same scale and replay factor as the objective. The 0.25 is unchanged.
- ASSUMED: the partial payouts take scale and replay now, because they read the same `base_reward` helper. Step 5.8 will replace this with the advance rule.
- Rounding of partials changed from `roundi` to `round_payout` (adds 1e-9). It differs only where the exact value is an x.5 that float error would put below.
- Finding (not fixed): `FlowRealmSelectState` reads `realm_order` inline. It could use `ConfigService.get_realm_order`. Out of scope.
- Finding (not fixed): `partial_intel_reward_factor` and `defeat_factor` stay in config. `defeat_factor` has no reader now (the consolation 0.25 is a literal). Open since 5.1.

## 6. PREDICTED moved values

PREDICTED, one cause each. Cause for all rows below: the doubled weights (D-62), the flat replay factor (D-54), or the realm scale (D-63), as named.

| Recorded value or test group | Moves? | Cause |
|---|---|---|
| `fingerprint_*` FINAL and SAVE hashes (7 modes) | No | The fixtures are fight-level wins. A win pays 0 Ase at the fight (5.2), and the fixtures never dispatch `flow.complete_stage`. The fixtures are all wins in the recorded state (the PURSUE loss became a win at 3c). The stage payer is not reached. |
| `fingerprint_*` ROUNDS hashes | No | No combat code changed. |
| `fingerprint_seek`, `combat_baseline`, `combat_roundtrip` | No | Same reason. They read no weight. |
| `snapshot_fingerprint`, `snapshot_contract`, `snapshot_purity` | No (ran green) | Key lists unchanged. The base row gained the param `realm_scale` inside `params`, which those suites do not hash. |
| Defeat consolation in any recorded defeat fixture | Yes, if one exists | Weights doubled. None found in the fingerprint files. |
| Partial payouts (retreat, return home) | Yes | Weights doubled, plus scale and replay factor. Tests that assert an exact partial: `econ_char` (updated). `retreat`, `venture_char`, `pending_result` ran green because they set the partial amount directly. |
| `reward` group | Edited, not run | Needs the RUN REQUEST below. |

Also moved by this step, and covered by the edited tests: stage Ase and Ekwan in every cell of section 2.

## 7. RUN REQUEST (for the main chat)

1. Commands (one at a time; the shared fixtures forbid two at once). Set `ECHOES_TEST_SAVE_DIR` per command and delete it first.

```bash
cd /Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/echoes-vnext-test-timing-9693e6
rm -rf /tmp/echoes-econ004-phase53-run
ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase53-run /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path "$PWD" -- tests =reward
rm -rf /tmp/echoes-econ004-phase53-run
ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase53-run /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path "$PWD" -- tests =fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue,fingerprint_guide_spirit,fingerprint_determinism_combat,fingerprint_determinism_purify_shrine,fingerprint_determinism_recover,fingerprint_determinism_protect,fingerprint_determinism_endure,fingerprint_determinism_pursue,fingerprint_determinism_guide_spirit,fingerprint_seek
rm -rf /tmp/echoes-econ004-phase53-run
ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase53-run /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path "$PWD" -- tests =combat_baseline,combat_roundtrip,maturity_baseline
```
Use `timeout: 3700000` on the Bash tool call for each.

2. Expected duration: `reward` is the longest suite of the project (about 15 minutes alone in CI). The fingerprint group and the baseline group take minutes. Do not rely on a recorded figure.
3. Files the run edits: none. The suites write only under `ECHOES_TEST_SAVE_DIR`. No `trap` is needed.
4. Restore check: `git status --short` must show only the 14 files listed in the report, and `git diff --stat` must equal the figure before the run. Then `rm -rf /tmp/echoes-econ004-phase53-run`.
5. Read back: the `Tests:` line of each command, and every `FAIL` line. For a failing fingerprint, run `godot --headless --import` first (stale class cache) and run again before any attribution.

Expected: all green. If a `reward` test fails, it is a call site or an expected number from the old weights that this step missed; the edited list is in section 4.

## OPEN — questions and assumptions

ASSUMED: The "Base objectives" row shows the amount after the realm scale. | WHY: the rows must add up to the total, and the brief lists no scale row. | WRONG IF: the UI session wants the raw weight sum in that row and a separate scale row (a 5.6 row-set decision).
ASSUMED: The defeat consolation takes the scale and the replay factor. | WHY: the brief says so. | WRONG IF: Jeff wants a flat consolation.
ASSUMED: The retreat and return-home partials take the scale and the replay factor now. | WHY: they read the same helper (brief), and D-72 rule 2 wants that formula. | WRONG IF: Jeff wants them unscaled until step 5.8.
ASSUMED: a 1e-9 epsilon in `round_payout` is acceptable. | WHY: it pins x.5 cells (D-30) and follows the same trick as `_compute_rank`. | WRONG IF: Jeff wants plain `roundi`. The results differ in no tested cell.
BLOCKED: none.
