# V2-ECONOMY-004 Phase 5.1 — build report (mechanics-developer)

Written in STE. Step 5.1 of the Phase 5 build plan. Decisions used: D-40, D-42, D-47, D-49, D-50, D-51, D-56, D-62 and the R0 review.
Tags: READ = from a file I opened. RAN = a command I ran. PREDICTED = not measured. ASSUMED = my choice, open to correction.
Nothing is committed. Nothing is pushed. Notion is untouched.

## 1. Design

### 1.1 What was removed (D-40, D-49)

| Removed | Where it lived |
|---|---|
| Enemy bonus (5 Ase per enemy) | `RewardCalc.compute`, `EconomyService.reward_encounter_complete`, `data.rewards.enemy_defeated_bonus` |
| Virtue bonus, stage-index bonus, realm-order multiplier | `RealmService.calculate_stage_reward`, `data.rewards.virtue_bonuses`, `stage_index_bonus_per`, `realm_order_multiplier_base`, `realm_order_multiplier_step`, the `virtue_bonus` argument of `settle_stage_complete` and `stage_payout_rows`, the `realm_virtue` row |
| Pace Ase bonus | `PaceService.bonus_ase`, `PaceService.max_bonus_ase`, `data.rewards.pace_bonus_pct`, the `Pace bonus` row, the causes `bonus_earned` and `bonus_missed`, `pace_bonus` and `pace_bonus_awarded` in results and snapshots |
| The enemy row | The `enemies_defeated` cause row in the fight payout |
| Pace inputs that existed only to pay Ase | `stage_base` and `pace_bonus_pct` in `ectx.pace_cfg` and in `combat_state` |

Kept on purpose: `pace_full_ratio`, `pace_zero_ratio`, `PaceService.bonus_fraction`, `pace_state`, `pace_changed_rank`, `echo_survived_bonus` (moves in step 5.2), the defeat consolation (D-13 base), the replay factor, Ekwan, the weights.

### 1.2 One producer, no virtue term

- `EconomyService.stage_payout_rows(base, redo, counts, ekwan_base)` is still the one producer. The stage payer and the preview both call it. It lost the `virtue_bonus` argument and the `realm_virtue` row.
- A stage now pays `roundi(base x redo)` Ase. The stage index, the realm virtue and `run_index` change nothing.
- `reward_encounter_complete(victory, base_reward, echo_bonus, echoes_survived, redo, rank, consolation_eligible, logger, t)` pays: a win = `roundi(echo_bonus x redo)` with one `echoes_alive` row (and a `replay` row when redo is below 1); a defeat = the consolation, as before.
- `RewardCalc.compute(victory, objectives, echoes_survived, total_echoes, round_ended, run_count, reward_cfg, resolution_mode, par_rounds, guide_mode, logger, t, fought_index)`. It lost `enemies_defeated`, `total_enemies`, `reached_enemies`, `pace_stage_base` and `ally_kills`. The result lost `enemy_bonus` and `pace_bonus`. `base_reward` stays (it logs an unknown objective type; no production code reads it).

### 1.3 The rank score (D-49, R0)

Rank is a win-only score. A defeat is `F`.

```
score = (win + home x (Echoes home / Echoes started) + pace x pace_credit) x redo_multiplier
```

- `win`, `home`, `pace` = 0.40, 0.40, 0.20, read from the new config `data.rewards.rank_points` (additive).
- `pace_credit` = the pace fraction for a pace mode. It is 1.0 for a no-pace mode.
- Thresholds are unchanged (`rank_thresholds`; S 0.90 only on run 0). The redo factor sits on the score as before.
- The score reads no Ase amount, no objective weight and no enemy count.
- `pace_changed_rank` = the grade differs from the grade with `pace_credit` 0. It is false in a no-pace mode. The Resolve screen still reads it (no UI edit needed).
- A threshold compare adds 1e-9, because `0.4 + 0.4 + 0.2 x 0.5` sums to 0.8999999999999999 in floating point and would miss S at 0.90. This was a real failure in my first run (RAN, fixed).

### 1.4 pace_state now follows the fraction

`PaceService.pace_state(round, par, full_ratio, zero_ratio)`: `full` when the fraction is 1.0, `none` when it is 0.0, else `partial`. Before, it followed the Ase paid. With Set B weights the old rule could never give `partial` (the maximum pay was 1 Ase or 0). So the HUD colour and the Resolve round-line colour now show `partial` in the band between 1.1 and 1.6 times par. That is the only visible change to the pace state. See the OPEN block.

