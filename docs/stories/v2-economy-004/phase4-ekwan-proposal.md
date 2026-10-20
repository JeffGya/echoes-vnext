# V2-ECONOMY-004 Part A — Phase 4 proposal: Ekwan amount per objective type

Written in STE. Every number marked PROPOSAL is a proposal. Jeff decides each one. No value is in `data/balance.json`.
Tags: READ = taken from code, data or docs. COMPUTED = my arithmetic (formulas below). PREDICTED = not run.
No test was run. No file other than this one was edited.

## 1. Summary for Jeff

- Each objective type gets its own Ekwan amount (D-05). The stage pays the SUM of the amounts of its COMPLETED objectives (D-06, D-16). Fights pay no Ekwan (D-28). `boss` pays 0 (D-10).
- Ekwan is no longer a share of Ase. The keys `ekwan_base_factor` and `ekwan_shrine_multiplier` go away (D-27).
- GDD §19.2 (READ): Ekwan is "shaped matter, stored labor, and build capacity". It is not generic gold. So I order the types by how much they read as matter or labor. I do not copy the Ase order.
- What the amounts must achieve:
  1. Ekwan must feel scarce (D-04).
  2. A player must be able to establish the first institution (Hearth, 10) within a span Jeff accepts.
  3. The type order must be readable: a shrine or a recover pays more than a plain fight.
- FINDING (COMPUTED): Phase 3 already cut Ekwan. Ekwan is still 12% of Ase in the tree, and Ase fell. The fixture run now pays 14 Ekwan from stages, not 44 (section 3, "Baselines").
- FINDING (READ): Ekwan has few sinks (section 4). Only two things spend it: institutions and vow breaks. After the player has built both institutions (25 Ekwan), more Ekwan has no use until Part B adds crafting. Scarcity is real only in the first stages.
- Jeff must set these targets (I do not): stages to afford the first institution; stages to afford both institutions; whether the vow-break prices (20 to 100) are goals or penalties.

## 2. Candidate sets

All values PROPOSAL. Integers. `boss` is 0 in every set. Set A is Set B halved (rounded half up). Set C is Set B doubled. So Phase 5 can scale the whole shape and keep the order.

Order by "matter or labor" (my judgement, from `ObjectiveModel.TYPE_DESCRIPTIONS` and GDD §19.2; no mechanic added):

| Rank (low to high) | Type | Description (READ) | Reason in terms of GDD §19.2 |
|---|---|---|---|
| 1 | `pursue` | "Track and intercept before the window closes." | Optional chase. No matter gained, no labor stored. |
| 1 | `combat` | "Defeat all enemies to proceed." | A fight makes nothing. Fights already pay no Ekwan (D-28); this is the lowest objective amount. |
| 2 | `protect` | "Keep the presence here safe." | Guard labor, but nothing is shaped or gathered. |
| 2 | `guide_spirit` | "Find the spirit and see it to safety." | A spirit task. It reads as Ase (life force), not matter. It has the highest Ase weight (16) and a low Ekwan on purpose. |
| 3 | `endure` | "Hold your ground through the pressure." | Held labor: the party stands for `hold_rounds`. |
| 4 | `recover` | "Find and retrieve what was taken." | Matter comes back into the house. |
| 5 | `shrine` | "Purify the corrupted shrine." | A site is made good again. Closest to "build capacity". |
| 0 | `boss` | stub | Pays 0 (D-10). |

Ties: `pursue` = `combat`; `protect` = `guide_spirit`. Descriptions show no difference in effort. Jeff may split them.

| Type | Ase today (D-09) | Set A (x0.5) | Set B | Set C (x2) |
|---|---|---|---|---|
| `pursue` | 8 | 1 | 2 | 4 |
| `combat` | 10 | 1 | 2 | 4 |
| `protect` | 12 | 2 | 3 | 6 |
| `guide_spirit` | 16 | 2 | 3 | 6 |
| `endure` | 14 | 2 | 4 | 8 |
| `recover` | 12 | 3 | 5 | 10 |
| `shrine` | 15 | 3 | 6 | 12 |
| `boss` | 0 | 0 | 0 | 0 |

Set A has many 1s and 2s. It is scarce but the type order is hard to feel (1 / 1 / 2 / 2 / 2 / 3 / 3).

