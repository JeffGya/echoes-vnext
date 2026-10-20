# V2-ECONOMY-004 Part A — Phase 1 characterization

Written in STE. Tags: MEASURED = a test or run in this phase produced the value. READ-FROM-CODE = taken from source, not run.
No file under `core/` or `data/` changed. Test suite: `tests/EconomyCharacterizationTests.gd`, suite name `econ_char` (14 tests, 12 s).

## 1. What the code pays today

### 1.1 Reward base (MEASURED: `econ_char/base_reward_per_type`, `unweighted_types_add_zero`, `boss_stub_adds_sixty`)

`data.rewards.objective_weights` has three keys: `combat` 30, `shrine` 40, `boss` 60 (`data/balance.json`).
`RewardCalc.base_reward` (`core/economy/RewardCalc.gd:26`) sums the weight of every objective. A missing key counts as 0.
The generator ends every stage with a boss stub (`RealmGenerator.gd:148-152`). So every stage base includes 60.

| Pre-boss objective type | Own weight | Stage base (type + boss stub) |
|---|---|---|
| combat | 30 | 90 |
| shrine | 40 | 100 |
| recover | 0 | 60 |
| protect | 0 | 60 |
| endure | 0 | 60 |
| pursue | 0 | 60 |
| guide_spirit | 0 | 60 |
| boss (the stub alone) | 60 | 60 |

KNOWN DEFECT (Phase 3 will change this): the five types `recover`, `protect`, `endure`, `pursue`, `guide_spirit` add weight 0.
KNOWN DEFECT (Phase 3 will change this): the boss stub adds 60 to every stage base. The test shows `with boss − without boss = 60` for all seven pre-boss types.

### 1.2 Redo multiplier and virtue bonus

Redo multiplier (MEASURED: `redo_multiplier_by_run_count`): realm `run_count` 0 gives 1.0. `run_count` 1 gives 0.9. (`redo_penalty_per_run` 0.10, floor 0.50.)
Redo scales the base only. It never scales the virtue bonus (`EconomyService.gd:221-222`, READ-FROM-CODE).

Virtue bonus = `roundi((virtue_base + 5 × stage_index) × (1.0 + 0.5 × run_index))`. `virtue_base`: courage 10, wisdom 15, faith 20.
MEASURED: `virtue_bonus_by_stage_and_run_index`.

| Realm (virtue) | run_index | Stage 0 | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|---|---|
| realm.01 (courage) | 0 | 10 | 15 | 20 | 25 |
| realm.01 (courage) | 1 | 15 | 23 | 30 | 38 |
| realm.02 (wisdom) | 0 | 15 | 20 | 25 | 30 |
| realm.02 (wisdom) | 1 | 23 | 30 | 38 | 45 |

`run_index` counts started realms. It is 0 for the first realm a player starts. It is not the same value as `run_count`.

### 1.3 Stage payer (MEASURED: `econ_char/stage_payer_matrix`)

Path: `StageSettlementService.settle()` → `EconomyService.settle_stage_complete()`. The test boots a real `FlowRuntime`, replaces the objectives of one real `realm.01` stage with the production shape, and calls `settle()`.
Formula: Ase = `roundi(base × redo) + virtue_bonus`. Ekwan = `roundi(Ase × 0.12)`.
The test covers all 8 types in `ObjectiveModel.VALID_TYPES`, stages 0 to 3, `run_count` 0 and 1 (64 cells). Cells are listed by stage base. Types with the same base pay the same.
Each cell is Ase / Ekwan. Realm is `realm.01`, `run_index` 0.

| Stage base | Types | run_count | Stage 0 | Stage 1 | Stage 2 | Stage 3 |
|---|---|---|---|---|---|---|
| 60 | recover, protect, endure, pursue, guide_spirit, boss | 0 | 70 / 8 | 75 / 9 | 80 / 10 | 85 / 10 |
| 60 | same | 1 | 64 / 8 | 69 / 8 | 74 / 9 | 79 / 9 |
| 90 | combat | 0 | 100 / 12 | 105 / 13 | 110 / 13 | 115 / 14 |
| 90 | combat | 1 | 91 / 11 | 96 / 12 | 101 / 12 | 106 / 13 |
| 100 | shrine | 0 | 110 / 13 | 115 / 14 | 120 / 14 | 125 / 15 |
| 100 | shrine | 1 | 100 / 12 | 105 / 13 | 110 / 13 | 115 / 14 |

