# V2-ECONOMY-004 Phase 5.0: code confirmations (read-only)

Author: mechanics-developer. Date: 2026-10-21. No file other than this one was edited. Godot was not run.

**Baseline.** All `file:line` values are from commit `4c3b3a2` (HEAD), read with `git show HEAD:` or `git grep HEAD`.
Files not listed as modified in `git status` read the same on disk.
**Warning.** While I worked, the live tree changed. Core files and `data/balance.json` now hold uncommitted Phase 5.1 edits that are not mine
(`RewardCalc`, `EconomyService`, `StageSettlementService`, `RealmService`, `FlowEncounterState`, `PaceService`, `tests/EconomyCharacterizationTests.gd`).
On disk, `enemy_defeated_bonus`, `virtue_bonuses` and `pace_bonus_pct` are already gone from `data/balance.json`. Line numbers on disk differ from HEAD for those files.
The coordinator must know that a second writer is active in this checkout (see Surprises, item 1).

Every answer is READ-FROM-CODE unless it says otherwise.

---

## 1. "Home" (D-45): the death field

**Death field. READ-FROM-CODE.** An Echo is dead when the actor dict key `is_dead` is `true`.
- Set when HP reaches 0 in melee: `core/combat/CombatService.gd:87` (`defender["is_dead"] = true`, with `death_round`).
- Set at turn start when `current_hp <= 0`: `core/actors/ActorStateMachine.gd:128-131`.
- Every Echo actor starts with `is_dead: false` and `current_hp = max_hp`: `core/actors/EchoActor.gd:53,56`.
- Hazard death erases `is_ko` and sets `is_dead`: `core/movement/LiveHazardOutcomeService.gd:27,69`.

**Fight-end tally. READ-FROM-CODE.** The Resolve snapshot projects `status = "dead"` when `is_dead` is true (`EncounterSnapshotBuilder._derive_status`, `EncounterSnapshotBuilder.gd:63-68`).
`FlowEncounterState.build_final_snapshot` counts `echoes_survived` as every `faction == "echo"` actor with `status != "dead"` (`FlowEncounterState.gd:132-133`)
and `total_echoes` as every such actor (`:131`). It skips actors with `is_ally` or `is_spirit` (`:129-130`).
So temporary allies and the guide spirit never count. The emotion summary tags a dead Echo `"ko"` from the same `is_dead` flag (`:295-299`).

**Downed or withdrawn. READ-FROM-CODE.** No separate "downed" state exists for Echoes in the reward path.
- `is_ko` exists only in the movement and guide-spirit code (`core/movement/MovementProfileService.gd:178-181`, `CombatRoundGuideSpiritService.gd:450`).
  It is derived as `current_hp <= 0 and not is_dead`. Combat never writes it for an Echo, and no reward code reads it.
- "Withdrawn" has no actor flag. A withdrawal is the retreat action. It ends the encounter with no win, so no stipend question arises there.
- Result: a rule "count Echoes where `is_dead == false`" matches D-45 (downed and withdrawn count as home). Use `is_dead`, not `current_hp`.

**Where a stage-ending payer reads "started" and "alive now". NOT FOUND as a stored value.**
- Looked in: `StageSettlementService.gd` (all), `FlowContext.gd`, `StageExploreModel.gd`, `ActiveStageService.gd`, grep for `stage_start|party_at|started` across `core/`. No field records the party at stage start.
- What exists: `StageSettlementService.settle` runs from `VentureController.gd:680`, before `flow_ctx.encounter_ctx = null` (`:682`). So on the combat path `flow_ctx.encounter_ctx.actors` still holds the LAST fight's actors.
  Its `is_dead` flags give "alive now" (already read this way at `StageSettlementService.gd:264-276`).
- `preview()` is called from `FlowEncounterState.gd:413` while `encounter_ctx` is also live, so both payer and preview can read the same `ectx.actors`.
- No-encounter path (a stage completed without a fight): `encounter_ctx` is null. The payer then has no actors. The party is `save_data.sanctum.active_party_ids` (`EncounterSetupService.gd:210`).
- Party at stage start vs party at the final fight: both are the same set today (see the next point). The build must add a stage-start record if D-44 needs "started" as a stored value.
  A new field on the stage dict is the natural place (the stage dict already carries `settlement_receipt`).