Config: new key `data.rewards.objective_ekwan` (name PROPOSAL), next to `objective_weights`. Consumer (READ): `StageSettlementService._plan` reads `ConfigService.get_rewards_cfg` (`ConfigService.gd:379-388`), which returns `data.rewards`. `data.rewards` is at `data/balance.json:1532`. Do not place the key in `data.economy`. Include a `boss: 0` entry so D-07 logs no error.

### Baselines (what "today" means)

Fixture: `realm.01` stages 0 to 3 with objectives `guide_spirit`, `protect`, `combat`, `combat`; `run_index` 0, `run_count` 0.

| Baseline | Stage 0 | Stage 1 | Stage 2 | Stage 3 | Run total |
|---|---|---|---|---|---|
| Before ECONOMY-004 (main; Phase 1, section 1.6, MEASURED) | 8 | 9 | 13 | 14 | 44 (60 with one fixture fight per stage) |
| Tree now (after Phase 3), Ekwan still 12% of Ase (COMPUTED) | 3 | 3 | 4 | 4 | 14 (30 with fight Ekwan 4 per fight) |

Arithmetic, "Tree now": Ase per stage is 16+10 = 26, 12+15 = 27, 10+20 = 30, 10+25 = 35. Ekwan = `roundi(Ase x 0.12)` = `roundi(3.12)` 3, `roundi(3.24)` 3, `roundi(3.60)` 4, `roundi(4.20)` 4. Sum 14. Fight Ekwan was `roundi(35 x 0.12)` = 4 per fixture fight; D-28 removes it.

## 3. Ekwan per stage and per run, for each set (COMPUTED)

Fixture run. Completed-only base, so each stage pays its one pre-boss objective. `redo` = 1.0 (`run_count` 0).

| | Stage 0 `guide_spirit` | Stage 1 `protect` | Stage 2 `combat` | Stage 3 `combat` | Run total | Against main (44) | Against tree now (14) |
|---|---|---|---|---|---|---|---|
| Set A | 2 | 2 | 1 | 1 | 6 | -86% | -57% |
| Set B | 3 | 3 | 2 | 2 | 10 | -77% | -29% |
| Set C | 6 | 6 | 4 | 4 | 20 | -55% | +43% |

Per-stage range in the pool (all 7 types, one objective per `realm.01` stage): main 8 to 15; tree now 2 to 5 (lowest `pursue` stage 0: Ase 18, Ekwan 2; highest `shrine` stage 3: Ase 40, Ekwan 5); Set A 1 to 3; Set B 2 to 6; Set C 4 to 12.

Pool mean per `realm.01` stage, weighted by the measured draw counts of Phase 1 (combat 98, shrine 100, recover 106, protect 88, endure 104, pursue 120, guide_spirit 84 of 700): A 1.98; B 3.57; C 7.14. Arithmetic for B: (98x2 + 100x6 + 106x5 + 88x3 + 104x4 + 120x2 + 84x3) / 700 = 2500 / 700 = 3.57.

The fixture stages are all low types. The pool mean is higher than the fixture mean. Both are shown below.

### Stages needed to afford (COMPUTED)

Method: add the fixture stage amounts in order (stage 0, 1, 2, 3, then repeat) until the sum reaches the price. Redo ignored (see section 5). Pool column: `ceil(price / pool mean)`. Prices (READ): Hearth 10, Training Grounds 15 (`establish_ekwan_cost`, `data/balance.json:3073,3086`); vow `tikoro_nko_agyina` tier 2 = 20 and tier 4 = 100 (`breaking_costs`).

| Price | Set A fixture | Set A pool | Set B fixture | Set B pool | Set C fixture | Set C pool |
|---|---|---|---|---|---|---|
| Hearth, 10 | 6 | 6 | 4 | 3 | 2 | 2 |
| Training Grounds, 15 | 10 | 8 | 6 | 5 | 3 | 3 |
| Both institutions, 25 | 17 | 13 | 10 | 8 | 5 | 4 |
| Vow break tier 2, 20 | 13 | 11 | 8 | 6 | 4 | 3 |
| Vow break tier 4, 100 | 66 | 51 | 40 | 29 | 20 | 15 |

