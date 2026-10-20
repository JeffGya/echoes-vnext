# V2-ECONOMY-004 Part A — Phase 3 proposal: Ase weights per objective type

Written in STE. Every number marked PROPOSAL is a proposal. Jeff decides each one. No value is in `data/balance.json`.
Tags: READ = taken from code or data. COMPUTED = my arithmetic (formulas below). PREDICTED = not run.

## 1. Summary for Jeff

- A weight is the Ase value of one objective type. A stage base is the SUM of the weights of all its objectives (`RewardCalc.base_reward`, `RewardCalc.gd:26`).
- The stage pays `roundi(base x redo) + virtue_bonus` (`EconomyService.settle_stage_complete`, READ).
- After Phase 3 the boss stub pays 0. So a `realm.01` stage base is the weight of its one pre-boss objective. Today it is that weight plus 60.
- The weights must do two jobs: (1) put each type in a fair order of effort; (2) start low (D-04).
- The weights cannot fix "too much Ase" alone. Three other payers stay as they are (see section 4):
  - The virtue bonus: 10 to 25 Ase per `realm.01` stage.
  - The fight bonus: 5 per enemy, 10 per surviving Echo. The Phase 1 fixture fight pays 35 per fight.
  - Both are larger than the lowest weights proposed here.
- Jeff must set these targets (I do not): stages to afford a first summon (60), a called summon (150), a skill unlock (40); and the total Ase of a full `realm.01` run.

## 2. Type order and optional types

The order is my judgement from `ObjectiveModel.TYPE_DESCRIPTIONS` (READ). I add no mechanic.
Fact from the fingerprint harness comment: the modes end on the same win condition (all enemies defeated) unless the mode ends first. So every type includes a fight. Types differ by the extra task.

| Rank (low to high effort) | Type | Description (READ) | Why this place |
|---|---|---|---|
| 1 | `pursue` (optional) | "Track and intercept before the window closes." | Optional. See below. |
| 2 | `combat` | "Defeat all enemies to proceed." | Only the fight. Baseline. |
| 3 | `recover` | "Find and retrieve what was taken." | Fight plus a find. |
| 3 | `protect` | "Keep the presence here safe." | Fight plus a guard duty (`duration_turns`). |
| 4 | `endure` | "Hold your ground through the pressure." | Fight plus a hold for rounds (`hold_rounds`). The player cannot end it early. |
| 5 | `shrine` | "Purify the corrupted shrine." | Fight plus a shrine to purify. Today it already weighs more than `combat` (40 against 30). I keep that order. |
| 6 | `guide_spirit` | "Find the spirit and see it to safety." | Most steps: find, then escort. |

`recover` and `protect` tie: the descriptions show no difference in effort. Jeff may split them.

Optional types (READ, `data/balance.json` `data.stages.objective_types`): `pursue` and `guide_spirit` have `required: false`.
FINDING (READ): the generator marks only `pursue` optional (`RealmGenerator.gd:145`: `is_required = obj_type != TYPE_PURSUE`). It writes `required: true` on a `guide_spirit` objective. The stage reads the objective flag, not the config flag (`FlowStageExploreState.gd:302`). So in play only `pursue` is optional today. `guide_spirit` is required today. The config and the generator disagree. I do not fix it.
FINDING (READ): the stage payer sums ALL objectives of the stage. It does not check `completed`. A skipped optional `pursue` still pays its weight today, once the stage ends.

My advice on optional weight: weigh `pursue` LESS than the required types. Reason: it pays even when the player skips it. A high weight pays for no effort. Weighing it more would reward risk, but the code does not pay by completion, so that logic does not hold now. If Jeff wants "pay only completed objectives", that is a new rule (see OPEN).

## 3. Candidate sets

All values PROPOSAL. `boss` pays 0 in every set (section 5).

