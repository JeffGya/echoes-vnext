# V2-ECONOMY-004 step 6.1 build: early-leave settlement (backend)

Rules: D-104 to D-106. Design file: `phase6-early-leave-design.md`. Nothing is committed.

## Files changed

| File | Change |
|---|---|
| `data/balance.json` | Added `rewards.carry_odds` {none 50, some 30, all 20} and `rewards.carry_shares` {0, 0.5, 1.0}. Removed `partial_intel_reward_factor`. |
| `core/economy/StageSettlementService.gd` | `carry_plan` is now pure `settle_plan`. `carry_home` is now `settle_leave`. New `carry_table` (odds from config, Scout shift, renormalise). `_plan` skips settled objectives for the base and Ekwan sums. |
| `core/economy/RewardCalc.gd` | New `unsettled(objectives)`. |
| `core/economy/EconomyService.gd` | `stage_payout_rows` and `settle_stage_complete` take `settled_ase`, `settled_ekwan`. Removed the negative `carried_advance` row. Added zero-delta memo row `settled_on_leave`. |
| `core/realms/ActiveStageService.gd` | Removed `get_carried`. |
| `core/runtime/controllers/VentureController.gd` | `handle_return_home` calls `settle_leave` after the escape succeeds. |
| `core/runtime/FlowRuntime.gd` | Retreat success no longer pays (D-106 item 2; step 6.2 owns the rest). New `pending_scout_return_settle_outcome` reset in three places. |
| `core/state/flow/FlowContext.gd` | New field `pending_scout_return_settle_outcome`. |
| `core/state/flow/PendingResultService.gd` | Replays `settle_outcome` from the stored result. |
| `.../venture/ResolveSnapshotBuilder.gd` | New `add_settle_outcome`. |
| `.../venture/VentureResolveSnapshotBuilder.gd` | Scout-return row now `settle_none/some/all/nothing_new` (word, no share). Payload carries `settle_outcome`. |
| `.../venture/StageExploreSnapshotBuilder.gd` | `carry_home_preview` = {ase, ekwan, overcome, total, nothing_new}. No odds. Pure. |
| `.../venture/EncounterSnapshotBuilder.gd` | `carry_retreat_preview` amounts stay 0; counts kept. |
| `CONVENTIONS.md` (line 925), `docs/MEMORY.md` (lines 401, 407) | Stale "carried home" text replaced. |
| `tests/EconomyCharacterizationTests.gd`, `tests/VentureCharacterizationTests.gd` | See below. |

Roll stream: `CampaignSeed.get_rng_from(realm_seed, "stage.settle.<stage_id>.<run_count>.<settle_count>")`, one `randi_range(0, 99)`. It is drawn only when `settle_plan` has something new. No existing draw moved.

## Answer: does a replay reset the `settled` marks?

Yes. `RealmService.get_or_create` on a completed realm builds new stages through `RealmGenerator`. New objective dicts carry no `settled`, `settled_share`, `settled_ase`, `settled_ekwan` or `settle_count`. Test `econ_char/settle_replay_resets_marks` proves it on a real runtime.

## Tests

New tests (all in `tests/EconomyCharacterizationTests.gd`, all pass):
`settle_plan_gathered_by_realm_and_run`, `settle_odds_come_from_config_and_scout_shifts_them`, `settle_roll_seeded_distribution`, `settle_pays_once_and_marks`, `settle_nothing_new_changes_nothing`, `settle_reroll_blocked_by_cancel_reload_retry`, `settle_scout_never_pays_over_the_gathered_amount`, `settle_defeat_keeps_what_the_leave_paid`, `settle_stage_end_pays_unsettled_only`, `settle_rows_memo_not_negative`, `settle_worked_example_74` (1 done: 64/74/84, 2 done: 40/62/84), `settle_replay_resets_marks`, `settle_return_home_dispatch_word_outcome_no_odds` (forbidden-key scan of the snapshots), `settle_retreat_pays_nothing`.

Rewritten tests, each with its reason:

| Test | Reason |
|---|---|
| `econ_char` carry tests (old 12% / `carried_advance` / subtraction cases, earlier agent) | The 12% factor, the subtraction and the negative row no longer exist (D-105). Replaced by the settle tests above. |
| `econ_char/cause_scout_return_rows` (this session) | It pinned cause `partial_return_home` with delta 3 from `pending_scout_return_ase` alone, and a `partial_retreat` row. Now: a return home with outcome `some` gives cause `settle_some`, delta 3. A retreat card has no row, because a retreat settles nothing (D-106). Assertions on counts and the zero row are unchanged. |
| `venture_char/_t_retreat_success`, `_t_retreat_snapshot` | `_expected_intel_partial` (12% of completed weights) removed. The expected award is 0: a retreat pays only its cost. |

