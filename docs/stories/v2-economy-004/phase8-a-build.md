# V2-ECONOMY-004 step 8.A build: technical debt round (backend)

Rules: D-121 (Jeff's defaults for follow-ups 25, 33 and 38). Nothing is committed. `ui/`, Notion and the Working GDD are untouched.
A first agent stopped midway. This build checked its partial edits (follow-up 25 and three test fixtures), fixed two errors in them, and finished the rest.

## Summary

| Follow-up | Result |
|---|---|
| 25 | `flow.complete_stage` re-checks `ObjectiveModel.stage_completable`. A failing stage is refused with a log and no state change. |
| 33 | The `encounter.retreat` handler computes the chance in core. `retreat_success_pct` and `cta.retreat.success_pct` are removed. |
| 34 | `TIER_PASSED_OBJECTIVE` is now `TIER_PASSED_FIGHT`. The key string changed too (audit below). |
| 38 | `StructuredLogger` has a real `error` level. Three config-error log types use it. |
| 50 | The fight win card carries a core `ase_gathered` (sum of its `encounter_gathered` rows). |
| 3 | The banner `surface` shows the objective being fought. |
| 56 | Comment fixed, header fixed, dead function removed, spec blocks 14f and 17 added. F-C (ignored retreat-passed fight) fixed. |

## 25: `flow.complete_stage` is re-validated

- Where: `VentureController.handle_complete_stage`, first lines.
- Gate: the same rule the offering snapshots use. A stage with no objectives passes (as on the Resolve card, `EncounterSnapshotBuilder._count_remaining_required_objectives`). Otherwise `ObjectiveModel.stage_completable(objectives)` must be true.
- Refusal: `logger.warn` type `stage.complete.refused`, then `FlowActionOutcome.handled_outcome()`. No save, no transition, no balance change.
- Legitimate paths still pass: the offered action (Resolve card and Explore card both use the same gate), the objective-complete path (the fight end marks the objective before this dispatch: `ActiveStageService` lines 713 and 779), and replays (the receipt stamp is unchanged).
- Errors found in the first agent's work: (1) `ObjectiveModel.make(..., {}, true)` in the new test sets `completed`, not `required`, so the stage was completable and nothing was refused; fixed to `{}, false, true`. (2) The realm-complete test moved `current_stage_index` but not `flow_ctx.stage_id`, so the gate read stage 0; the fixture now sets `stage_id`.
- Tests: `venture_char/complete_stage_refused_when_stage_not_completable` (new: refusal log, no index, balance, snapshot or flush change; then the same dispatch passes once the objective is overcome). Fixtures that dispatch `flow.complete_stage` first overcome the stage objectives (`VentureCharacterizationTests._overcome_stage_objectives`; used in `OnboardingTests` and three venture tests). `econ_char/earnings_every_completion_hook_writes_one_row` case C no longer un-completes its objective.
- Probe: `VentureController.gd` restored to HEAD gives 1 failure (the new test). File restored, `cmp` clean.

## 33: the retreat chance comes from core

- New `RetreatService.chance_tier(actors, config_service)`: reads `data.combat.retreat_agi_tiers` and calls `get_chance_tier`.
- `EncounterSnapshotBuilder.build_round_snapshot` uses it to decide whether `cta.retreat` exists. `FlowRuntime._handle_encounter_retreat` uses it for the chance. The action is no longer read for the chance (the handler parameter is now `_action`).
- Removed: `retreat_success_pct` (round snapshot data and the keeper-intro stub in `FlowKeeperIntroState.gd`) and `cta.retreat.success_pct`. `retreat_eligible`, `retreat_ase_cost`, `retreat_affordable` and `cta.retreat.ase_cost` stay.
- Audit (grep of `core/`, `ui/`, `tests/`, `docs/`, `scripts/`): `ui/` has no reader of either field. `scripts/screenshot.gd:485` carried `success_pct` in a mock action; removed. `docs/MEMORY.md:405` updated. The log line `encounter.retreat` keeps its `success_pct` field (the core value).
- A retreat sent when the party cannot attempt it (no tier) now uses chance 0, as a missing field did before. It still spends the Ase and starts the fight. See OPEN.
- Test seam: `RetreatTests.force_chance(flow_ctx, pct)` sets a one-tier table in `config_service._balance` and makes the party faster than the enemy. Fixtures that sent `success_pct` now call it: `RetreatTests`, `VentureCharacterizationTests`, `EconomyCharacterizationTests`, `CombatRoundtripIntegrationTests`, `CombatBaselineTests` (50 percent kept, same roll key).
- New tests: `retreat/hand_sent_success_pct_is_ignored` (core chance 0, hand-sent 100: the fight stays open), `retreat/snapshot_carries_no_chance`. `snapshot/pre_combat_has_retreat_fields` now asserts `retreat_success_pct` is absent.
- Probe: `FlowRuntime.gd` restored to HEAD fails 8 `retreat` tests, including the new one. File restored, `cmp` clean.

## 34: `TIER_PASSED_OBJECTIVE` renamed

- Audit: the constant is in `StagePartyMovementAdapter` (4 places), `ActiveStageService` (1), `StagePartyMovementTests` (4). The key string `state.tier_passed_objective` is only in `StagePartyMovementAdapter.TIER_PRESSURE_SOURCE`. It appears in no file under `data/`, no bark data, no test and no `ui/` file. It is a pressure-source token gated by prefix (`state.`) only.
- Because no bark data uses it, the constant and the key string were both renamed: `TIER_PASSED_FIGHT` and `state.tier_passed_fight`. A comment on the constant now says what it names.
- Story docs (history) still use the old name.

## 38: real `error` level

- `StructuredLogger`: `LEVEL_ERROR := "error"` and `error(t, type, msg, data)`. It is a severity, not a verbosity: kept at `info` and `debug`, dropped at `off` (so tests that silence the logger stay silent). `warn` is unchanged (stored as `info`). `set_level` is unchanged. `LogFormatter` shows `[Error]` for sev `error`; all other formats are unchanged.
- Moved to `error`: `economy.settle.config_error` (`StageSettlementService`), `economy.reward.missing_config_key` (`RewardCalc.cfg_num`), `economy.earnings.missing_row` (`EarningsService`).
- Tests that read these lines now also assert `sev == "error"`. Reason: the move is the change, so the test must pin it. They are `econ_char/missing_rewards_key_logs_and_returns_safe_value`, `settle_leave_fails_visibly_on_bad_carry_config`, `earnings_safety_net_writes_missing_row_and_logs`, `packs_fight_weight_reads_config_and_fails_visibly`. New: `econ_char/logger_error_level`.
- Probe: the three economy files with `warn` again give 4 failures. Files restored, `cmp` clean.
- No other log level changed. `RetreatService.get_ase_cost` and `RewardCalc` without a logger still use `push_error`.

## 50: core `ase_gathered` on the fight win card

- `ResolveSnapshotBuilder.fight_rows_ase(rows)` sums the `encounter_gathered` rows of a ledger. `FlowEncounterState.build_final_snapshot` calls `add_ase_gathered(_data, fight_rows_ase(_breakdown))`.
- One row (today's only case): the key equals that row's delta (6). A stage-ending win (the row sits in the stage payout), an objective fight and a defeat carry no row, so no key.
- Test change: `econ_char/packs_cards_carry_gathered_causes_and_replay` used to assert the fight card has NO `ase_gathered`. Reason: that was the old contract (7.C). It now asserts the key is 6. It also checks the sum of two fight rows (10), no key when no fight row exists, and no key on an objective fight card.
- Probe: `FlowEncounterState.gd` restored to HEAD fails the test. File restored, `cmp` clean.
- UI change needed (not made): see the ui list below.

## 3: banner `surface` shows the fought objective

- `FlowEncounterState.build_final_snapshot`: the surface is the type of `stage_objectives[active_encounter_objective_index]`. A fight that belongs to no objective (index -1) reads `combat` (before: the type of objective 0).
- Test: `econ_char/banner_surface_is_the_fought_objective` (index 0 gives `recover`, 1 gives `shrine`, -1 gives `combat`). Probe: with the old code, index 1 and -1 fail; index 0 passes. This matches the prediction below.
- `ResolveScreen` line 365 shows `surface` capitalised. A non-objective win now reads "Combat". UI to check.

## 56: stale and dead items

| Item | Result |
|---|---|
| `data/balance.json` stalemate `_comment` (line 1829) | Text only: "a forced retreat that pays nothing" is now "a standoff: the party steps back onto the path, it costs one turn and no Ase, and no pack row changes". JSON parses. No value changed. |
| `RewardCalc.base_reward` header | `MODE_COMPLETED` is selected only by `stage_ekwan`; no Ase payer uses it. Checked by grep of `base_reward(` in `core/`. |
| `ActiveStageService.get_stage_base_reward` | Removed (no caller in `core/`, `ui/` or `scripts/`). Tests called it in 5 places; they now use `EconomyCharacterizationTests._stage_base`, which calls `RewardCalc.base_reward` over the current stage's objectives (the same call the old function made). Comment lists in `ActiveStageService.gd` and `ConfigService.get_rewards_cfg` updated. The rename-history block in `ActiveStageService.gd` is kept as history, with one line saying the function was deleted. Other mentions (`VentureController`, `FlowRuntime` migration notes, story docs) describe the past and stay. |
| `docs/resolve-snapshot-block-spec.md` | Added blocks 14f `ase_gathered` and 17 `standoff` to the block table, the screen-section table and the API table, plus a rules note after the block 16 rules. The old Q3 text said blocks #16/#17 were deleted (the `title` and `note` blocks); the note says the numbers now name these blocks. |
| F-C: `stage.ignore_situation` did not clear `retreat_pass_turn` | `VentureController.handle_ignore_situation` now erases `retreat_pass_turn` on the ignored situation. An ignored fight with no marker is never re-offered (Tier 4), so ignoring the re-offer now ends it. An objective fight is still re-offered as an objective. Test: `retreat/ignoring_a_retreat_passed_fight_clears_its_marker`; probe: without the erase line it fails; restored, `cmp` clean. D-112 said "Jeff to decide"; D-121 says fix 56. See OPEN. |

Not fixed, found: the block spec has no rows for blocks 7b, 7c, 14c, 14d and 14e (`add_ledger_seen`, `add_stage_payout`, `add_thread_whole`, `add_objective_overcome`, `add_settle_outcome`). Only 14f and 17 were asked.

## Filtered runs (own `ECHOES_TEST_SAVE_DIR`, deleted before each run). Compile check: 0 errors.

| Filter | Result |
|---|---|
| `=econ_char,seam` | 149 of 149 |
| `=objective,objective_combat` | 91 of 91 |
| `=stage,stage_stop_ui,stage_camera` | 84 of 84 |
| `=pending_result,save_integrity` | 32 of 32 |
| `=unified_resolve,foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity,realm_ui` | 72 of 72 |
| `=venture_char,flow_transaction,retreat,payout_ui,summon_price_ui,sanctum.summon` | 171 of 171 |
| `=realm,realm_prog,realm_reward,bridge,onboarding` | 59 of 59 |
| `=sit_res,contact,contact_cfg,combat_ui` | 93 of 93 |
| `=traversal,movement,movement_option,movement_path,explore,explore_p5,social_graph,structure,combat_terrain` (for the rename) | 488 of 488 |

Not run (RUN REQUEST): `fingerprint_seek`, `reward`, `combat_baseline`, `combat_roundtrip`, `maturity_baseline`, all `fingerprint_*` and `fingerprint_determinism_*`. `combat_baseline` and `combat_roundtrip` fixtures were edited (follow-up 33).

## PREDICTED moved values (none re-recorded)

| Item | Prediction |
|---|---|
| 25 | None. No snapshot changes. |
| 33 | None in FINAL fingerprints. They hash the final Resolve snapshot; `retreat_success_pct` was in the round snapshot only. `combat_baseline` retreat probes keep the same roll key and the 50 percent chance, so the same outcome is expected. |
| 34 | None expected. The key string is a pressure-source token. If a movement or fingerprint hash includes it, the hash moves; no such test is known. |
| 38 | None. Log sev is not hashed. |
| 50 | None. The FINAL fingerprint fixtures fight objective index 0, so no `encounter_gathered` row exists and no `ase_gathered` key is added. |
| 3 | None for the 14 FINAL constants. The fixtures fight objective index 0, and the new surface is the type of objective 0, which the old code also showed. The constants would move only for a fixture with a fought index other than 0. |
| 56 | None. |

Hash proof method if a constant moves: save `core/state/flow/states/venture/FlowEncounterState.gd`, restore it from `git show HEAD:<path>`, run the same suite, and confirm the OLD constant returns. Then restore the saved file and `cmp`.

## ui/ changes needed (for the UI agent; none made)

1. `ui/screens/venture/ResolveScreen.gd:572` `_gathered_ase`: the fight win card now carries `ase_gathered`, so the function can read that key alone and drop the `encounter_gathered` row fallback (follow-up 50). Optional: both paths give the same number for one row.
2. `ui/screens/venture/ResolveScreen.gd:365`: the banner shows `surface`. A normal (non-objective) win now says "Combat"; an objective win says the fought objective. Check the look.
3. Nothing reads `retreat_success_pct` or `cta.retreat.success_pct` in `ui/`. No change.
4. Follow-up 37 and 45 are UI items from D-121; they are not in this backend step.
5. Left alone: `scripts/screenshot.gd:417` still sets `retreat_tier_label` (removed in 6.4).

## RUN REQUEST

1. Command (pass tool `timeout: 3000000`):
   `rm -rf /tmp/echoes-8a-saves && ECHOES_TEST_SAVE_DIR=/tmp/echoes-8a-saves/ /usr/bin/perl -e 'alarm shift; exec @ARGV' 2800 /opt/homebrew/bin/godot --headless --quit --path "<this worktree>" -- tests =fingerprint_seek,reward,combat_baseline,combat_roundtrip,maturity_baseline,fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue,fingerprint_guide_spirit,fingerprint_determinism_combat,fingerprint_determinism_purify_shrine,fingerprint_determinism_recover,fingerprint_determinism_protect,fingerprint_determinism_endure,fingerprint_determinism_pursue,fingerprint_determinism_guide_spirit`
2. Expected duration: several minutes (`combat_roundtrip` and the fingerprint suites are the slow ones). Run `--import` first only if a stale cache is suspected.
3. Files the run edits: none in the repo (saves go to the isolated save dir). No `trap` needed.
4. Verify: `git status --short` is unchanged by the run.
5. Read back: the `Tests:` line and every failed test name with its message. For any fingerprint failure, read the old and the new constant.