| Type | Today | Set A: much lower | Set B: lower | Set C: moderately lower |
|---|---|---|---|---|
| `pursue` | 0 | 4 | 8 | 12 |
| `combat` | 30 | 5 | 10 | 15 |
| `recover` | 0 | 6 | 12 | 18 |
| `protect` | 0 | 6 | 12 | 18 |
| `endure` | 0 | 7 | 14 | 20 |
| `shrine` | 40 | 8 | 15 | 20 |
| `guide_spirit` | 0 | 8 | 16 | 24 |

One-line reason per type:

| Type | Reason (all sets) |
|---|---|
| `combat` | Baseline: the fight alone. The anchor for the other types. |
| `pursue` | About 0.8 of `combat` in B and C, below it in A. Optional, and paid even when skipped. |
| `recover` / `protect` | A little above `combat`: one extra task each. |
| `endure` | Above `recover`: a fixed hold the player must sit through. |
| `shrine` | Keeps its present place above `combat`. About 1.5 of `combat`. |
| `guide_spirit` | Highest: two linked tasks, find then escort. |

Shape note: B keeps the ratios 0.8 / 1.0 / 1.2 / 1.2 / 1.4 / 1.5 / 1.6. Set A and C are near the same shape with rounding. Jeff can scale the whole shape later in Phase 5 and keep the order.

### Formulas used (READ from code)

- `realm.01`, `run_index` 0, `run_count` 0: redo = 1.0. Virtue bonus = 10, 15, 20, 25 for stages 0 to 3 (Phase 1, section 1.2; formula `RealmService.calculate_stage_reward`).
- Stage Ase = weight + virtue bonus (boss 0). Stage Ekwan is not computed here (Phase 4).
- The virtue bonus is as it stands today. It is a separate lever for Phase 5. This proposal does NOT change it.

### Stage Ase by type, `realm.01` stages 0 to 3, `run_count` 0 (COMPUTED)

Cell = weight + virtue (10 / 15 / 20 / 25).

| Type | Today (with boss 60) | Set A | Set B | Set C |
|---|---|---|---|---|
| `pursue` | 70 / 75 / 80 / 85 | 14 / 19 / 24 / 29 | 18 / 23 / 28 / 33 | 22 / 27 / 32 / 37 |
| `combat` | 100 / 105 / 110 / 115 | 15 / 20 / 25 / 30 | 20 / 25 / 30 / 35 | 25 / 30 / 35 / 40 |
| `recover` | 70 / 75 / 80 / 85 | 16 / 21 / 26 / 31 | 22 / 27 / 32 / 37 | 28 / 33 / 38 / 43 |
| `protect` | 70 / 75 / 80 / 85 | 16 / 21 / 26 / 31 | 22 / 27 / 32 / 37 | 28 / 33 / 38 / 43 |
| `endure` | 70 / 75 / 80 / 85 | 17 / 22 / 27 / 32 | 24 / 29 / 34 / 39 | 30 / 35 / 40 / 45 |
| `shrine` | 110 / 115 / 120 / 125 | 18 / 23 / 28 / 33 | 25 / 30 / 35 / 40 | 30 / 35 / 40 / 45 |
| `guide_spirit` | 70 / 75 / 80 / 85 | 18 / 23 / 28 / 33 | 26 / 31 / 36 / 41 | 34 / 39 / 44 / 49 |

Example arithmetic: Set B, `guide_spirit`, stage 2 = 16 + 20 = 36. Set A, `combat`, stage 0 = 5 + 10 = 15.
`pursue` and `guide_spirit` in a stage of `realm.02` with 2 pre-boss objectives: the base is the sum of both weights. I did not tabulate `realm.02`.

### Phase 1 fixture run (COMPUTED)

Fixture: stage 0 `guide_spirit`, stage 1 `protect`, stage 2 `combat`, stage 3 `combat`. Stage payer only.

