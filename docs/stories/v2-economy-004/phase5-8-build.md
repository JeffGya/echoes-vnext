# V2-ECONOMY-004 Phase 5.8: carried home is an advance on the stage payout

Status: built, short suites green, not committed. Decisions: D-14, D-24, D-30, D-54, D-63, D-72, D-87.

## 1. The rule

| Event | Ase | Ekwan |
|---|---|---|
| Retreat or return home | `round_payout(base_completed x realm_scale x replay_factor x 0.12 x retention)` minus `carried_ase`, never below 0 | `round_payout(ekwan_completed x realm_scale x replay_factor x 0.12)` minus `carried_ekwan`, never below 0 |
| After paying | `carried_ase` += amount paid | `carried_ekwan` += amount paid |
| Stage end (`settle`) | Full Ase (objectives + stipend) minus `carried_ase`, never below 0 | Full Ekwan minus `carried_ekwan`, never below 0 |

- 0.12 is `data.rewards.partial_intel_reward_factor` (unchanged).
- `retention` is the Scout `intel_retention_bonus` (1.0 when the directive does not retain intel). It applies to Ase only, BEFORE the subtraction. See OPEN.
- One rounding, on the product (as in step 5.3). It is not "round the stage amount, then take 12%".
- The intel gate stays: no revealed situation in the stage, no partial (the rule before D-72).
- A repeat return with no new objective carries 0 more. This closes B5.
- A failed roll (retreat or return home) pays and records nothing. This is the rule before D-72: the partial is paid only on success.

## 2. Design

| Item | Where |
|---|---|
| Shared helper `StageSettlementService.carry_plan(ctx, config_service, retention_mul)` (pure) | `core/economy/StageSettlementService.gd` |
| Shared helper `StageSettlementService.carry_home(ctx, config_service, econ, retention_mul, reason, logger, t)` (pays and records) | same file |
| `StageSettlementService.retention_mul(directive)` | same file |
| Retreat payer calls `carry_home` (retention 1.0, reason `retreat_intel_partial`) | `core/runtime/FlowRuntime.gd` `_handle_encounter_retreat` |
| Return-home payer calls `carry_home` (directive retention, reason `return_home_intel_partial`) | `core/runtime/controllers/VentureController.gd` `handle_return_home` |
| `stage_payout_rows(..., carried_ase, carried_ekwan)` and `settle_stage_complete(..., carried_ase, carried_ekwan)`: new last parameters, default 0 | `core/economy/EconomyService.gd` |
| `_plan` returns `carried_ase`, `carried_ekwan`; `settle` and `preview` pass them | `StageSettlementService.gd` |
| `ActiveStageService.get_carried(ctx)` read-only `{ ase, ekwan }` | `core/realms/ActiveStageService.gd` |
| `FlowContext.pending_scout_return_ekwan` (volatile, never saved) | `core/state/flow/FlowContext.gd` |

The old private partial formulas in `FlowRuntime.gd` and `VentureController.gd` are deleted. `get_stage_base_reward` stays (the pace base and tests still read it).

The `settlement_receipt` shape and exactly-once rule are unchanged. A second `settle` still returns `{}`.

The stage dict gains fields only when something is carried. A stage with no carry has no new key. An old save reads 0.

## 3. New fields (for the UI sessions)