## 2. Removal audit (full repo)

Search terms: `enemy_defeated_bonus`, `virtue_bonuses`, `virtue_bonus`, `stage_index_bonus_per`, `calculate_stage_reward`, `realm_order_multiplier*`, `realm_virtue`, `pace_bonus_pct`, `max_bonus_ase`, `bonus_ase`, `pace_bonus`, `pace_bonus_awarded`, `bonus_earned`, `bonus_missed`, `Pace bonus`, `enemy_bonus`, `pace_stage_base`, `stage_base` (pace use), `max_possible`.
The phase 5.0 file `phase5-0-confirmations.md` did not exist when I worked. I did my own grep.

### 2.1 `core/`

| File | Hit | Action |
|---|---|---|
| `core/economy/RewardCalc.gd` | enemy bonus, pace bonus, `max_possible`, ceiling, reached and ally terms | Removed. Rank re-based. |
| `core/economy/EconomyService.gd` | enemy row, pace row, `virtue_bonus` argument, `realm_virtue` row, long history comment | Removed. Comment block cut to 7 lines. |
| `core/economy/StageSettlementService.gd` | `virtue_bonus`, `calculate_stage_reward`, `formula_inputs` log | Removed. The `economy.stage.reward` log now carries `stage_index`, `base`, `redo_multiplier`. |
| `core/realms/RealmService.gd` | `calculate_stage_reward`; a comment naming it | Function removed; comment fixed. |
| `core/combat/PaceService.gd` | `bonus_ase`, `max_bonus_ase`, Ase-based `pace_state` | Removed / rewritten. |
| `core/combat/CombatState.gd` | `pace_bonus_pct`, `stage_base` in `combat_state` | Removed. |
| `core/combat/EncounterSetupService.gd` | `pace_bonus_pct`, `stage_base` in `ectx.pace_cfg` | Removed. |
| `core/state/encounter/EncounterContext.gd` | comment naming both | Fixed. |
| `core/realms/ActiveStageService.gd` | comment naming the pace base | Fixed. |
| `core/state/flow/states/venture/EncounterSnapshotBuilder.gd` | `pace_state` call passed `stage_base`, `pace_bonus_pct` | Call shortened. |
| `core/state/flow/states/venture/FlowEncounterState.gd` | `calculate_stage_reward` call, `formula_inputs`, `enemy_bonus`, `pace_bonus`, `total_enemies`, `add_pace` call | Removed. `formula_inputs` key stays on the snapshot with `{}`. |
| `core/state/flow/states/venture/ResolveSnapshotBuilder.gd` | `add_pace(... pace_bonus_awarded ...)` | Argument and key removed. |
| `core/state/flow/PendingResultService.gd` | replay of `pace_bonus_awarded` | Removed. |

`EncounterSnapshotBuilder._build_keeper_intro_final_snapshot` pays a fixed trial reward and has no hit.

### 2.2 `ui/`