| | Stage 0 | Stage 1 | Stage 2 | Stage 3 | Run total | Change against today |
|---|---|---|---|---|---|---|
| Today | 70 | 75 | 110 | 115 | 370 | |
| Set A | 8+10 = 18 | 6+15 = 21 | 5+20 = 25 | 5+25 = 30 | 94 | -75% |
| Set B | 16+10 = 26 | 12+15 = 27 | 10+20 = 30 | 10+25 = 35 | 118 | -68% |
| Set C | 24+10 = 34 | 18+15 = 33 | 15+20 = 35 | 15+25 = 40 | 142 | -62% |

Virtue bonus total in the run: 10+15+20+25 = 70. Its share of the stage-payer total: today 19%, A 74%, B 59%, C 49%.
Second run of the same realm (`run_count` 1, redo 0.9, COMPUTED): A 92, B 113, C 136, today 340.

### Stages needed to afford (COMPUTED)

Method: add the fixture stage payouts in order (stage 0, 1, 2, 3, then again), until the sum reaches the price. Redo and fight bonus are ignored in the first block. Other Ase (online accrual, 40 first-trial grant, spends) is ignored. Prices READ from Phase 1, section 3.1.

| Price | Today | Set A | Set B | Set C |
|---|---|---|---|---|
| Skill unlock, 40 | 1 | 3 (sum 18, 39, 64) | 2 (26, 53) | 2 (34, 67) |
| First summon, 60 | 1 | 3 (sum 64) | 3 (26, 53, 83) | 2 (34, 67) |
| Called summon, 150 | 3 | 7 | 6 | 5 |
| Chosen summon, 400 | | not computed | not computed | not computed |

Same method with one Phase 1 fixture fight added to every stage (+35: 3 enemies x 5, 2 Echoes x 10, redo 1.0). This is an example, not a forecast.

| Price | Today | Set A | Set B | Set C |
|---|---|---|---|---|
| Skill unlock, 40 | 1 | 1 | 1 | 1 |
| First summon, 60 | 1 | 2 | 1 | 1 |
| Called summon, 150 | 2 | 3 | 3 | 3 |

Reading: the fight bonus makes the three sets look almost the same. A weight set alone does not set the pace of the early game. The fight bonus and the virtue bonus matter as much.
GDD check (READ, §20.12): the opening should grant almost enough Ase to summon, and one proper stage reward should finish the job. The opening grants 40 (first trial) + 12 (awakening boost) = 52 (Phase 1, section 3.3). The first summon costs 60. The gap is 8. Every set pays at least 14 at stage 0. So the GDD line holds for A, B and C.
These numbers need Jeff's target: "stages to afford the first summon", "stages to afford a called summon", "Ase of a full first run". I do not choose them.

### What a low weight does to the virtue bonus

With low weights the virtue bonus is the main part of a stage payout (49% to 74% in the fixture run). Consequences:

1. Stage payout becomes almost the same for every objective type. Stage 0: `combat` 15 and `guide_spirit` 18 in set A. The type order matters less to the player.
2. The redo multiplier scales only the base. With a small base it does almost nothing: set A second run pays 92 against 94. A replay of a stage pays nearly the same. The virtue bonus is never redo-scaled.
3. The stage index adds 5 per stage to the virtue base. So stage depth, not objective type, drives the payout.
4. If Jeff wants the type order to be felt, he should lower the virtue bonus in Phase 5, or keep the weights higher (set C).
5. Phase 5 owns `virtue_bonuses`, `stage_index_bonus_per`, the realm-order step, and the fight bonuses. I do not propose them here.

## 4. Recommendation (separate from the options; Jeff decides)

Recommend Set B as the working shape, with the scale left open for Phase 5.