The test also checks the `Base objectives` and `Realm virtue` rows of the payout breakdown, and the saved balances.

KNOWN DEFECT (Phase 2 will change this) — `shrine` pays the ordinary Ekwan factor (MEASURED: `stage_payer_shrine_ordinary_ekwan`). A shrine stage at stage 0, `run_count` 0 pays 110 Ase and 13 Ekwan. That is `roundi(110 × 0.12)`. The factor 1.5 (`ekwan_shrine_multiplier`) never applies.

### 1.4 Encounter payer (MEASURED: `encounter_payer_victory`, `encounter_payer_defeat`, `encounter_payer_shrine_ordinary_ekwan`)

Path: `RewardCalc.compute()` → `EconomyService.reward_encounter_complete()`.
Fixture fight: 3 of 3 enemies defeated, 2 of 2 Echoes survive, no pace mode. Enemy bonus 5 each (15). Echo bonus 10 each (20).

Victory pays `roundi((15 + 20) × redo)`. The stage base, the stage index and the objective type do not enter a victory payout.

| run_count | Ase | Ekwan |
|---|---|---|
| 0 | 35 | 4 |
| 1 | 32 | 4 |

Defeat pays the one consolation `roundi(base × 0.25 × redo)`. The base here is the stage base.

| Stage base | run_count 0 (Ase / Ekwan) | run_count 1 (Ase / Ekwan) |
|---|---|---|
| 60 | 15 / 2 | 14 / 2 |
| 90 | 23 / 3 | 20 / 2 |
| 100 | 25 / 3 | 23 / 3 |

KNOWN DEFECT (Phase 2 will change this): the encounter factor for a shrine stage is 0.12, not 0.18.
The test mirrors the factor code of `FlowEncounterState.gd:208-215` in a helper. Reason: `build_final_snapshot()` needs a finished combat. The test `ekwan_sites_read_obj_type` reads the source of both sites and fails if the `"obj_type"` read moves. It does not run the production encounter payer.

### 1.5 The key defect (D66 / D83)

MEASURED: `objective_model_writes_type_not_obj_type`. `ObjectiveModel.make()` writes `type`. It never writes `obj_type`.
READ-FROM-CODE: both Ekwan sites read `obj_type` with default `"combat"`: `StageSettlementService.gd:147` and `FlowEncounterState.gd:211`.
MEASURED: `ekwan_sites_read_obj_type` pins both source lines.

### 1.6 Example: a real first `realm.01` run (MEASURED fixture, READ-FROM-CODE formula)

Fixture campaign (root seed 12346, harness `_setup_stage_env`) generates `realm.01` with 4 stages, `run_index` 0, `run_count` 0.
Stage objectives: stage 0 `guide_spirit`, stage 1 `protect`, stage 2 `combat`, stage 3 `combat` (each plus the boss stub).

| Stage | Base | Stage Ase / Ekwan | Fight (victory, fixture) Ase / Ekwan |
|---|---|---|---|
| 0 | 60 | 70 / 8 | 35 / 4 |
| 1 | 60 | 75 / 9 | 35 / 4 |
| 2 | 90 | 110 / 13 | 35 / 4 |
| 3 | 90 | 115 / 14 | 35 / 4 |
| Run total, stage payer only | | 370 / 44 | |
| Run total, with one fixture victory per stage | | 510 / 60 | |

The fight column is an example. The real bonus depends on the real fight. The totals come from adding table cells.

## 2. Objective draw pool of `realm.01` and `realm.02`