**Important consequence. READ-FROM-CODE. A dead Echo does not stay dead in code.** Each fight builds its Echo actors fresh from `sanctum.roster` with `EchoActor.from_echo` (`EncounterSetupService.gd:210-214`),
which sets `is_dead = false` and full HP (`EchoActor.gd:53,56`). Nothing writes the death back to the roster or removes the Echo (grep of `core/` and `ui/` finds no roster removal on death).
`CONVENTIONS.md:776` says permadeath must not ship before V2-INFRA-005. So today "started == active party size" always, and a dead Echo is back in the next fight.
The GDD 20.10 rule "Echo removed from roster" is not built. The stipend (D-43 to D-45) counts a death only for the last fight of the stage.
This also bears on D-50 and D-55 (see sections 5 and 7).

---

## 2. The opening (D-58): can the player afford Echo 2?

**A shortfall exists. READ-FROM-CODE.** No script, discount or free path makes Echo 2 cheaper than 60.

| Step | Evidence |
|---|---|
| Echo 1 is a free starter grant, no price | `OnboardingController._grant_starter_echo_for_fragment`, `OnboardingController.gd:194-240` (sets `starter_granted`) |
| The first trial pays 40 Ase, once | `KeeperIntroService.grant_trial_rewards`, `KeeperIntroService.gd:144`, `data.keeper_intro.first_trial_ase_reward` 40 |
| The awakening grants no Ase | comment at `OnboardingController.gd:345`; `data.economy.awakening_ase_grant` (40) is read only for a display field (`SanctumSnapshotBuilder.gd:408`) |
| The awakening boost pays 5 Ase per 240 s tick for 600 s: up to 12 Ase | `KeeperIntroService.apply_ase_boost_from_save`, `KeeperIntroService.gd:214-239`, formula at `:236` |
| Online accrual: 0.3 Ase per minute while the flame is awake | `data.economy.ase_online_per_min_base` |
| Echo 2 is a normal `sanctum.summon`, flat price from `ase_cost_per_summon_by_grade.uncalled` = 60 | `SanctumController.handle_summon`, `SanctumController.gd:163-176`; denied if `ase < total_cost` |

- Right after the trial the player holds 40 Ase. The 52 figure needs the boost to run its full 12 Ase, which takes about 10 real minutes in the Sanctum (the settle runs on summon, `SanctumController.gd:149-154`).
  Even at 52 the player is 8 Ase short of 60.
- The code author already recorded this: `OpeningRealmService.gd:17-24` says the player "leaves the keeper intro with exactly the 40 Ase ... against a 60 Ase summon cost", and gates the opening Realm on awakening plus first weave, not on Echo 2.
- This contradicts D-39 ("the opening Ase pays for the second Echo before stage 0"). The code does not pay for Echo 2 before stage 0. The realm can open with one Echo.
- I propose no change (as asked). Jeff decides (see OPEN).

---

## 3. Skill unlock (D-61)

**Cost is per skill, from data. READ-FROM-CODE.**
- Charge: `ProgressionController.handle_unlock_skill` reads `defn["unlock_conditions"]["ase_cost"]` (`ProgressionController.gd:431-433`), checks `can_afford_ase` (`:438`), spends with `spend_ase` (`:444`).
- Display and `can_afford`: `FlowSanctumState.gd:196-198,218` read the same key. The UI button text reads the snapshot value (`SanctumScreen.gd:831`, default 40 only if the key is missing).
- Data: `data.skills.definitions.<id>.unlock_conditions.ase_cost` = 40 for all 14 skills (checked in `data/balance.json`).
- **Changing the values needs no code.** One test checks only that the four keys exist: `tests/SkillUnlockTests.gd:61,76-79`. It does not pin 40.