Reasons:
1. Set A makes the pace bonus pay 0 on every type. The bonus is `roundi(stage_base x 0.05 x fraction)`. `max_bonus_ase` of a base under 10 rounds to 0 (A: base 4 to 8). The pace row would show 0 Ase in all pace modes (READ: `PaceService.gd`). Set A also makes the retreat partial 0 or 1 Ase.
2. Set B keeps the type order readable (8 to 16) and the pace bonus at 1 Ase for most types. Set C has the same pace result but cuts less.
3. The proposal fixes the shape and the order. The scale is a Phase 5 decision, because the virtue bonus and the fight bonus are larger levers. If Jeff sets a lower target, multiply the B column by one factor and keep the order.
4. Weigh `pursue` below `combat` in every set until Jeff decides how optional objectives pay.
5. A cut of 62% to 75% in the stage payer (fixture run) is large already. The fight bonus (35 per fixture fight) is then larger than the stage base in sets A and B. Jeff should decide the fight bonus together with the weights in Phase 5.

I do not recommend a first-summon target. That is for Jeff.

## 5. Config shape: the boss does not pay

Constraint (D-07): a type with no weight logs an error through `StructuredLogger` and pays 0. The boss stub is on every stage (`RealmGenerator.gd:148-152`). It must NOT log an error each stage.

| Option | Config | D-07 fit | Cost |
|---|---|---|---|
| 1. Remove `boss` from `objective_weights` | Delete the key. | CONFLICT. `boss` has no weight, so it logs an error on every stage. The code needs a hard-coded exception for `boss`. D-02 says not a hard-coded type. | Reject. |
| 2. Explicit list | New key `data.rewards.unpaid_objective_types: ["boss"]`. `base_reward` skips listed types silently. Unlisted and unweighted types log the error. | FITS. Intent is named in config. | One new key, one new code branch, one new test. |
| 3. Explicit zero | Keep `"boss": 0` in `objective_weights`. A key that is present is a known type. | FITS. D-07 means "no weight key". A key with 0 is a weight. | No new key, no new code branch. Risk: a 0 on a real type pays 0 without a log. |

Recommend Option 3, for its size: one number changes (60 to 0), and D-07 needs no exception. A later boss story edits one visible number, which matches D-02 ("restore a boss weight on purpose"). It also lets a load-time check require every `ObjectiveModel.VALID_TYPES` entry to have a key in `objective_weights`. Take Option 2 instead if Jeff wants a "free on purpose" list that is separate from "weight 0".

Notes for the developer (no code):
- `RewardCalc.base_reward` is `static` and has no logger. D-07 needs a logger path or a check at config load. A check at load logs once. A log in `base_reward` repeats per call.
- Callers of the base: `StageSettlementService.gd` (stage payer), `RewardCalc.compute`, and `ActiveStageService.get_stage_base_reward` (callers `EncounterSetupService.gd:739`, `FlowRuntime.gd:1202`, `VentureController.gd:379`).
- Test fixture `EconomyRewardTests._default_cfg()` has weights for `combat`, `shrine`, `boss` only. Tests that use `recover`, `protect`, `endure` and others with that cfg would log the D-07 error.

## 6. Values moved outside the stage payer

Weights feed `get_stage_base_reward` and `RewardCalc.base_reward`. Every reader of the stage base moves. Tables use the same weights (COMPUTED). Today column includes the boss 60.

| Reader | Code (READ) | Formula | Today (combat / shrine / other) | A | B | C |
|---|---|---|---|---|---|---|
| Retreat partial | `core/runtime/FlowRuntime.gd:1201-1202` | `roundi(base x 0.12)` | 11 / 12 / 7 | 1 for most (`pursue` 0) | 1 to 2 | 2 to 3 |
| Return-home partial | `core/runtime/controllers/VentureController.gd:368,379` (not 381) | same, times Directive `intel_retention_bonus` (Scout 1.5) | same as above, x1.5 for Scout | 1 | 1 to 3 | 2 to 4 |
| Defeat consolation | `EconomyService.gd:168` | `roundi(base x 0.25 x redo)` | 23 / 25 / 15 | 1 to 2 | 2 to 4 | 4 to 6 |
| Rank ceiling | `RewardCalc.gd:~103` | `max_possible = base + enemies x 5 + echoes x 10 + max_pace` | | | | |
| Pace bonus | `PaceService.max_bonus_ase`, base captured at `EncounterSetupService.gd:739` | `roundi(base x 0.05 x fraction)` | 3 to 5 | 0 | 0 or 1 | 1 |
| Resolve card | `settle_stage_complete` breakdown; `PendingResultService.gd:314,464` | Rows: `Base objectives`, `Realm virtue`, `Pace bonus` | | | | |