MEASURED: `econ_char/objective_pool_frequency`. Method: `RealmGenerator.generate()` with the realm's `objective_pool`, stage count, objective counts and seed namespace from `data/realms.json`. Root seeds 1 to N. `run_count` 0.
The test `fast_generation_matches_realm_service` shows the objective types and seeds equal the output of `RealmService.get_or_create` (the production path) for 3 seeds per realm. The fast path uses small explore maps. Reason: the maps cost most of the run time and use separate RNG paths.
Run the 200-seed table with `ECONOMY_CHAR_SEEDS=200` (about 65 s for the suite). The default is 25 seeds.

Both realms use the pool `combat, shrine, recover, protect, endure, pursue, guide_spirit`. It is the same as `foundation_objective_pool`. The pool has all 7 types. The per-realm override does not remove any type.
So "5 of 7 types pay 0" is true for the pool: 5 of the 7 drawable types have no weight.

Pre-boss objectives per stage: `realm.01` always 1 (700 of 700 stages). `realm.02` 1 in 576 stages and 2 in 611 stages.

200 seeds per realm (MEASURED):

| Item | realm.01 | realm.02 |
|---|---|---|
| Stages generated | 700 | 1187 |
| Stages with non-boss weight 0 | 502 (71.7%) | 719 (60.6%) |
| Mean non-boss weight per stage | 9.9 | 15.3 |
| combat | 98 | 244 |
| shrine | 100 | 271 |
| recover | 106 | 259 |
| protect | 88 | 241 |
| endure | 104 | 244 |
| pursue | 120 | 256 |
| guide_spirit | 84 | 283 |
| boss (one per stage) | 700 | 1187 |

Answer to "how many generated stages have a non-boss base of 0": 502 of 700 in `realm.01`, and 719 of 1187 in `realm.02`. Each of these still pays a base of 60 (boss stub) today.
`realm.02` for stages 0 to 3 only: 800 stages, 477 with non-boss weight 0 (MEASURED in an earlier probe run in this phase; the suite does not freeze this subset).
The 25-seed default table is in the test (`_POOL`).

## 3. Ase and Ekwan sinks

All spend goes through `EconomyService.spend_ase` / `spend_ekwan`. Both deny the spend when funds are too low (READ-FROM-CODE: `EconomyService.gd:64-79`). Prices are READ-FROM-CODE from `data/balance.json` unless noted.

### 3.1 Ase sinks

| Site | Spend | Price |
|---|---|---|
| `SanctumController.gd:188` | Summon, per Echo, by grade | uncalled 60, called 150, chosen 400 (`data.summoning.ase_cost_per_summon_by_grade`; flat fallback 60) |
| `FlowRuntime.gd:1173` | Retreat before round 1 (spent whether the retreat works or not) | 30 (`data.combat.retreat_ase_cost`, code default 30) |
| `ProgressionController.gd:444` | Unlock a skill | 40 for each of the 14 skill definitions (`data.skills.definitions.*.unlock_conditions.ase_cost`) |
| `VowService.gd:342` | Break a vow | `tikoro_nko_agyina` tier 1/2/3/4: 60/120/250/500. `praye_wokabomu` tier 1/2: 60/120. `obi_nnim_kyere` tier 1/2: 60/100 (`data.vows.definitions.*.breaking_costs`) |
| `InstitutionService.gd:136` | Assign an Echo to an institution | 5 (`hearth`, `training_grounds`; `assign_ase_cost`) |
| `EconomySettlementController.gd:112` | Debug command `ase spend` | Debug only. Not a game sink. |

### 3.2 Ekwan sinks

| Site | Spend | Price |
|---|---|---|
| `InstitutionService.gd:103` | Establish an institution | `hearth` 10, `training_grounds` 15 (`establish_ekwan_cost`) |
| `InstitutionService.gd:158` | Remove an Echo from an institution | 3 (`unassign_ekwan_cost`) |
| `VowService.gd:344` | Break a vow | `tikoro_nko_agyina` tier 2/3/4: 20/50/100. `praye_wokabomu` tier 2: 20. `obi_nnim_kyere` tier 2: 15. Tier 1 costs no Ekwan. |
| `ui/AppRoot.gd:1311` | Debug command `ekwan spend` | Debug only. Not a game sink. |