Arithmetic (fixture column):
- Set A, running sum: 2, 4, 5, 6, 8, 10 (Hearth at stage 6), 11, 12, 14, 16 (Training Grounds at stage 10). Both (25): 4 runs = 16 stages = 24; stage 17 adds 2 = 26. Tier 2 (20): 3 runs = 12 stages = 18; stage 13 adds 2 = 20. Tier 4 (100): 16 runs = 64 stages = 96; stages 65 and 66 add 2 and 2 = 100.
- Set B, running sum: 3, 6, 8, 10 (Hearth at stage 4), 13, 16 (Training Grounds at stage 6), 18, 20. Both (25): 2 runs = 8 stages = 20; stage 9 adds 3 = 23; stage 10 adds 3 = 26. Tier 2 (20) at stage 8. Tier 4 (100): 10 runs = 40 stages.
- Set C, running sum: 6, 12 (Hearth at stage 2), 16 (Training Grounds at stage 3), 20 (stage 4). Both (25): stage 5 = 26. Tier 4 (100): 5 runs = 20 stages.

Reading, in runs of `realm.01` (4 stages): Set B pays a Hearth at the end of run 1 and Training Grounds in run 2 (stage 6). Set A needs run 2 for the Hearth and run 3 for Training Grounds. Set C pays Hearth in stage 2.

### What the sinks are today, and what it means for scarcity (READ, Phase 1 section 3.2)

| Site | Spend | Price |
|---|---|---|
| `InstitutionService.gd:103` | Establish an institution | `hearth` 10, `training_grounds` 15 |
| `InstitutionService.gd:158` | Remove an Echo from an institution | 3 each time |
| `VowService.gd:344` | Break a vow | `tikoro_nko_agyina` tier 2/3/4: 20/50/100; `praye_wokabomu` tier 2: 20; `obi_nnim_kyere` tier 2: 15; tier 1 costs no Ekwan |
| `ui/AppRoot.gd:1311` | Debug `ekwan spend` | Not a game sink |

- Only institutions and vow breaks spend Ekwan. Establishing is a one-time spend (25 for both). Removing an Echo costs 3 and is optional. A vow break is a penalty the player should not plan for.
- So Ekwan has FEW sinks. Total planned demand is about 25. Under Set B the player has 25 after 10 stages (about 2.5 runs). After that, every extra Ekwan has no use until Part B (crafting; GDD §19.6 "item + Ekwan + Ase").
- Consequence for scarcity: the amounts decide how long the first 25 Ekwan take. They do not decide long-term scarcity. Long-term scarcity needs sinks. Set C is not "plentiful" by this measure, because it only brings the 25 sooner (stage 5). If Jeff wants Ekwan to stay scarce after the institutions, the sinks must come first (Part B), then the amounts can be tuned.
- Comment disagrees with code (not fixed): `VowService.gd:340` says "clamp to zero if broke". `spend_ekwan` denies the whole spend when funds are low (Phase 1, section 6). A player with too little Ekwan breaks a vow for free in Ekwan terms.

## 4. Retreat, defeat and return-home partials

READ: the retreat, return-home and defeat consolation payers pay Ase only. They add no Ekwan today (`add_ekwan` has the call sites listed in section 7). This proposal adds none. A stage that is not settled pays no Ekwan.

## 5. The replay question

Today (READ): `redo_multiplier` is `max(redo_penalty_floor, 1 - run_count x redo_penalty_per_run)` = 1.0, 0.9, 0.8, 0.7, 0.6, 0.5 for `run_count` 0 to 5 (floor 0.5). It scales the Ase base only (`stage_payout_rows`, `EconomyService.gd:247`). `_plan` already holds `redo_mul` (`StageSettlementService.gd`), so Ekwan can use it with no new input.

| | Option R1: Ekwan ignores redo | Option R2: Ekwan x `redo_multiplier` |
|---|---|---|
| Rule for the player | A replay pays full Ekwan and less Ase. | A replay pays less of both. One rule: "replays pay less". |
| Anti-farm | None for Ekwan. Ekwan has few sinks now, so the risk is low today. When crafting exists (Part B), Ekwan becomes the farmable resource. | Same protection as Ase. |
| Code | No change. | Round once at the stage sum: `roundi(sum x redo)` (same as the Ase base). |
| Effect at small amounts (COMPUTED) | None. | Small. See table below. |
| Resolve card (D-19, replay row absent when it does not apply) | No Ekwan replay row. | If the rounding changes nothing, no row. A row appears only when the amount changes. |

Fixture run total under R2 (COMPUTED; each stage is `roundi(amount x multiplier)`, `roundi` rounds half away from zero):