| Field | Where | Type | Meaning |
|---|---|---|---|
| `carried_ase` | stage dict in save (`realms.<id>.stages[i]`) | int, default 0 | Ase already paid from this stage by returns and retreats. |
| `carried_ekwan` | same | int, default 0 | Ekwan, same. |
| `data.carry_home_preview` | STAGE_EXPLORE snapshot | `{ ase: int, ekwan: int, overcome: int, total: int }` | What a return home would bank NOW (after the retention bonus of the active directive). `overcome` and `total` as in `objectives_overcome` (boss stub excluded). Always present; show "carried home" only when `ase` or `ekwan` is above 0 (D-71). |
| `data.carry_retreat_preview` | ENCOUNTER snapshot (pre-combat phase; zeros in other phases) | same shape | What a successful retreat would bank NOW. Retention is 1.0 on a retreat. |
| `data.stage_payout_ase`, `data.stage_payout_ekwan` | victory card (existing keys) | int | Now NET of what was carried. Equals what `flow.complete_stage` pays (test). |
| `data.stage_payout_rows[]` row, `cause = "carried_advance"` | victory card | `{ label "Carried home", delta -min(carried_ase, gross), currency "ase", params { carried_ase, carried_ekwan } }` | Present only when `carried_ase` > 0. The rows add up to `stage_payout_ase`. Ekwan has no row. |
| `data.reward_breakdown[]` row `partial_return_home` / `partial_retreat` | scout-return card | params gain `carried_before` (int) | Ase carried before this return. |
| `data.ekwan_awarded` | scout-return card | int | Was always 0. Now the Ekwan carried by this return or retreat. |
| `data.ase_awarded` | scout-return card | int | The Ase carried by this return or retreat (unchanged meaning, new amounts). |

The names `carry_home_preview` and `carry_retreat_preview` are the final names (the brief gave them as proposals).

Notes for the UI:
- A repeat return with `overcome` > 0 and nothing new to carry gives `ase_awarded` 0 and NO breakdown row (the `nothing_overcome_yet` row shows only when `overcome` is 0). The card may need its own sentence for this case. That is a copy decision for Jeff.
- The scout-return card may now show an Ekwan line (`ekwan_awarded` > 0).

## 4. Tests

Edited: `tests/EconomyCharacterizationTests.gd` (`econ_char`). `_settle_cell` takes `carried_ase` and `carried_ekwan` (default 0; it erases the fields otherwise).
No test asserted the old partial through production code (they mirror the formula), so none was changed for the old behaviour.

New tests in `econ_char`:

| Test | Proves |
|---|---|
| `carried_first_return_by_realm_and_run` | realm.01 and realm.02, run 0 and run 1: Ase 9/12/3/4, Ekwan 2/2/1/1 for shrine + recover + protect; stage fields, balance, overcome 3 of 3. |
| `carried_repeat_and_increment` | Repeat return carries 0/0. A new objective carries the increment (2 Ase, 0 Ekwan). |
| `carried_scout_bonus_before_subtraction` | 30 x 0.12 x 1.5 = 5 Ase, Ekwan unchanged (1); Scout after a plain 4 carries 1. `retention_mul` cases. |
| `carried_nothing_overcome_and_old_save` | 0 and no field written; no revealed situation gives 0; old stage without fields previews 30/6 with no `carried_advance` row. |
| `carried_stage_end_pays_full_minus_carried` | Through real `settle`: 52/8 full, carried 6/1, paid 46/7; row -6; rows sum to paid; preview equals paid and is pure; second settle returns `{}`; no carry pays 52/8 with no row. |
| `carried_rows_clamp_and_sum` | Oversize carry never goes below 0. Zero carry adds no row. |
| `carried_return_home_preview_equals_action` | Real `stage.return_home` dispatch: `carry_home_preview` equals the card, the balance and the stage; `carried_before` 0; preview after is 0/0. |
| `carried_retreat_preview_equals_action` | Real `encounter.retreat` dispatch (100% roll): `carry_retreat_preview` equals the card, the balance (minus the price 10) and the stage. |

Falsification: with the subtraction removed from `carry_plan`, `econ_char` showed 3 failures. The change was reverted.

## 5. Suites run (own save dir `/tmp/echoes-econ004-phase58`, deleted before each run)

| Filter (`tests =...`) | `Tests:` line |
|---|---|
| `econ_char` | 60 total, 60 passed, 0 failed |
| `realm_reward,economy,objective,venture_char` | 46 total, 46 passed, 0 failed |
| `pending_result,save_integrity,unified_resolve,foundation_ui` | 60 total, 60 passed, 0 failed |
| `snapshot_contract,snapshot_fingerprint,snapshot_purity,retreat,flow_transaction` | 46 total, 45 passed, 1 failed (`snapshot_fingerprint/stage_explore`, predicted; re-recorded, see section 6) |
| `snapshot_fingerprint` (after the re-record) | 2 total, 2 passed, 0 failed |
| `seam,stage,snapshot,combat_ui,explore,explore_p5` | 163 total, 163 passed, 0 failed |