Summary: the most expensive repeatable Ase item is a chosen summon (400). A full `realm.01` run pays about 370 Ase from the stage payer (section 1.6). Ekwan has only one-time or rare sinks. Total Ekwan to establish both institutions is 25.

### 3.3 Ase sources outside stage rewards (READ-FROM-CODE)

| Source | Site | Value |
|---|---|---|
| Online accrual | `EconomySettlementService.gd:131-151`, `data.economy` | `ase_online_per_min_base` 0.3 per minute (18 per hour) × multiplier (default 1.0). One settle counts at most 3600 s (`_max_online_settle_delta_seconds`), so at most 18 Ase per settle. Needs the Ase flame awakened. Bank timer interval 240 s (`sanctum_bank_interval_seconds`): 1.2 Ase per tick. |
| Awakening boost | `KeeperIntroService.gd:214-240` | 5 Ase per 240 s tick for 600 s (`data.keeper_intro`): 12 Ase in total. |
| Offline accrual | `OfflineAccrualService.gd:132-184` | rate 0.005 Ase per second × `offline_start_factor` 0.06, with a linear taper. Base cap 151200 s (42 h), clamped 108000 to 172800 s. Multiplier 0.8 plus continuity and stability terms, clamped 0.05 to 1.2. At the cap: about 18 Ase at multiplier 0.8, at most about 31 Ase (cap 172800 s, multiplier 1.2). |
| First trial | `KeeperIntroService.gd:146` | 40 Ase once (`first_trial_ase_reward`). |
| Awakening grant | `data.economy.awakening_ase_grant` 40 | Not paid. `OnboardingController.gd` (comment near line 345) says the grant is unreachable. `SanctumSnapshotBuilder.gd:408` reads the value for a display field only. |
| Retreat partial | `FlowRuntime.gd:1201-1204` | `roundi(stage base × 0.12)` when at least one situation is revealed (`partial_intel_reward_factor`). Base 60: 7. Base 90: 11. |
| Return-home partial | `VentureController.gd:381` | Same formula, times the Directive `intel_retention_bonus` (1.5 for Scout) when it applies. |
| Claimant contact, good outcome | `ContactController.gd:618` | 20 Ase. |
| Situation "money" | `SituationEngagementService.gd:301` | 8 to 20 Ase (`situation_resolution.money.ase_min/ase_max`). |

Both partial payouts read the stage base. The stage base includes the boss stub (60), so the boss stub also raises these payouts today.

### 3.4 Ekwan sources outside stage rewards

None in game code. `add_ekwan` has three call sites: `EconomyService.gd:191` (encounter payer), `EconomyService.gd:237` (stage payer) and the debug command (`ui/AppRoot.gd:1308`). Ekwan comes only from the two payers, as a share of the Ase paid.

## 4. Debug-console commands that reach a payout (READ-FROM-CODE: `ui/AppRoot.gd:265-370`, `1235-1330`, `1645-1694`; `DebugController.gd`)

No command grants a stage clear. No command calls `StageSettlementService.settle` or dispatches `flow.complete_stage`.

| Command | Effect |
|---|---|
| `ase show`, `ase add <amount> [reason]`, `ase spend <amount> [reason]` | Set or read the Ase balance. Does not use a payer. |
| `ekwan show`, `ekwan add <amount> [reason]`, `ekwan spend <amount> [reason]` | Same for Ekwan. |
| `realm select <realm.01\|realm.02>`, `realm show` | Pick a realm without playing the earlier one. |
| `combat_objective <combat\|purify_shrine\|recover\|protect\|endure\|pursue\|guide_spirit\|show>` | Forces the mode of the next fight. A fight that ends reaches the ENCOUNTER payer. |
| `spawn_ally`, `force_claimant_combat`, `force_charge_pressure`, `force_recruit`, `guide`, `rankup`, `emotion`, `stopshort`, `institution`, `vow unlock`, `seed`, `echo`, `summon`, `hero_info` | Do not pay a stage reward. |