| `run_count` (multiplier) | Set A | Set B | Set C |
|---|---|---|---|
| 0 (1.0) | 6 | 10 | 20 |
| 1 (0.9) | 6 | 10 | 18 |
| 2 (0.8) | 6 | 8 | 16 |
| 3 (0.7) | 4 | 6 | 14 |
| 5 (0.5) | 4 | 6 | 10 |

Example arithmetic, Set B, `run_count` 3: stage 0 `roundi(3 x 0.7)` = `roundi(2.1)` = 2; stage 1 the same = 2; stages 2 and 3 `roundi(2 x 0.7)` = `roundi(1.4)` = 1 each; total 6.

Reading: with Set A or Set B, R2 does nothing on the first replay (0.9). It starts to bite on the third replay. With Set C it bites on the first replay. R2 has a flat floor: Set B never drops below 6 per fixture run.

Recommendation on replay: R2 (follow redo). Reasons: (1) `redo_mul` already exists in the plan, so the cost is small; (2) one rule for both currencies is easier to explain (D-17); (3) Ekwan is the currency that Part B will make farmable. State plainly that the effect is small at Set A and B. Jeff decides.

## 6. Rounding

- Ekwan is an integer (`add_ekwan` takes `int`, `EconomyService.gd:263`). The config amounts are integers.
- Smallest useful amount: 1. A type set to 0 pays 0 Ekwan and logs nothing (D-07 logs only a MISSING key). Do not set 0 on a real type by accident. The Resolve card hides the Ekwan row when the amount is 0 (`ResolveScreen.gd:189`).
- Risk of rounding to 0: only through redo. `roundi(1 x 0.5)` = 1 (rounds half away from zero). So with the floor at 0.5 an amount of 1 never reaches 0. If Jeff lowers `redo_penalty_floor` below 0.5, an amount of 1 rounds to 0, and Set A would pay 0 on every `combat` and `pursue` replay.
- Round once per stage, on the sum, as the Ase base does. Do not round each objective. In `realm.01` there is one pre-boss objective per stage, so both give the same value. In `realm.02` 611 of 1187 sampled stages have two (Phase 1, section 2), and per-objective rounding would lose or gain Ekwan.
- Edge values at x.5 (COMPUTED): Set B `recover` 5 at multiplier 0.7 = 3.5, and `protect` 3 at multiplier 0.5 = 1.5. The result depends on float arithmetic in `1.0 - run_count x 0.1`. A test must pin these cells.
- Two-objective example (`realm.02`): `shrine` + `guide_spirit` = 6 + 3 = 9 in Set B; both completed. If only one is completed, 6 or 3.

## 7. Values that move outside the stage payer

### Readers and writers of Ekwan (grep, READ)

| Site | What it does | Phase 4 effect |
|---|---|---|
| `core/economy/EconomyService.gd:216-241` `settle_stage_complete` | Stage payer: `roundi(Ase x factor)`, `add_ekwan`, "Sanctum share" row | Replace with the amount from the new key. Remove the `ekwan_factor` parameter. |
| `core/economy/EconomyService.gd:133-199` `reward_encounter_complete` | Fight payer: `ekwan_total`, "Sanctum share" row | Remove the Ekwan share (D-28). `ekwan_awarded` is 0 on every fight. |
| `core/economy/StageSettlementService.gd:129,154,200-213` | `_plan` builds `ekwan_factor` from `objectives[0]` (reads `type`); settle log carries `ekwan_awarded` | Replace the factor with the summed amount. Keep the log field. |
| `core/economy/StageSettlementService.gd:166-187` `preview()` | Ase only ("Ekwan is Phase 4") | Needs Ekwan too (see OPEN). |
| `core/state/flow/states/venture/FlowEncounterState.gd:211-217,240,422` | Fight factor from `obj_type`; `add_ekwan(_data, ekwan_awarded)` | Remove the factor. Line 422 then writes 0. Keep the key (shape rule). |
| `core/state/flow/states/venture/ResolveSnapshotBuilder.gd:143` `add_ekwan` | Writes `ekwan_awarded` | Shape stays. |
| `core/state/flow/states/venture/VentureResolveSnapshotBuilder.gd:125,189` | `add_ekwan(_data, 0)` | None. |
| `core/state/flow/PendingResultService.gd:314,470-471` | Stores and restores `ekwan_awarded` | None; shape stays. |
| `ui/screens/venture/ResolveScreen.gd:188-190,396-400` | Ekwan row and chip, shown when > 0 | Nothing shows on a fight card after D-28. See OPEN. |
| `ui/components/RewardEntryItem.gd:26` | Colors an `ekwan` breakdown row | Used only if a breakdown row has `currency: ekwan`. |
| `core/sanctum/SanctumSnapshotBuilder.gd:226,382`, `InstitutionService.gd:99-103`, `VowService.gd:335-344` | Read the balance; spend it | None. They see smaller balances. |
| `ui/AppRoot.gd:1309` | Debug `ekwan add` | None. |
| `core/save/SaveSchema.gd:76`, `SaveService.gd:421-440`, `EconomyService.gd:323-330` | Save field `economy.ekwan` | None. Save change: none. |
| `data/balance.json:1571-1572` | `ekwan_base_factor`, `ekwan_shrine_multiplier` | Removed (D-27). Needs the full-repo audit of `core/`, `ui/`, `tests/`, `docs/`. |