`reward` and the full suite were NOT run.

## 6. PREDICTED moved values (one cause each)

| Value | Moves? | Cause |
|---|---|---|
| `STAGE_EXPLORE_FINGERPRINT_HASH` (`tests/FlowSnapshotFingerprintTests.gd`) | YES, re-recorded: `b4c2a6e7...19d9` to `1728e1fe...df7e` | One new key `data.carry_home_preview`. Attributed: with the key removed, the old hash returned. |
| Key lists of the stage-explore and encounter snapshots | The stage-explore and encounter snapshots gain one key each. No key list in `snapshot_contract` failed, so none was edited. | New keys `carry_home_preview`, `carry_retreat_preview`. |
| Combat fingerprints (`fingerprint_*`), `fingerprint_seek`, `combat_baseline`, `combat_roundtrip`, `maturity_baseline` | NO move predicted | They do not retreat, return home or settle; the combat state is untouched. |
| `snapshot_fingerprint` (the other test) and `reward` | NO move predicted | Not read by this change. `reward` must be run (section 7). |

## 7. RUN REQUEST (main conversation runs it)

1. Commands (each with its own save dir; run one after the other, never two at once). Replace `<checkout>` with `/Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/echoes-vnext-test-timing-9693e6`:

```bash
for g in "fingerprint_combat,fingerprint_determinism_combat,fingerprint_purify_shrine,fingerprint_determinism_purify_shrine,fingerprint_recover,fingerprint_determinism_recover" \
         "fingerprint_protect,fingerprint_determinism_protect,fingerprint_endure,fingerprint_determinism_endure,fingerprint_pursue,fingerprint_determinism_pursue,fingerprint_guide_spirit,fingerprint_determinism_guide_spirit" \
         "fingerprint_seek" \
         "combat_baseline" "combat_roundtrip" "maturity_baseline" "snapshot_fingerprint" "reward"; do
  rm -rf /tmp/echoes-econ004-phase58
  ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase58 /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 \
    /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =$g 2>&1 | grep -a "Tests:\|❌"
done
```

2. Timeout to pass to the tool: 3700000 ms. Alarm: 3600 s (as above). Expected duration: several minutes in total (the `fingerprint_*` groups are the longest; `reward` is short).
3. Files edited by the run: none. (The tests write only under `/tmp/echoes-econ004-phase58`.)
4. Restore check: `git status --short` must show only the files listed in section 8, and `git diff --stat` must be unchanged from before the run.
5. Output to read back: every `Tests:` line and every line starting with `❌`. Expected: all groups `0 failed`. Any failure in a `fingerprint_*`, `combat_baseline`, `combat_roundtrip` or `maturity_baseline` group is NOT predicted and needs attribution before any constant changes.

## 8. Files changed

- `core/economy/StageSettlementService.gd`
- `core/economy/EconomyService.gd`
- `core/realms/ActiveStageService.gd`
- `core/runtime/FlowRuntime.gd`
- `core/runtime/controllers/VentureController.gd`
- `core/state/flow/FlowContext.gd`
- `core/state/flow/states/venture/VentureResolveSnapshotBuilder.gd`
- `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd`
- `core/state/flow/states/venture/EncounterSnapshotBuilder.gd`
- `tests/EconomyCharacterizationTests.gd`
- `tests/FlowSnapshotFingerprintTests.gd` (one constant, named cause above)
- `docs/stories/v2-economy-004/phase5-8-build.md` (this file)

Not mine: `docs/stories/v2-economy-004/follow-ups.md` shows a modified line 24 (summon UI session). It was already modified in this checkout. I did not touch it.