`debug.*` actions in `DebugController.gd`: `debug.seed.*`, `debug.echo.gen_test`, `debug.ally.spawn`, `debug.claimant.force_combat`, `debug.charge_pressure.set`, `debug.guidance.set`, `debug.emotion.set`, `debug.stop_short.set`, `debug.progression.force_rank_up`. None pays Ase or Ekwan.

Play steps for Jeff (replaces a debug command for the STAGE payer):
1. Start a new campaign. Finish the opening. Run `realm select realm.01`, `realm show`.
2. Enter a stage. Win its fights. Press the next-stage button on the Resolve screen. That dispatches `flow.complete_stage`, which calls the stage payer once.
3. Read Ase and Ekwan on the Resolve card. Compare with section 1.3 and 1.6. Use `ase show` and `ekwan show` before and after.
4. To see a shrine stage, use `combat_objective purify_shrine` for the fight. Note: the stage payer reads the stage's real first objective, not this toggle.

## 5. `FlowEncounterState.gd:346` (`_combat_surface`)

READ-FROM-CODE. Line 346: `var _combat_surface := _obj_type if not _obj_type.is_empty() else "combat"`.
`_obj_type` is `"combat"` today for every stage (section 1.5). So `_combat_surface` is always `"combat"` today.

What uses it:
- One use: `FlowEncounterState.gd:425`, `ResolveSnapshotBuilder.add_banner(_data, _combat_surface, _summary_line)`. It writes `data["surface"]` on the combat Resolve snapshot.
- Readers of `data["surface"]` on this snapshot:
  - `PendingResultService.gd:438-439` replays a stored `surface` into a restored Resolve snapshot.
  - `tests/FlowFingerprintTests.gd:367` puts `surface` in the fingerprint payload. This payload feeds the FINAL hash of the seven fingerprint modes and the Seek copies.
  - `ui/screens/venture/ResolveScreen.gd:274` reads `surface`, but only in `_render_situation_result`. A combat Resolve does not take that path (banner text is `VICTORY` or `DEFEAT`, line 158). So no UI text changes (READ-FROM-CODE; not run in the UI).

What changes when `_obj_type` holds the real type:
1. `surface` on the combat Resolve snapshot becomes the type of the stage's FIRST objective (`stage_objectives[0]`), for example `guide_spirit`. It is not the type of the objective being fought.
2. The fingerprint harness uses `realm.01` `stage.0` (`FlowFingerprintTests.gd:148`) with root seed 12346. In the harness of this phase (same seed) the first objective of stage 0 is `guide_spirit`. So the `surface` field of all seven fingerprint modes probably moves from `combat` to `guide_spirit`, and the FINAL hashes move, in `FlowFingerprintTests` and `FlowFingerprintSeekTests`. I did not run the fingerprint suites. The Phase 2 agent must confirm with the `FP_DEBUG` payload and record one cause for those moved constants.
3. The Ekwan factor at the same line group changes only for `shrine` first objectives. It does not change `surface`.
4. A restored Resolve snapshot from an old save keeps its stored `surface` (`combat`). The stored value is a string, so nothing breaks.

## 6. Findings outside this story (not fixed)

- Comment disagrees with code: `VowService.gd` (line 340) says "spend what we can — clamp to zero if broke". `EconomyService.spend_ase` denies the whole spend when funds are too low (`EconomyService.gd:73-79`). A broke player pays nothing for a vow break. Same for Ekwan. Owner: vow work, not Part A.
- `data.economy.awakening_ase_grant` is read for display (`SanctumSnapshotBuilder.gd:408`) and never paid (V2-ECONOMY-002 per the comment in `OnboardingController.gd`).
- The partial payouts (retreat, return home) use the stage base. Phase 3 changes the stage base, so these payouts will move too. Phase 3 and 5 must list them in the moved values.

## 7. How to run

```bash
rm -rf /tmp/echoes-econ004-phase1 && ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase1 /usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =econ_char
```
Last result in this phase: `Tests: 14 total, 14 passed, 0 failed` (default 25 seeds, 12 s) and the same with `ECONOMY_CHAR_SEEDS=200` (65 s).