Detail:
- Retreat: the retreat costs 30 Ase before round 1 (`data.combat.retreat_ase_cost`, READ in Phase 1). The partial payout becomes at most 3. The retreat is a net loss today (30 against 7 to 12). It stays a net loss, with a larger gap. Jeff may want to see this.
- Defeat rank (COMPUTED): the numerator is `roundi(base x 0.25)`. A defeat on a `combat` stage with 3 enemies and 2 Echoes: today 23/125 = 0.18 (rank D). Set A 1/40 = 0.03, B 3/45 = 0.07, C 4/50 = 0.08. All are rank F (D needs 0.15).
- Rank on a win (COMPUTED, 3 enemies, 2 Echoes, one Echo lost): ratio today (base 60) 0.895, set A combat (5) 0.75, set B combat (10) 0.78, set C combat (15) 0.80. A ratio of 0.75 is the A threshold. Base 4 gives 0.744 (rank B). One missed kill with all Echoes alive: today 0.947 (S); set A 0.875, B 0.889 (A); C 0.90 (S on the exact edge). A low base makes the rank depend on kills and survivors, not on the stage. Rank thresholds are not changed here (Phase 5 may change them).
- Pace bonus: for a base under 10 the maximum rounds to 0. The row "Pace bonus 0" shows in pace modes at every value (decisions D-13), and `pace_state` is "none".
- Resolve card: `Base objectives` shows the new base. `Defeat penalty` rows show small numbers. The `Redo penalty` row may show -1 or none, because the base is small.
- Adjacent finding (not fixed): `EconomyService.gd:168-169` hard-codes the defeat factor 0.25. `data.rewards.defeat_factor` (0.25) exists and `RewardCalc` reads it for the rank. ANSWERS #83 says tunables live in config. Phase 5 may need this.

### Recorded tests and fingerprints that could move (grep of `tests/`; none run)

| Test / constant | Status | Reason |
|---|---|---|
| `tests/EconomyCharacterizationTests.gd` (`econ_char`): `base_reward_per_type`, `unweighted_types_add_zero`, `boss_stub_adds_sixty`, `stage_payer_matrix` tables (`_STAGE_PAID`, `_SHRINE_STAGE_PAID`), defeat tables, `encounter_payer_defeat` | WILL MOVE | They assert today's weights 30 / 40 / 60 / 0 and the labels `KNOWN DEFECT (Phase 3 will change this)`. Phase 3 inverts them. The pool-frequency test prints weight means: check for asserts. |
| `*_FINAL_HASH` x 7 in `tests/FlowFingerprintTests.gd` and x 7 in `tests/FlowFingerprintSeekTests.gd` | PREDICTED to move for pace modes, possibly all | The FINAL payload holds `ase_awarded`, `rank`, `objective_state` (with `pace_state`). Stage base is captured into `combat_state["stage_base"]`. The harness uses `realm.01` `stage.0` (first objective `guide_spirit`): base 60 today, the `guide_spirit` weight after. Pace bonus and `pace_state` change when the base changes. Rank can change. Moves must be attributed to this one cause, in a separate re-record from the Phase 2 one. |
| `*_SAVE_HASH` in the same two files | PREDICTED to move where a pace bonus is paid | The save payload holds `ase` from the encounter payer. |
| `*_ROUNDS_HASH` | PREDICTED to hold | No Ase or base in the rounds payload. |
| `tests/EconomyRewardTests.gd` (`reward`, a long suite) | PREDICTED to hold, with one risk | Tests 1, 2, 27 use the inline `_default_cfg()` (30 / 40 / 60). It does not read `balance.json`. Test 2 expects 130 (incl. boss 60). It holds under Option 3 (only `balance.json` changes). Tests that build a fight through `FlowFingerprintTests._setup_encounter` read the real base, but compare live values with each other (lines 534, 593, 760, 849, 1062). Risk: D-07 error logs from unweighted types in `_default_cfg()`. |
| `tests/VentureCharacterizationTests.gd` `_expected_intel_partial` (:599) used at :636, :678, :770 | PREDICTED to hold | It recomputes the expected value from live weights. Check that no assert needs the partial to be above 0. |
| `tests/EconomyTests.gd:163` (`settle_stage_complete(30, ...)`) | HOLDS | Direct call, no config. |
| `tests/Stage004SeamTests.gd:1391`, `tests/PendingResultTests.gd:250,288,382`, `tests/CombatRoundtripIntegrationTests.gd:645` | PREDICTED to hold | They compare two live values, or assert 0. |
| `tests/OnboardingTests.gd:297` (40 Ase) | HOLDS | First-trial grant, not a weight. |
| `tests/PaceUITests.gd`, `FoundationUITests.gd`, `SanctumPulseTests.gd`, `UnifiedResolveTests.gd` | HOLD | Synthetic snapshot values. |