Docs that mention the old model and need an update: `docs/resolve-snapshot-block-spec.md` (lines 61, 85, 128, 145, 278), `docs/v2-migration-map.md:459`, `docs/stories/v2-infra-003/defect-register.md` (D83), `tests/FlowFingerprintTests.gd:494-495` (a comment that says Ekwan is a fraction of Ase).

### Recorded tests that could move (grep of `tests/`; none run)

| Test or constant | Status | Reason |
|---|---|---|
| `tests/EconomyCharacterizationTests.gd` (`econ_char`): lines 133-135 (reads `ekwan_base_factor`), 251-254 (fight Ekwan 4), 417-418 (stage matrix Ekwan), 441 and 465-466 (shrine Ekwan, fight Ekwan), 494-496 (defeat Ekwan) | WILL MOVE | They assert the 12% model and the removed keys. Rewrite them for the new source. |
| `tests/EconomyTests.gd:163-174` | WILL FAIL (compile or assert) | Calls `settle_stage_complete(30, 1.0, 0, 0.12, logger, 0)` and expects `ekwan_awarded > 0`. The signature and the rule change. |
| `tests/EconomyRewardTests.gd:214,265,274,481,1014` | WILL FAIL TO COMPILE if the `ekwan_factor` parameter is removed | They call `reward_encounter_complete(...)` and `settle_stage_complete(30, 1.0, 0, 0.0, ...)` with the old argument list. No Ekwan assert in this file. |
| `*_FINAL_HASH` x 7 in `tests/FlowFingerprintTests.gd` and x 7 in `tests/FlowFingerprintSeekTests.gd` | PREDICTED to move | The payload holds `ekwan_awarded` (`FlowFingerprintTests.gd:366`). Fights pay 0 Ekwan, so the value changes in every mode. Stage Ekwan is not in the payload (the harness does not dispatch `flow.complete_stage`). |
| `*_SAVE_HASH` x 14 | PREDICTED to move | The save payload holds `economy.ekwan` (`FlowFingerprintTests.gd:416`). Fight Ekwan was paid into it. |
| `*_ROUNDS_HASH` x 14 | PREDICTED to hold | No Ekwan in the rounds payload. |
| `tests/VentureCharacterizationTests.gd:265-295` | PREDICTED to hold, with one risk | It expects Ekwan to rise on a no-encounter `complete_stage`. Under the completed-only rule it holds only if the fixture objective is `completed` and its type amount is above 0. Check the fixture. |
| `tests/VentureCharacterizationTests.gd:696,713` and `tests/CombatRoundtripIntegrationTests.gd:647` | HOLD | They assert `ekwan_awarded` = 0 on retreat cards. |
| `tests/OnboardingTests.gd:284` | HOLDS | Keeper trial omits the key. |
| `tests/InstitutionTests.gd`, `VowServiceTests.gd`, `SkillReachTests.gd`, `StopShortWiringTests.gd`, `SaveBridgeTests.gd`, `StageObjectiveTests.gd`, `FlowSnapshotFingerprintTests.gd:1129` | HOLD | They set Ekwan directly or use synthetic snapshots. |

New tests Phase 4 needs: the amount per type and the sum over completed objectives only; an incomplete objective pays 0; fights pay 0 Ekwan; the config has a key for every `ObjectiveModel.VALID_TYPES` entry; the replay cells at the x.5 edges (section 6); the removed keys are absent from `balance.json` and from `core/`.