| File | Hit | Action |
|---|---|---|
| `ui/screens/venture/ResolveScreen.gd:182` | reads `pace_changed_rank` | Kept. The key still exists and still means "pace moved the grade". No edit. |
| `ui/screens/venture/StageMapScreen.gd:131` | `realm_virtue` | Different key (the realm's virtue for the Thread cord). Not a reward key. No edit. |
| `ui/components/RewardEntryItem.gd:12` | a comment that says "Pace bonus +0 Ase" | Comment only. NOT edited (ui). A UI agent can fix it. |
| `ui/AppRoot.gd` | none from me | The risk-probe agent's registration line is not mine. |

No screen reads `formula_inputs`, `pace_bonus_awarded`, `enemy_bonus`, the `bonus_*` causes or the `realm_virtue` cause. I made no `ui/` edit.

### 2.3 `tests/`

| File | Action |
|---|---|
| `EconomyCharacterizationTests.gd` | Updated for the new values. Added 6 tests (section 3). `virtue_bonus_by_stage_and_run_index` replaced by `removed_bonus_keys_absent`. |
| `EconomyRewardTests.gd` | Updated the `compute` and payer calls. Deleted 4 tests that tested removed things: `pace_rank_ceiling`, `pace_uses_captured_stage_base`, `pace_state_from_ase_paid`, `pace_result_reads_combat_state_stage_base`. Renamed 5: `compute_no_enemy_bonus`, `pace_fraction_curve`, `pace_none_for_no_pace_mode`, `pace_no_breakdown_row`, `pace_ally_kill_sets`. |
| `RealmRewardTests.gd` | Rewritten: 3 tests. The old 5 tested the removed helper. The suite is still registered in `ui/AppRoot.gd` under the same name. |
| `EconomyTests.gd` | One call updated (`settle_stage_complete`). |
| `PaceUITests.gd` | NOT edited. It builds fake snapshots with a `Pace bonus` row and `pace_bonus_awarded`. It tests how the UI shows a 0 Ase row. It still compiles. The game no longer produces such a row. For the UI agent. |
| `FlowFingerprintTests.gd` | NOT edited (hash constants). Comments mention old pace bonus values. |
| `Stage004SeamTests.gd`, `RiskProbeTests.gd` | Compile. Not mine. |

### 2.4 `scripts/`, `data/`, `docs/`

| File | Action |
|---|---|
| `data/balance.json` | Removed 7 keys (`enemy_defeated_bonus`, `pace_bonus_pct`, `_comment_realm005`, `virtue_bonuses`, `stage_index_bonus_per`, `realm_order_multiplier_base`, `realm_order_multiplier_step`). Added `rank_points` and its comment. The file parses (RAN). |
| `scripts/screenshot.gd` | Fixture only: removed `pace_bonus_awarded`, the `Pace bonus` row and the `enemies defeated` row. |
| `CONVENTIONS.md:1187` | The REALM-005 line now says the helper is removed. |
| `docs/resolve-snapshot-block-spec.md` lines 139 and 289 | `add_pace` shape and key list updated. |
| Other `docs/` hits | History files (pace-reward story, V2-INFRA-003 defect register, earlier ECONOMY-004 phase reports, decisions). They record what was true then. NOT edited. |

Not checked: other prose in `CONVENTIONS.md` that describes the old rank ceiling or the `ECONOMY-004` payer (line 1184 area). I searched only for the removed names.

## 3. Tests

### 3.1 Added (all in `econ_char`, all pass, RAN)

| Test | What it proves |
|---|---|
| `removed_bonus_keys_absent` | None of 13 removed names is in `data.rewards` or in any `core/**/*.gd` file. `rank_points` exists. |
| `rank_score_table` | The 6 x 3 table of `phase5-risk-and-rank.md` section 4.2 (1, 2, 3 Echoes started; slow, partial, full pace). A defeat is F. S needs run 0. |
| `death_lowers_rank` | For 2 and 3 started, one death gives a strictly lower grade at every pace. |
| `speed_never_outranks_survival` | For 1 to 3 started: a full-pace win that lost any Echo never ranks above a slow win with everyone home. Speed never lowers a grade. |
| `no_pace_mode_not_capped` | Protect and endure, all home = S for 1 to 3 started. 1 of 2 home = A. No pace state is carried. |
| `speed_pays_no_ase` | A full, a partial and a slow win pay the same 20 Ase and show one row. |

Changed tests also assert: no `realm_virtue` row on the stage card, no `enemies_defeated`, `bonus_earned` or `bonus_missed` row on a win, the stage matrix pays `roundi(base x redo)` at every stage index.

### 3.2 Runs (RAN; `ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase51`, deleted before each run; compile check = 0 errors)

| Filter | `Tests:` line |
|---|---|
| `=econ_char` | `42 total, 42 passed, 0 failed` (after one fix, section 1.3) |
| `=realm_reward,economy,objective` | `30 total, 30 passed, 0 failed` |
| `=venture_char` | `16 total, 16 passed, 0 failed` |
| `=pending_result,save_integrity,unified_resolve` | `43 total, 43 passed, 0 failed` |
| `=foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity` | `39 total, 39 passed, 0 failed` |
| `=retreat,flow_transaction,seam,stage` | `71 total, 71 passed, 0 failed` |

`payout_ui` is not registered in this checkout (the UI suite is on another branch), so I skipped it. I did NOT run `reward` (brief). One attempt to run four fingerprint suites together hit my 115 s alarm and gave no `Tests:` line; I discarded it. Nothing was edited by it.

## 4. PREDICTED moved values (not measured; I changed no constant)

I read `FlowFingerprintTests._final_fingerprint` and `_save_fingerprint`. FINAL holds `data_keys`, `enemies_defeated`, `echoes_survived`, `ase_awarded`, `rank`, `objective_state`. SAVE holds `economy.ase`, `economy.ekwan`, party XP. ROUNDS holds per-round state; the record in the file header says pace changes never moved it ("ROUNDS held").

| Constant group | Prediction | One cause |
|---|---|---|
| `*_FINAL_HASH`, 7 modes (combat, purify_shrine, recover, protect, endure, pursue, guide_spirit) | PREDICTED to move in each mode that has a win with at least 1 enemy killed, a pace term, or a rank change. Most likely all 7. | The fight Ase falls (no 5 per enemy, no pace Ase), and the rank score changes. Pace-mode wins also lose the `pace_bonus_awarded` key from `data_keys`, and `objective_state.pace_state` may read `partial` where it read `none` or `full`. |
| `*_SAVE_HASH`, 7 modes | PREDICTED to move wherever the fight Ase moves (`economy.ase`). | Same fight-Ase cause. Ekwan stays 0. Party XP stays. |
| `*_ROUNDS_HASH` | PREDICTED to hold. | Rounds carry no Ase, rank or pace state. If one moves, the cause is `pace_state` in a round snapshot, which I did not confirm. |
| `fingerprint_determinism_*` | PREDICTED to pass (they compare a run with a run). | No random draw changed. |
| `reward` suite | PREDICTED to pass, but UNVERIFIED. I edited about 20 of its tests without running them. | The suite drives real fights and reads pace, rank and rows. |
| `fingerprint_seek`, `combat_baseline`, `maturity_baseline`, `combat_roundtrip` | PREDICTED unchanged. I did not confirm that they do not read Ase, rank or `pace_state`. | No match found for those names in a grep of the files I read. |

One cause per re-record, to write in the file header: "D-40 and D-49: the fight pays no enemy or pace Ase and the rank is a score of win, home and pace."

## 5. RUN REQUEST for the main chat

Needed because the `reward` suite and the fingerprint suites are over 2 minutes and I did not run them. Run each group separately (the `reward` run holds the process for a long time).

Files edited by every run: none. Restore check: `git status --short` must show the same file list as before the run, and `git diff --stat` must be unchanged. Delete the save directory before each run.

| Group | Command | Expected time (shard-map comments) |
|---|---|---|
| A `reward` (own group) | `rm -rf /tmp/echoes-econ004-phase51; ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase51 /usr/bin/perl -e 'alarm shift; exec @ARGV' 4200 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =reward` with `timeout: 4300000` | about 1054 s (one test is 991 s) |
| B fingerprints | `... alarm 1200 ... -- tests =fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue` with `timeout: 1300000` | not measured; shard map gives the sum of these 6 as about 100 s to 200 s each group |
| C guide spirit | `... alarm 1200 ... -- tests =fingerprint_guide_spirit` | about 279 s |
| D determinism | `... alarm 3200 ... -- tests =fingerprint_determinism_combat,fingerprint_determinism_purify_shrine,fingerprint_determinism_recover,fingerprint_determinism_protect,fingerprint_determinism_endure,fingerprint_determinism_pursue,fingerprint_determinism_guide_spirit` with `timeout: 3300000` | about 775 s for guide_spirit plus about 200 s for pursue plus the rest |
| E optional | `... -- tests =fingerprint_seek,combat_baseline` | 344 s + 490 s. NOT needed unless group B shows an unexpected failure. |

Read back from each run: the `Tests:` line and every `❌` line, raw. For groups B and C, copy the `FP_DEBUG ... final=` and `... save=` lines of each failing mode: they show `ase_awarded`, `rank`, `data_keys` and `objective_state`. Compare against section 4. A moved constant in a field not named there is a finding. Do not re-record until the attribution matches.

Is the `reward` suite needed? Yes. I rewrote about 20 of its tests and it is the only suite that drives real GUIDE_SPIRIT, PURSUE and ENDURE fights through the new result path.

## 6. Diff summary

- `core/`: 14 files, net about -120 lines. `data/balance.json`: 7 keys out, 1 object in.
- `tests/`: 4 files edited, 1 rewritten (`RealmRewardTests`).
- `scripts/screenshot.gd`, `CONVENTIONS.md`, `docs/resolve-snapshot-block-spec.md`: one-line fixes.
- No `ui/` file edited by me.

## 7. Found but not done (scope control)

1. Dead code now: `PaceService.record_reached_enemies`, `record_kill`, `rank_reached_count`, `tracks_reached_enemies`, `REACHED_ENEMY_MODES`, and `combat_state.reached_enemy_ids` and `ally_killed_enemy_ids`. The rank no longer reads them. The `reward` suite still tests them. Removing them is a separate story.
2. `RewardCalc.compute` still returns `base_reward` and `MODE_COMPLETED_PLUS_FOUGHT` has no other production user. Harmless.
3. `ui/components/RewardEntryItem.gd:12` comment and `tests/PaceUITests.gd` still describe a `Pace bonus` row.
4. Stale prose in `CONVENTIONS.md` about the old rank formula (not searched).
5. Party size 4 and above: see OPEN.

## OPEN — questions and assumptions

ASSUMED: A no-pace mode takes the full 0.20 pace points (the brief's choice), not the "divide by 0.80" of `phase5-risk-and-rank.md` option B | WHY: the brief says so, and it keeps those modes out of the cap | WRONG IF: Jeff wants the divide-by-0.80 rule. The two rules differ: 1 of 2 home gives 0.80 (A) here and 0.75 (A) there. All home is S in both. Only the `rank_points` read in `RewardCalc.rank_score` would change.

ASSUMED: A defeat ranks `F` | WHY: the brief says "F for a defeat". The old code ranked a defeat from the consolation and could give C or D | WRONG IF: Jeff wants a grade for a lost fight. The Thread tier for `F` is "broken" (`data.threads.segment_quality_by_grade`).

ASSUMED: Home share is 1.0 when 0 Echoes started | WHY: a win with no Echo cannot happen; this only avoids a divide by zero | WRONG IF: some fight can start with no roster Echo and still win.

ASSUMED: `pace_state` follows the fraction (full at 1.0, none at 0.0, else partial) | WHY: the Ase it followed is gone. The brief says keep the HUD state | WRONG IF: Jeff wants the HUD to stay exactly as before. Before, `partial` was unreachable with Set B weights, so the HUD showed only `full` or `none` (READ from `PaceService` before my edit and the weights in `balance.json`; COMPUTED, not observed in play). Now `partial` shows between 1.1 and 1.6 times par. The UI colour for `partial` already exists. Jeff should confirm he wants this.

ASSUMED: `formula_inputs` stays on the Resolve snapshot as `{}` | WHY: no screen reads it, and the shape rule keeps the key | WRONG IF: a screen outside `ui/screens` reads fields from it. I found none.

FINDING (for Jeff): the "speed never outranks survival" relation holds only for 1 to 3 Echoes started. At 4 Echoes, one lost and full pace = 0.40 + 0.30 + 0.20 = 0.90 = S, and an all-home slow win = 0.80 = A. So a fast win with a death can outrank a slow win with none. The general formula is 1 - 0.4/N for one lost at full pace; it reaches 0.90 at N = 4. The test pins the relation for 1 to 3 only and says so. Principle 1 of `phase5-risk-and-rank.md` (a death never pays more) is not met by 0.40/0.40/0.20 for parties of 4 or more. Options for Jeff: raise the `home` points, add a rule that pace counts only when nobody died, or accept it. I did not choose. D-57 plans villages of 7 to 12; I did not check the party size limit in code.

BLOCKED: none that stopped the work. `phase5-0-confirmations.md` did not exist; I did my own audit (section 2). | CHECKED: `docs/stories/v2-economy-004/` | NEED: the main chat can compare that file with section 2 when it arrives.

NOT VERIFIED: the `reward` suite and all fingerprint suites (section 5). The in-game look of the `partial` pace colour. The prose of `CONVENTIONS.md` outside line 1187.

## Skills used

- `ponytail` (full): smallest change per task; left dead tracking code alone and listed it (section 7); did not add a flag or an alias.
- `godot-echoes-dev`: not loaded separately; `AGENTS.md` and the scoped contracts were enough for the choke-point and snapshot rules.

Skipped, with reason (ponytail): no new service or helper class (the rank score is one static function beside `compute`); no UI edits (the key `pace_changed_rank` kept its meaning); no removal of the reached-enemy tracking (not in the brief, tested by `reward`); no re-record of any hash constant (brief); no edit of history docs.