Method: `grep` for `objective_weights|base_reward|partial_intel|rank_thresholds|stage_base|ase_awarded` in `tests/`, then read the hits. The call sites above were read in `core/`. I did not run any test.

## OPEN — questions and assumptions

ASSUMED: The effort order `pursue` < `combat` < `recover` = `protect` < `endure` < `shrine` < `guide_spirit` | WHY: It follows `TYPE_DESCRIPTIONS` and the existing `shrine` > `combat` order; I did not read the objective handlers | WRONG IF: Jeff or the play data show `endure` or `protect` is harder than `shrine`.
ASSUMED: A stage payout includes the weight of an optional objective even when the player skips it | WHY: `RewardCalc.base_reward` and `StageSettlementService` sum all objectives without a `completed` check (READ) | WRONG IF: another code path filters by `completed` before the stage payer runs. I did not find one.
ASSUMED: The "stages needed" figures repeat the fixture run in order, ignoring redo and all other Ase | WHY: It is the only stage sequence Phase 1 measured | WRONG IF: Jeff wants a different path (for example `realm.02`, or average stages).
BLOCKED: Should a skipped optional objective pay its weight? | CHECKED: `RewardCalc.gd`, `StageSettlementService.gd`, `RealmGenerator.gd:145` | NEED: Jeff's decision. A "pay only completed objectives" rule is a mechanic change and needs `sr-game-designer`.
BLOCKED: Is `guide_spirit` required or optional? Config says optional. The generator makes it required. | CHECKED: `data.stages.objective_types`, `RealmGenerator.gd:145`, `FlowStageExploreState.gd:302` | NEED: Jeff's decision, then a fix in config or generator (not part of this story).
BLOCKED: Targets for Phase 5: stages to afford a first summon (60), a called summon (150), a skill unlock (40); Ase of a first full `realm.01` run | CHECKED: GDD §20.12, §20.14, §21.1 (open: "exact summon cost and early Ase cadence"), `ANSWERS.md` (no reward-pace answer) | NEED: Jeff's numbers.
BLOCKED: Does Jeff want to lower the virtue bonus and the fight bonus (5 per enemy, 10 per Echo) together with the weights? | CHECKED: `data.rewards` | NEED: Jeff's decision. They are Phase 5 levers; they are larger than the weights in sets A and B.
BLOCKED: Which boss config option (2 or 3)? | CHECKED: D-02, D-07 | NEED: Jeff's choice. I recommend Option 3.
BLOCKED: Which set (A, B, C), or other values? Each number needs his approval before it enters `data/balance.json` | CHECKED: D-03, D-04 | NEED: Jeff.

Skills used: none. Arithmetic: a scratch script outside the repo (rounding as Godot `roundi`, half away from zero). Files edited: this file only.