Method: `grep -rn "ekwan_awarded|add_ekwan|ekwan_base_factor|ekwan_shrine_multiplier|ekwan_factor"` over `core/ ui/ tests/ scripts/ docs/`, then reading the hits. I did not run any test.

## 8. Recommendation (separate from the options; Jeff decides)

1. Use Set B as the working shape: 2 / 2 / 3 / 3 / 4 / 5 / 6, boss 0. Reasons: (a) the fixture run pays 10, so the Hearth is affordable at the end of the first `realm.01` run and Training Grounds in the second; (b) it is below the tree-now total of 14 (D-04 direction: scarce) and well below main (44); (c) the type order is readable (2 to 6); (d) Set A is too flat to show an order; Set C pays the first institution in 2 stages, which is not scarce.
2. Keep the scale open for Phase 5: B x 0.5 or x 2 keeps the order.
3. Replay: R2 (follow redo), rounded once on the stage sum.
4. Do not tune Ekwan long-term scarcity now. It needs sinks (Part B). Record this for the Part B plan.
5. I do not recommend the target "stages to the first institution". That is for Jeff. Set B gives 4 stages on the fixture and 3 on the pool mean.

## OPEN — questions and assumptions

ASSUMED: The order `pursue` = `combat` < `protect` = `guide_spirit` < `endure` < `recover` < `shrine` reflects "matter or labor" | WHY: It follows `TYPE_DESCRIPTIONS` and GDD §19.2; I did not read the objective handlers | WRONG IF: Jeff reads `guide_spirit` or `protect` as more material than `endure`, or wants the Ase order for Ekwan too.
ASSUMED: "Stages to afford" repeats the fixture sequence (guide_spirit, protect, combat, combat) and ignores redo | WHY: It is the only sequence Phase 1 measured | WRONG IF: Jeff wants another path, or the pool-mean column to lead.
ASSUMED: `roundi` rounds half away from zero (so `roundi(0.5)` = 1) | WHY: Godot 4 behaviour; the code uses `roundi` everywhere | WRONG IF: Godot 4.6 differs. A test should pin the x.5 cells.
ASSUMED: The new config key is `data.rewards.objective_ekwan` | WHY: `StageSettlementService._plan` reads `data.rewards` through `ConfigService.get_rewards_cfg` (`ConfigService.gd:379-388`) | WRONG IF: Jeff wants another name; the section is correct.
BLOCKED: Target: stages to afford the first institution (Hearth, 10), and both (25) | CHECKED: GDD §19.2, §19.10, §21.1 ("exact early Ekwan cadence" is open); `ANSWERS.md` and `decisions.md` (no Ekwan pace) | NEED: Jeff's number. This picks A, B or C.
BLOCKED: Are the vow-break prices (tier 2 = 20, tier 4 = 100) goals the player saves for, or penalties? | CHECKED: `VowService.gd`, Phase 1 section 3.2 | NEED: Jeff. If they are penalties, their Ekwan cost does not set the pace.
BLOCKED: Which field shows the stage Ekwan on the Resolve card? After D-28 `ekwan_awarded` is 0 on every fight card, and `ekwan_awarded` is never set for the stage payout. `preview()` returns Ase only, and the UI session decision says Ekwan shows only as "Ekwan earned" with an amount, no cause (D-18 relay) | CHECKED: `ResolveScreen.gd:188-190`, `StageSettlementService.gd:166-187`, `ResolveSnapshotBuilder.gd:136-137`, `decisions.md` D-18, D-24 | NEED: Jeff or the UI session: add the stage Ekwan to the preview (new key, for example `stage_payout_ekwan`) and let the card show it, or keep it hidden. Without this, the player never sees the stage Ekwan arrive. A new snapshot key may touch the key-list tests.
BLOCKED: Should the "Sanctum share" breakdown row (`currency: ekwan`) stay? | CHECKED: `EconomyService.gd:194,235`, D-18 relay ("no sanctum_share cause") | NEED: Jeff. I read the relay as: remove the row and show only "Ekwan earned".
BLOCKED: Replay: R1 or R2? | CHECKED: `EconomyService.gd:247`, `StageSettlementService.gd` `_plan` | NEED: Jeff. I recommend R2.
BLOCKED: Which set (A, B, C), or other values? Each number needs his approval before it enters `data/balance.json` | CHECKED: D-04, D-05, D-09 | NEED: Jeff.

Skills used: none. Arithmetic: a scratch script outside the repo (python; half-up rounding as Godot `roundi`). Files edited: this file only.