**Standing per skill. READ-FROM-CODE.** Each skill already carries `unlock_conditions.min_standing`. Value is 3 for all 14 skills. Two surprises:
- Nothing reads `min_standing` to gate an unlock. `handle_unlock_skill` checks only: calling confirmed (`:393`), family accessible (`:402-420`), not already unlocked, and Ase. The grep of `core/` finds `min_standing` read only by the movement code, for a different table.
- No skill exists at Standing 6 or 9. The Sanctum constellation draws empty "ghost" slots for tiers 6 and 9 (`FlowSanctumState.gd:236-282`, `skill_id ""`, `ase_cost 0`, `can_afford false`). The tier shown on real skills is hard-coded to 3 (`:220`).

**Where a per-Standing cost would be read.** The same line, `ProgressionController.gd:433`. D-61 (60 / 90 / 120 at Standing 3 / 6 / 9) needs only data today for Standing 3: set `ase_cost` to 60 on all 14 skills.
The 90 and 120 prices need skills that sit at Standing 6 and 9. Those skills do not exist. A Standing 6/9 skill is content (a mid-game-designer task), not code.
A formula "cost by `min_standing`" would be new code at `:433` and `FlowSanctumState.gd:198`; it is not needed if each skill carries its own `ase_cost`.

---

## 4. Retreat (D-46): behaviour when funds are low

**READ-FROM-CODE.** `FlowRuntime._handle_encounter_retreat`, `FlowRuntime.gd:1164`:
- Cost is read from the action dict (`:1169`), which the snapshot baked from `data.combat.retreat_ase_cost` (default 30 in the code, `EncounterSnapshotBuilder.gd:427`; value 30 in `data/balance.json`).
- `if econ.can_afford_ase(ase_cost)` then spend; `else` log `encounter.retreat.no_ase` and **do not spend** (`:1175-1180`).
- Then the retreat roll runs and, on success, the player gets the partial Ase (`:1189` onward). So a retreat with too little Ase is **not denied and not partial: it is free.**
- The balance never goes negative: `EconomyService.spend_ase` refuses when `before < amount` (`EconomyService.gd:64-80`).
- The UI does not check the balance either. The pre-battle modal enables Retreat from `retreat_eligible` only (`CombatBoardScreen.gd:1203-1210`).
  `retreat_ase_cost` is only text in the label.
- Effect for D-46: with a price of 10, a player with under 10 Ase retreats for nothing. This is a loophole in the price. (A paid-retreat rule would need a denial path and a UI disabled state. Not proposed here.)

---

## 5. Summon price by roster size (D-55, D-59)

**Every reader of the summon price. READ-FROM-CODE.**

| Reader | File:line | Reads |
|---|---|---|
| Charge (the one that pays) | `SanctumController.gd:163-169` | `ase_cost_per_summon_by_grade[grade]` (fallback `ase_cost_per_summon`), times `count` (1 to 10) |
| Funds check, same function | `SanctumController.gd:176`, spend at `:188` | `total_cost` |
| Grade select log and `can_afford` | `SanctumController.gd:263-283` | per-grade cost |
| Summon snapshot | `FlowSummonState.gd:58-66,74-78,89` | per-grade options, `summon_disabled`, and a legacy flat `ase_cost_per_summon` |
| UI price shown | `SummonScreen.gd:62` (`_cost_each`), `:130,144-149` | the legacy flat key only, times `_count` |
| UI grade menu | `SummonScreen.gd:104-109` | Called and Chosen are locked in the UI |
| Docs text only | `OpeningRealmService.gd:21` | "60 Ase summon cost" in a comment |
| Tests | `tests/SanctumSummonTests.gd:27,283` | grade cost tests |

**Price by number of living Echoes: how to read the count.**
- `sanctum.roster` is the full list (`SummonService.gd:24-26,96-99`). Today no code removes a dead Echo from it (section 1), so `roster.size()` is the count of Echoes ever owned. It equals "living Echoes" only after permadeath is built.
- `sanctum.summon_count` is a separate counter of summons made (`SummonService.gd:42`). It never falls.
- `echo_id` is `"echo_%04d" % (roster.size() + 1)` in three places (`SummonService.gd:37,96`, `RecruitmentService.gd:227`). If dead Echoes are ever removed from the roster, new ids will repeat an old id. Permadeath must change this first.
- `SummonService.summon_paid_many` makes `count` Echoes in one call. A price that rises with the roster needs the price of each Echo in the batch (Echo n, n+1, ...), not `cost_each * count`. The UI (`SummonScreen.gd:130,144`) uses the same multiplication.
- The price is computed in three places (charge, grade select, summon snapshot) and the UI reads a fourth copy. A roster-size price needs one shared function, or the UI and the charge disagree.