## Run results (filtered, own save dir deleted before each run)

All pass except one predicted failure: econ_char 79/79, objective 91, seam 44, stage 84, pending_result 8, save_integrity 22, unified_resolve 13, foundation_ui 17, snapshot_contract 8, snapshot_purity 12, venture_char 16, flow_transaction 9, retreat 15, payout_ui 36, summon_price_ui 10, sanctum.summon 32. Compile check: zero errors.

`snapshot_fingerprint/stage_explore` FAILS (expected `1728e1fe...`, actual `5515ca86...`). Attribution probe: with the `nothing_new` key removed from `carry_home_preview`, the suite passes 2/2 (file restored, `cmp` clean). The new key is the only cause. I did not re-record it.

## PREDICTED moved values (for the RUN REQUEST)

| Constant or baseline | Moves? | Why |
|---|---|---|
| `snapshot_fingerprint/stage_explore` | YES (measured) | New key `carry_home_preview.nothing_new`. |
| `fingerprint_seek`, `fingerprint_*` stage-explore modes | Possible | They hash the explore snapshot only if it holds `carry_home_preview`; the same one key. Re-record with this one cause. |
| `reward` suite | Possible | Pins stage payout totals after a leave and `partial_intel_reward_factor`; not run (brief). |
| `combat_baseline`, `combat_roundtrip`, `maturity_baseline`, `fingerprint_determinism_*` | Should NOT move | No combat or existing RNG draw changed. Only a new path-derived stream was added. Any move here is a regression. |

## ui/ references (not edited; for the UI step 6.3)

- `ui/screens/combat/CombatBoardScreen.gd:1219` reads `carry_retreat_preview`; amounts are now always 0.
- `ui/screens/venture/StageExploreScreen.gd:620` reads `carry_home_preview` (now holds `nothing_new`, still `ase`/`ekwan`).
- `ui/components/CarriedHomePanel.gd` (+ `.tscn`): panel for the old carried amount.
- `ui/components/PayoutCausePresentation.gd:17,21,24,28,31`: labels for `partial_return_home` and `carried_advance`; no labels for `settle_none/some/all/nothing_new` or `settled_on_leave`.
- `ui` does not read `settle_outcome` yet.

## Other leftovers (outside core)

- `tests/ResolvePayoutUITests.gd` lines 35, 141, 278, 299, 755, 980, 984 use `carried_advance` and old preview data as static fixtures. They pass; I did not change them. Step 6.3 rewrites them.
- `scripts/screenshot.gd:124,323` use the same old fixtures.
- `docs/integration-map.md:37` mentions the old carry model.

## Ponytail: skipped

No new abstraction beyond `carry_table`. I did not edit ui/, did not re-record fingerprints, and did not touch the retreat flow beyond removing its payout.

## RUN REQUEST

1. Command (main chat): `rm -rf /tmp/echoes-vnext-tests && /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests fingerprint_seek,reward,combat_baseline,combat_roundtrip,maturity_baseline` and a second run with filter `fingerprint` (covers all `fingerprint_*` and `fingerprint_determinism_*`). Use tool `timeout: 3700000`.
2. Expected duration: several minutes each.
3. Files edited by the run: none.
4. Restore check: `git status --short` shows only the 17 files above.
5. Read back: the `Tests:` line and every failing line. Expected: `combat_baseline`, `combat_roundtrip`, `maturity_baseline`, determinism pass. Fingerprint or `reward` failures must trace to the table above.

## OPEN — questions and assumptions

ASSUMED: `carry_shares` {none 0, some 0.5, all 1.0} is a new config key beside `carry_odds`. | WHY: shares must not be hard-coded (ANSWERS #83) and the brief gave only weights. | WRONG IF: Jeff wants the shares fixed in code or in another shape.
ASSUMED: The Resolve return-home card shows one Ase row (`settle_<outcome>`); Ekwan appears through the existing `ekwan` field, not a second row. | WHY: the earlier card had one Ase row and a separate Ekwan field. | WRONG IF: Jeff wants an Ekwan row in the ledger (design file section 4).
ASSUMED: A retreat card (`settle_outcome` empty, overcome above 0) shows no ledger row until step 6.2. | WHY: D-106 item 2 says a retreat settles nothing; 6.2 owns its card. | WRONG IF: 6.2 expects a row from the builder.
ASSUMED: The intel gate (at least one revealed situation) is dropped. | WHY: design file section 1; a completed objective implies a revealed situation. | WRONG IF: an objective can complete with no revealed situation.
BLOCKED: Does the retreat roll key (`encounter.retreat.<id>.<t>`) repeat after a reload? | CHECKED: not traced in this step; step 6.2 owns the retreat. | NEED: step 6.2 to trace whether `t` is saved.