**Release or dismiss action. NOT FOUND.** Looked in: `FlowRuntime.gd` dispatch table (`sanctum.*` cases at `:481-565`), `SanctumController.gd`, grep for `release|dismiss|farewell|retire|remove` across `core/`. The only "dismiss" is `ui.dismiss_summon_reveals` (a modal queue). There is no way to remove an Echo from the roster. A "village reduced regularly" (D-57) can happen today only through permadeath, which is not built.

**Recruits (ANSWERS #28). READ-FROM-CODE.** The player accepts a companion invite: `sanctum.companion.accept` (`FlowRuntime.gd:481`) calls `SanctumController.handle_companion_accept` (`SanctumController.gd:510-535`).
That calls `RecruitmentService.promote_ally_to_echo` (`RecruitmentService.gd:182`, appends at `:293`). **No Ase is spent, and there is no roster cap check.** A recruit raises the roster by 1 and so would raise the next summon price. This is consistent with D-55; flag it only so the build does not charge recruits.
Grep for `roster_max|max_roster|roster_cap|roster_limit` in `core/` and `data/balance.json`: nothing. The only cap is the party size (`data.sanctum.party_max_size` 5).

---

## 6. Removal audit lists (Phase 5.1 to 5.3)

Baseline: HEAD `4c3b3a2`. "Reader" means the key is read. "Writer" means the key is defined or produced. Story and proposal docs under `docs/stories/` are records and are listed once at the end.
Step key: **5.1** enemy, virtue, pace Ase bonus, realm-order multiplier, rank re-base. **5.2** stipend. **5.3** replay and scale.

### 6.1 `data/balance.json` (writers), at HEAD

`enemy_defeated_bonus` :1558 (5.1) · `echo_survived_bonus` :1559 (5.2, rank use 5.1) · `pace_full_ratio` :1560 (keep: rank pace term) · `pace_zero_ratio` :1561 (keep) · `pace_bonus_pct` :1562 (5.1) ·
`redo_penalty_per_run` :1563 (5.3) · `redo_penalty_floor` :1564 (5.3) · `defeat_factor` :1565 (5.1 decision) · `rank_thresholds` :1566-1572 (keep, 5.1 re-base) ·
`_comment_realm005` :1573, `virtue_bonuses` :1574, `stage_index_bonus_per` :1579, `realm_order_multiplier_base` :1580, `realm_order_multiplier_step` :1581 (all 5.1).

### 6.2 Per key: readers and step

| Key | Readers (HEAD) | Step |
|---|---|---|
| `enemy_defeated_bonus` | `RewardCalc.gd:140` | 5.1 |
| `echo_survived_bonus` | `RewardCalc.gd:141` (pay `:143`; rank ceiling in `max_possible` `:168-172`) | per-fight pay: 5.2 (moves to the stage stipend, D-44); rank use: 5.1 (home share 0.40) |
| `virtue_bonuses` | `RealmService.gd:326-327,334` | 5.1 |
| `stage_index_bonus_per` | `RealmService.gd:328` | 5.1 |
| `realm_order_multiplier_base` / `_step` | `RealmService.gd:330-331` | 5.1 removes; 5.3 adds the new realm scale (D-63) as new keys |
| `pace_bonus_pct` | `RewardCalc.gd:149`; `EncounterSetupService.gd:737`; `CombatState.gd:94`; `EncounterSnapshotBuilder.gd:293`; `PaceService.gd:153` (comment; `max_bonus_ase`, `bonus_ase`); `EncounterContext.gd:105` (comment) | 5.1. The pace state label is derived with the stage base and this pct (`EncounterSnapshotBuilder.gd:292-293`): re-derive it, do not just delete the argument |
| `pace_full_ratio` / `pace_zero_ratio` | `RewardCalc.gd:147-148`; `EncounterSetupService.gd:735-736`; `CombatState.gd:92-93`; `EncounterSnapshotBuilder.gd:292`; `EncounterContext.gd:105` | stays in 5.1: the rank pace term (0.20) still needs the curve |
| `calculate_stage_reward` | def `RealmService.gd:320`; callers `StageSettlementService.gd:197`, `FlowEncounterState.gd:182`; comments `FlowEncounterState.gd:176,372`, `RealmService.gd:401`, `EconomyService.gd:208` | 5.1 (remove the function and both callers) |
| `formula_inputs` | produced `RealmService.gd:340`; read `StageSettlementService.gd:126,204` (log line `economy.stage.reward`), `FlowEncounterState.gd:185,423`; carried `ResolveSnapshotBuilder.gd:173,177` (`add_progression`); `PendingResultService.gd:319-323,483-486` (copy into and out of the stored result) | 5.1 |
| `virtue_bonus` (key and variable) | `RealmService.gd:336,339,345`; `StageSettlementService.gd:122,129,152,186,203`; `EconomyService.gd:207,213,219,240,251-255` (param and `realm_virtue` row) | 5.1 |
| `redo_penalty_per_run` / `redo_penalty_floor` | `RewardCalc.gd:85-86` | 5.3 |
| `redo_multiplier` (function, param, result key) | fn `RewardCalc.gd:84`; result key `:197`; rank use `:157,179-182,203-204` (`_rank_for` divides the rank ratio by it); `EconomyService.gd:142,153,167,169,178` (fight pay and rows), `:205,212,219,242,250,256` (stage pay); `StageSettlementService.gd:124,202`; `FlowEncounterState.gd:229` | 5.3. Rank use needs a decision (see Surprises item 6) |
| `defeat_factor` | `RewardCalc.gd:164,182` only (the consolation 0.25 in `EconomyService.gd:169` is a hard-coded literal, not this key) | 5.1: the rank re-base decides if it stays |
| `rank_thresholds` | `RewardCalc.gd:173` | stays; 5.1 changes the ratio it is applied to |

`ui/` has no reader of any listed key at HEAD (grep of `ui/`: none). `scripts/` has none.

### 6.3 `formula_inputs` on the Resolve snapshot: who reads it

- The key is set at `ResolveSnapshotBuilder.gd:177` inside `data.progression`, called from `FlowEncounterState.gd:423`.
- **No UI reads it.** `docs/resolve-snapshot-block-spec.md:135,232` says block 12 (`formula_inputs`, `relics`, `xp_events`) is "not rendered"; grep of `ui/` for `formula` finds nothing.
- Core reads: `PendingResultService.gd:319-323` copies it into the stored result; `:483-486` restores it. The stored result is saved data, so old saves hold the key (harmless; saves are disposable).
- Tests: `tests/FlowSnapshotFingerprintTests.gd:1103,1133` pass `{ "base": 10 }` through `add_progression`; `tests/RealmRewardTests.gd:48-110` assert the key. The Resolve-snapshot fingerprints move when the key changes.
- Docs to update: `docs/resolve-snapshot-block-spec.md:63,135,232,285`; `CONVENTIONS.md:1184,1187`.

### 6.4 Tests that touch the keys (HEAD)

| File | Hits | Step |
|---|---|---|
| `tests/RealmRewardTests.gd` | 31 (whole file tests `calculate_stage_reward`) | 5.1: delete the file or its tests |
| `tests/EconomyRewardTests.gd` | 24 (config at `:39-47`; redo tests `:12-13,70-71,185-200`; pace at `:145,518-519,774`) | 5.1 and 5.3 |
| `tests/EconomyCharacterizationTests.gd` | 9 (`:56-57,142,321-340,791`) | 5.1 and 5.3 (already being edited on disk) |
| `tests/FlowSnapshotFingerprintTests.gd` | 2 (`:1103,1133`) | 5.1 |
| `tests/FlowFingerprintTests.gd` | 1 (`:485`, a comment) | 5.3 |
| `tests/RiskProbeTests.gd` (untracked) | reads `pace_full_ratio`, `pace_zero_ratio` at `:168-169` | probe only; check if pace stays |

### 6.5 Docs

Live docs: `CONVENTIONS.md:1184,1187`; `docs/resolve-snapshot-block-spec.md:63,135,232,285`.
Records (do not rewrite; they describe the past): `docs/stories/pace-reward/*` (31 hits), `docs/stories/v2-infra-003/defect-register.md` (2), and the `docs/stories/v2-economy-004/*` files.
`docs/MEMORY.md` and `ANSWERS.md`: no hits for the listed keys. Also grep `ResolveScreen.gd:167,404-408`: the UI shows an `enemies_defeated` COUNT chip. That is a summary field, not a payout row, so D-40 does not force its removal. Ask the UI session.

---

## 7. Thread rule (D-50): dead Echoes and rank

**Where the number of lost Echoes is recorded. NOT FOUND as stored data.**
- `echoes_survived` and `total_echoes` are local variables of `build_final_snapshot` (`FlowEncounterState.gd:113-133`). They go into the fight payout and the Resolve snapshot (`data.echoes_survived`, `ResolveSnapshotBuilder.gd:105`). The dead count is `total - survived`, never stored.
- The emotion summary tags each dead Echo `"ko"` (`FlowEncounterState.gd:295-299`) on the snapshot only.
- `RealmService.contribute_segment` (`RealmService.gd:281`) takes only a grade letter. It stores `{ stage_index, quality_tier }` (`:302`). No death data.

**Which value feeds Thread quality. READ-FROM-CODE.** The rank letter `data.rank` from `RewardCalc.compute` (`RewardCalc.gd:198`, put on the snapshot by `add_grade_rank`, `ResolveSnapshotBuilder.gd:75-76`; set at `FlowEncounterState.gd:418`).
- Combat path: `FlowRuntime.gd:1753-1760` passes `final_snap.data.rank` to `contribute_segment`, only on a stage-clearing victory.
- Complete-stage path: `VentureController.gd:704-712` passes the rank from the last snapshot, or `NO_COMBAT_GRADE = "C"` (`VentureController.gd:158`) when no fight happened.
- `contribute_segment` maps the letter with `data.threads.segment_quality_by_grade` (`RealmService.gd:286-288`): S and A = clean, B, C and D = compromised, F = broken.
- `ThreadService` (`core/progression/ThreadService.gd`) reads only the stored `quality_tier` strings and the tier weights (`:84-96`). It reads no `rank`, no `pace` and no Ase.

**Indirect link to Ase and pace. READ-FROM-CODE.** The rank letter is built from Ase terms: `kept = base + enemy bonus + echo bonus (+ pace bonus)` over `max_possible`, times `redo_mul` (`RewardCalc.gd:167-182,203-204`).
So pace and Ase terms reach Thread quality only through this letter. The 5.1 rank re-base (win 0.40, home share 0.40, pace 0.20) changes what each letter means for Threads.
A single death can keep rank A today (the home share is 10 Ase of a larger total), so one dead Echo can still give a clean Thread. D-50 needs a new input: a "any Echo died this stage" flag passed to `contribute_segment`, or a rank cap.
Because dead Echoes revive between fights (section 1), the flag must be recorded when the death happens, not read at stage end.

---

## Surprises

1. **A second writer is active in this checkout.** During this task, uncommitted Phase 5.1 edits appeared in 14 core files, `data/balance.json` and `tests/EconomyCharacterizationTests.gd`. My audit uses HEAD, so it stays valid, but concurrent edits can corrupt each other. The coordinator should confirm who owns the tree.
2. **Permadeath is not built.** Dead Echoes revive in the next fight and stay in the roster (section 1). The stipend counts only deaths in the stage's last fight. D-50 and the "village reduced regularly" idea of D-57 depend on code that does not exist. `CONVENTIONS.md:776` bars permadeath before V2-INFRA-005.
3. **D-39 and the code disagree.** The code does not pay for Echo 2 before stage 0 (section 2). The player is 20 Ase short after the trial, 8 short at the best case of 52.
4. **Retreat is free when the player is poor** (section 4), and the UI never checks the balance.
5. **Skill `min_standing` is data without code.** All 14 skills sit at Standing 3, no code gates on it, and no Standing 6 or 9 skill exists. D-61's 90 and 120 prices have no skill to attach to.
6. **The replay factor would also hit the rank.** Rank is `ratio * redo_mul` (`RewardCalc.gd:203-204`). If 5.3 keeps that line and sets the factor to a flat 0.35, every replay ranks C or worse and Threads on replay become compromised. D-53 says replay is for collecting better Threads. Decide before 5.3 whether rank ignores the replay factor.
7. **The summon price exists in four places** (charge, grade select, summon snapshot, UI) and the UI reads the legacy flat key. A roster-size price must come from one function. The batch buy (1 to 10) multiplies one price, which is wrong for a rising price. `echo_id` uses `roster.size() + 1` and will repeat ids once Echoes can leave the roster.
8. **`echo_survived_bonus` straddles 5.1 and 5.2.** Its rank use belongs to the 5.1 re-base. Its payment moves in 5.2. If 5.1 lands first, the per-fight echo payment must stay (or go to zero) until 5.2. The plan table does not say which.
9. **`pace_state` uses `pace_bonus_pct`.** Removing the Ase bonus in 5.1 (`EncounterSnapshotBuilder.gd:292-293`) changes how the earned or partial label is computed. Treat it as a re-derivation.
10. **`formula_inputs` has no UI reader**, so removing it is safe for the UI. It still moves the Resolve snapshot fingerprints and the saved pending result.

## OPEN — questions and assumptions

ASSUMED: The audit baseline is HEAD `4c3b3a2`, not the live tree | WHY: the live tree holds another writer's uncommitted 5.1 edits, and a stable base keeps the line numbers checkable | WRONG IF: the 5.1 edits on disk are the agreed starting point; then re-run section 6 on that tree
ASSUMED: "Home" = `is_dead == false` on a non-ally, non-spirit `faction == "echo"` actor of the last fight's `ectx.actors` | WHY: it matches D-45 and the existing survivor tally at `FlowEncounterState.gd:129-133` | WRONG IF: Jeff wants a downed Echo (HP 0 but not `is_dead`) to not count; no such state exists in combat today
ASSUMED: Step ownership of `echo_survived_bonus` and `defeat_factor` (section 6.2) follows the plan table | WHY: the plan lists no key names | WRONG IF: the build lead splits the rank re-base differently
BLOCKED: Jeff must decide the opening. The player holds 40 Ase after the first trial (52 at best) and Echo 2 costs 60 (D-39 says the opening pays for it; the code does not) | CHECKED: `OnboardingController.gd:345`, `OpeningRealmService.gd:17-24`, `KeeperIntroService.gd:144,214-239`, `SanctumController.gd:163-176`, `data.economy`, `data.keeper_intro` | NEED: Jeff's choice (D-58 said do not change the opening; report only)
BLOCKED: Does Phase 5 include building permadeath (roster removal, unique ids, V2-INFRA-005)? Without it D-43 to D-45 and D-50 work only for the last fight of a stage | CHECKED: `CONVENTIONS.md:776`, `FlowEncounterState.gd`, `EncounterSetupService.gd:210-214`, grep of `core/` for roster removal | NEED: Jeff's scope decision
BLOCKED: Should the rank ignore the replay factor (Surprise 6)? | CHECKED: `RewardCalc.gd:157,179-182,203-204`, D-53, D-54 | NEED: Jeff or sr-game-designer
BLOCKED: Where is "Echoes that started the stage" stored (new stage field, or the active party at stage entry)? | CHECKED: `StageSettlementService.gd`, `FlowContext.gd`, `StageExploreModel.gd`, `ActiveStageService.gd` | NEED: a build-plan decision for 5.2
BLOCKED: Standing 6 and 9 skills do not exist, so 90 and 120 Ase (D-61) have no target | CHECKED: `data/balance.json` `data.skills.definitions`, `FlowSanctumState.gd:236-282` | NEED: mid-game-designer content, or Jeff to approve 60 only for now
