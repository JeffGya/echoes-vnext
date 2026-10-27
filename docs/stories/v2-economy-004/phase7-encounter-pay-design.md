# V2-ECONOMY-004 Phase 7: encounter pay and the packs (design)

Author: sr-game-designer. Date: 2026-10-26. Status: OPTIONS for Jeff. Nothing here is decided.
Basis: D-04, D-13, D-22, D-28, D-44, D-62, D-65, D-72, D-89, D-104 to D-106, D-113, D-114, ANSWERS #87.
Skills used: echoes-sankofa-gdd, game-mechanics-designer.
Every number is a PROPOSED DEFAULT for `mid-game-designer`. All player text is a PROPOSAL (Jeff's word rules: no "home", no "stage"; "path", "Sanctum", "lost").
Tags: READ-FROM-CODE = taken from source. COMPUTED = my arithmetic. ASSUMED = see the OPEN block. Nothing was run.
Passive time income (`economy.settle_time`) exists. It is NOT part of the packs and NOT in any total below (D-114).

## 0. Facts read from the code

| Fact | Where |
|---|---|
| A fight is an "encounter" in the code only when the flow enters `ENCOUNTER`. That happens for a `combat` situation, for an objective situation of type combat, shrine, recover, protect, endure, pursue or guide_spirit, and for a hostile-Claimant forced fight. | `SituationResolutionService.route` (`_ASYNC_SIT_TYPES`, `_ASYNC_OBJ_TYPES`); `ContactController` claimant "failed" branch |
| All other situation types resolve in the explore view with a card, not an encounter: npc (a conversation), loot, money, omen, obstacle, ritual, structure. | `SituationEngagementService.engage_situation` |
| The encounter payer pays a WON fight 0 and has no rows. A LOST fight pays `round(fought objective weight x realm scale x defeat_factor 0.25 x replay factor)` at once, once per situation (`consolation_paid`). A lost non-objective fight pays 0. | `EconomyService.reward_encounter_complete`; `FlowEncounterState.build_final_snapshot` |
| The payer is called from `build_final_snapshot`. That builder can run more than once for one fight. Only the defeat branch has an exactly-once stamp. | `FlowEncounterState.gd` (call at ~219), `ActiveStageService.claim_situation_defeat_consolation` |
| A won fight marks its situation `resolved` through `resolve_combat_situation_and_objective`. It skips a situation that is already `resolved`. The hostile-Claimant situation is marked `resolved` BEFORE its fight starts. | `ActiveStageService.gd` ~650-700; `ContactController.gd` ~640 |
| A non-objective situation that is resolved or passed is never targeted again. A retreat-passed normal fight returns once, later (D-109). | `find_explore_target` |
| A path ends when the required objectives are done. The party does not have to visit every situation. | `_build_resolve_actions`, `ObjectiveModel.stage_completable` |
| Money situation pays 8 to 20 Ase straight into the balance. A good Claimant contact pays 20 Ase straight into the balance. Both ignore the realm scale and the replay factor. | `SituationEngagementService` (`situation.money`); `ContactController.claimant_good_ase` |
| Objective Ase and Ekwan are summed from completed, unsettled objectives at the time of the payout. Rounded once on the sum. | `StageSettlementService.settle_plan`, `EconomyService.stage_payout_rows` |
| The 6.1 settle code marks `settled` and `settled_share` on each OBJECTIVE dict, and `settled_ase`, `settled_ekwan`, `settle_count` on the stage. | `StageSettlementService.settle_leave` |
| A defeat sends the party to the Sanctum. It marks nothing settled. The path stays open, and the completed objectives stay completed and unsettled. | `_build_resolve_actions` (defeat branch), `settle()` |
| A new run (replay) builds new stage dicts through `RealmGenerator`, so marks reset. | `phase6-1-build.md` |

### Path shape (COMPUTED from the generator, not run)

| | realm.01 | realm.02 |
|---|---|---|
| Situations per path | 4 to 6 (uniform, mean 5) | 5 to 8 (mean 6.5) |
| Objective situations | 1 (one pre-boss objective; the boss stub is not a situation) | 1 or 2 (mean 1.5) |
| Other situations | 3 to 5 (mean 4) | mean 5 |
| Type pool of the others (12 slots) | combat 3, npc 2, loot 2, money 1, omen 1, obstacle 1, ritual 1, structure 1 | same |
| Normal fights available per path | mean 1.0 (4 x 3/12) | mean 1.25 |
| Money situations available per path | mean 0.33 (avg 14 Ase) | mean 0.42 |

Not every available situation is visited, because the path can end first. I use a central visit share of 0.75 (range 0.5 to 1.0). This share is ASSUMED. The build must measure it (step 7.0).

## 1. What an encounter earns

### 1.1 Ase only, or Ase and Ekwan

| Option | Rule | Verdict |
|---|---|---|
| A (pick) | Encounters pay Ase only. D-28 stays. | GDD 19.2: Ekwan is shaped matter and stored labor. No section names a fight as an Ekwan source. Ekwan sinks are rare (institutions 10 and 15, vow breaks). More Ekwan would open institutions sooner and not add a decision. |
| B | A normal fight pays a small Ekwan (1). | Fills the packs line with both currencies. Speeds institutions by about 0.75 per path. Weaker fit to the GDD. Second choice. |
| C | Ase and Ekwan by a fixed ratio | Reverses D-05 and D-28 (Ekwan is not a share of Ase). Reject. |

The row shape in section 2 carries an `ekwan` field. Pick A sets it to 0. Option B is a config change only.

### 1.2 Per kind

| Kind | In code | Is it an encounter? | Pays | Pick |
|---|---|---|---|---|
| Normal fight (combat situation, not an objective) | route "async" | Yes | New fight pay (section 2) | Pay. |
| Hostile-Claimant forced fight | claimant "failed" branch, `encounter_id` ends `.claimant` | Yes | Same fight pay | Pay the same. A failed talk must not pay more than a good one (good Claimant = 20). |
| Objective fight: combat, shrine, recover, protect, endure, pursue, guide_spirit | route "async" with `objective_index >= 0` | Yes | The objective weight, and nothing more | See 1.3. |
| Boss | stub, no situation | No | 0 (D-02) | Unchanged. |
| Contact (npc): witness, guide, charge, temporary_ally | conversation | No | 0 | No new pay. A Charge objective pays its objective weight. |
| Contact (npc): claimant, good outcome | conversation | No | 20 Ase today, straight to the balance | Moves into the packs (rule D-114). Amount unchanged. |
| Money situation | explore card | No | 8 to 20 Ase today, straight to the balance | Moves into the packs. Amount unchanged. |
| Loot | explore card | No | Items, no currency | Items join the packs later (D-114). Out of scope. |
| Omen, ritual, obstacle, structure | explore card | No | 0 | Jeff designs them after this story. |
| Thread segment | stage payout side effect | No | Not currency | Not an encounter. |

Findings on the money and Claimant rows: today they are "found Ase" paid at once. After D-114 no source may pay the balance directly. If they stay direct, the line "In their packs" would be false, and a leave would risk objective Ase but not found Ase. So they must become rows. This is a change to an existing payout. I list it as step 7.5 so Jeff can cut it.

### 1.3 The objective fight: replace, add, or sit under

| Option | Rule | Effect |
|---|---|---|
| O1 (pick) | The objective weight IS the pay of that fight. The encounter payer adds nothing for a fight with `objective_index >= 0`. | No double pay by construction. Approved weights (D-62) hold. Recorded objective totals do not move. |
| O2 | Fight pay adds on top of the weight | Every objective gets +6 to +8. Raises all baselines. Reopens D-62. Reject. |
| O3 | Split each weight into fight pay plus remainder | Same totals as O1 with more rows. Reject. |

Rule for the build: the encounter row is written only when `active_encounter_objective_index < 0`. The objective row is written when the objective completes.

### 1.4 Defeat, and what is kept

A lost fight earns nothing new. The open question is what happens to the packs. Today a defeat leaves the packs alone (section 0). Because the game has no permadeath yet, a deliberate defeat is a free exit: no escape roll, no settle roll, full packs kept. That is an exploit against the roll. The three options:

| Option | Rule | Effect |
|---|---|---|
| C (pick) | A defeat loses every unsettled row in the packs, except the defeat consolation of the fought objective (D-13, 25% of its weight). The consolation is a row marked `keep_on_defeat` and is banked by the same bank code at that moment. Rows are marked `lost`. | A defeat is always worse than a careful leave (0 against 35% on average). It teaches "leave before it breaks". The pillar says keeping Echoes alive is rewarded. Harsh at Standing 1: a new player can lose a whole path of earnings in one fight. |
| B | A defeat settles the packs by the same roll as a leave (no escape check). | No exploit gain. A defeat costs the same as a leave. Weak pillar fit: losing the fight is not worse than leaving. |
| A | Keep today's behaviour: the packs wait on the path. | No code. Leaves the free-exit exploit. Worst for the roll design. |

Normal-fight defeat pays 0 (D-22 stays). There is no consolation row for a normal fight.
This option changes behaviour that Jeff accepted in the play test (D-108 covers deaths, not packs). So it needs Jeff's pick. If Jeff does not pick, the build keeps option A and records the exploit as a follow-up.

## 2. The amount

### 2.1 Table (PROPOSED DEFAULT)

One new config group `data.rewards.encounter_weights` with one key: `fight`. Same scale rules as objectives: x realm scale x replay factor, rounded once on the scaled sum (objective rows and fight rows are summed first, then rounded once).

| Source | Row | Base Ase | Base Ekwan | Scaled by realm and replay |
|---|---|---|---|---|
| Objective (7 types) | unchanged weights | 16 / 20 / 24 / 24 / 28 / 30 / 32 | unchanged | Yes |
| Normal fight won | `fight` | **6** | 0 | Yes |
| Hostile-Claimant fight won | `fight` | 6 | 0 | Yes |
| Money situation | found | 8 to 20 (seeded, unchanged) | 0 | No (unchanged) |
| Good Claimant | found | 20 | 0 | No (unchanged) |
| Stipend | not a row | 2 per Echo, cap 10 (5 on a replay) | | Paid at the path end only, as before |

Ranked options for the fight base:

| Option | Base | Reading |
|---|---|---|
| 6 (pick) | 30% of the combat objective (20), 38% of the cheapest objective (16) | A side fight is worth clearly less than the task. Cadence stays near "one summon per 2 paths". |
| 9 | 45% of combat | A fight pays almost half an objective. Cadence drops under 2 paths from Echo 4. Risk of overflow (D-04). |
| 4 | 20% of combat | Safe for D-04. After two fights the packs show 8 Ase. The reward feels like a token. |

### 2.2 Worked totals per path (COMPUTED, party of 5, first run, visit share 0.75, no passive income)

Mean objective = (16+20+24+24+28+30+32)/7 = 24.86.

realm.01, scale 1.00:

| Part | Before | After (fight = 6) |
|---|---|---|
| Objectives (only) | 24.9 | 24.9 |
| Normal fights: 1.0 available x 0.75 visited x 6 | 0 | 4.5 |
| Found Ase (money 4.67 + Claimant 1.33 available, x 0.75) | 4.5 | 4.5 (now in the packs) |
| Stipend | 10.0 | 10.0 |
| **Total** | **39.4** | **43.9** |
| Share from encounters | 0% | 10% of the total, 13% of the packs (without the stipend) |

Range of fights visited 0.5 to 1.0: the fight part is 3.0 to 6.0 Ase.

realm.02, scale 1.25: objectives 46.6 (1.5 x 24.86 x 1.25), fights 1.25 x 0.75 x 7.5 = 7.0, found 5.6, stipend 10. Before 62.2, after 69.2. Encounter share 10%.

Replay of realm.01 (factor 0.35, stipend cap 5): objectives 8.7, fights 0.75 x 2.1 = 1.6, found 4.5 (unscaled), stipend 5. Before 18.2, after 19.8. Found Ase is 23% of a replay. Flag in section 6.

Realm.03 and later: scale 1.50, 1.75: the fight row scales with the objectives. No extra rule.

### 2.3 Against the D-04 targets (uncalled summon: first in 1 to 3 paths, then about one per 2 paths)

Party size equals Echoes owned, up to 5. Price: Echo 3 = 60, 4 = 70, 5 = 85, 6 = 100, 7 = 120. Passive income is left out here, so these numbers are lower than the paths-to-afford column in `phase5-tuning-proposal.md` (which included 3 Ase of accrual and excluded found Ase). Do not compare the two tables directly.

| Echo bought | Price | Income before | Paths before | Income after (6) | Paths after (6) | After at 9 | After at 4 |
|---|---|---|---|---|---|---|---|
| 3 (party 2) | 60 | 33.4 | 1.80 | 37.9 | 1.58 | 1.49 | 1.65 |
| 4 (party 3) | 70 | 35.4 | 1.98 | 39.9 | 1.75 | 1.66 | 1.82 |
| 5 (party 4) | 85 | 37.4 | 2.27 | 41.9 | 2.03 | 1.93 | 2.10 |
| 6 (party 5) | 100 | 39.4 | 2.54 | 43.9 | 2.28 | 2.17 | 2.36 |
| 7 (party 5) | 120 | 39.4 | 3.05 | 43.9 | 2.73 | 2.59 | 2.83 |

Reading: with fight = 6 the first summon still takes 1 to 3 paths (1.6) and the next ones stay near 2 (1.75, 2.0, 2.3). Ase stays hard: a 60 Ase skill needs 10 fights alone. The retreat (10 Ase) costs about 1.7 won fights. The fight pay does not break any sink price. At 9 the cadence drops under 2 paths for Echo 4, which weakens D-04.

### 2.4 What I drop (keep it simple)

| Dropped | Why |
|---|---|
| Pay by enemy count or kills | D-40 removed the enemy bonus because it paid for killing. |
| Pay by pace or speed | D-49: speed pays no Ase. |
| Pay by enemy tier or terrain | Needs a difficulty measure the sim does not expose. Add later if fights differ much. |
| Pay by Echoes alive in the fight | The stipend, the rank cap and the Thread already reward living Echoes. A second reward would make a death cost twice in two places. |
| Rank-based bonus | D-74: rank ignores Ase. |
| A different pay for the Claimant fight | One number is easier to read. |

## 3. Timing: the packs

### 3.1 Rule (D-113, D-114, ANSWERS #87)

Every currency earning is gathered in the packs when it is earned. Nothing pays the balance at that moment. The packs leave in one of two ways:

1. Early leave (return to the Sanctum): the 6.1 roll settles all unsettled rows at once (none, some, everything). The rest is lost.
2. Finishing the path: the stage payer banks every unsettled row, scaled and rounded once, plus the stipend. Rows settled by an earlier leave pay nothing more.

A retreat settles nothing (D-106). A defeat follows section 1.4.

### 3.2 Data shape: one list of earnings on the stage record

New stage field `earnings`: Array of dicts. It replaces the per-objective `settled` and `settled_share` marks.

| Field | Type | Meaning |
|---|---|---|
| `id` | String | Unique key and the exactly-once stamp. `obj.<index>`, `enc.<situation_id>` (a Claimant fight: `enc.<situation_id>.claimant`), `find.<situation_id>`, `contact.<situation_id>` |
| `source` | String | `objective`, `encounter`, `found`. A new source adds a value here. |
| `kind` | String | The objective type, `fight`, `money`, `claimant_good`. For the ledger row text and tests. |
| `ase` | int | Base Ase before scale. |
| `ekwan` | int | Base Ekwan before scale. |
| `scaled` | bool | true: x realm scale x replay factor. false: paid as stored. |
| `keep_on_defeat` | bool | true only for the defeat consolation (option C). |
| `settled` | bool | Set by an early leave. |
| `settled_share` | int | 0, 50 or 100. For tests and logs. Never printed. |
| `lost` | bool | Set by a defeat (option C). |
| `items` | Array | RESERVED, empty. Items join later. Jeff designs how the roll treats an item. |

Stage totals stay: `settled_ase`, `settled_ekwan`, `settle_count`.

Rules:
- The one writer is `EarningsService.add(stage, row)`. It returns false and writes nothing when the `id` exists. This gives exactly-once for fights across a reload, a repeated `build_final_snapshot`, a retry and a retreat.
- A row with 0 Ase and 0 Ekwan is not written (the boss, an unknown type that logs an error).
- An objective row is written when the objective completes. Base values are read from config at that moment.
- The rows are in save data on the stage record, so a quit and reload keeps the packs. The writer requests a save.
- A new run builds a new stage with `earnings: []`.

### 3.3 What the 6.1 code must change

| 6.1 code | Change |
|---|---|
| `settle_plan` | Iterate `earnings` where `not settled and not lost`. Sum the scaled rows (Ase and Ekwan separately), multiply by `realm_scale x replay_factor`, round once. Add the unscaled rows (integers). Return `indexes` as row ids. `overcome` and `total` still come from `objective_counts` on the objectives. |
| `settle_leave` | Mark rows (not objective dicts). The roll, the stream `stage.settle.<stage_id>.<run_count>.<settle_count>`, the Scout shift, the config check and the log stay as they are. |
| `_plan` and `settle` (stage end) | `base` and `ekwan_base` come from unsettled scaled rows. Add a `flat` input for unsettled unscaled rows. `stage_payout_rows` takes the new inputs. |
| `RewardCalc.base_reward`, `stage_ekwan`, `unsettled` | Used once to build an objective row (weight lookup). `unsettled(objectives)` goes away. |
| `ObjectiveModel` dicts | `settled` and `settled_share` removed (clean break; saves are disposable). `completed` stays: counts, "overcome" and pace read it. |
| `mark_stage_objective_completed`, `resolve_combat_situation_and_objective` | After setting `completed`, call `EarningsService.add` for the objective row. Grep for every `["completed"] = true` in the build. |
| `reward_encounter_complete` | Victory with `objective_index < 0` adds a `fight` row and returns `gathered_ase` for the card. It never calls `add_ase` on a victory. A defeat follows section 1.4. |
| `SituationEngagementService` (money), `ContactController` (claimant good) | Replace `add_ase` with `EarningsService.add` (step 7.5). |
| `StageSettlementService.preview`, `carry_home_preview` | Use the new plan. The gathered figure on the confirmation panel is the sum of all unsettled rows. |
| Tests | `settle_*` tests build their fixtures through objective dicts. They must build rows. Add the invariant test: every completed objective has an `obj.<i>` row. |

Safety net: at settle time, if a completed objective has no row, log an error and write the row then. This turns a missed hook into a visible log and not a lost payout.

### 3.4 Interaction checks

| Item | Result |
|---|---|
| Exactly-once | Row `id` is unique. Stage receipt blocks a second stage payout. Settled rows pay nothing at the path end. |
| One roll | One draw covers all unsettled rows, as in 6.1. A fight won after a leave is a new unsettled row and joins the next roll or the path end. |
| Retreat from an unfinished fight | No final snapshot, so no row. Pays nothing. Confirmed. |
| Replay factor | Applies to scaled rows at settle or bank time (fight 6 x 0.35 = 2.1). Found rows are unscaled (section 6). |
| Stipend | Not a row. Paid at the path end only (D-44). An early leave does not pay it. |
| Rank | Unchanged. See section 4. |
| Defeat | Section 1.4. |
| Mid-path card | The balance does not rise until a leave or the path end. D-25 (no mid-path preview) stays; the gathered figure shows only on the leave confirmation and on the cards that earn it. |

## 4. Rank

Encounter earnings stay OUT of the rank score (win 0.40, home 0.40, pace 0.20). Reasons: D-49 and D-74 say Ase amounts never enter the score. A fight row is Ase. If fights counted, a player could raise the rank by picking side fights, which rewards risk-taking over keeping Echoes alive. Nothing changes in `RewardCalc.rank_score`.

## 5. UI and ledger

### 5.1 Rows and causes (names for `mechanics-developer`)

| Where | Row | `cause` | `params` |
|---|---|---|---|
| Fight victory card | "Fight" +N Ase, marked as gathered | `encounter_gathered` | `{ kind, gathered_ase }` |
| Fight defeat card (normal fight) | no row | | |
| Fight defeat card (objective fight, option C) | existing consolation rows plus a lost note | `defeat_consolation`, `packs_lost` | `{ lost_ase, lost_ekwan }` |
| Situation card, money or Claimant | "Found" +N Ase, marked as gathered | `found_gathered` | `{ kind }` |
| Path-end ledger | "Base objectives" (unsettled objective rows) | `objectives_overcome` (unchanged) | unchanged |
| Path-end ledger | "Fights" (unsettled fight rows) | `encounters_overcome` | `{ count }` |
| Path-end ledger | "Found on the path" | `found_banked` | `{ count }` |
| Path-end ledger | "Redo penalty" (one row on the scaled sum) | `replay` (unchanged) | unchanged |
| Path-end ledger | "Echoes home" | `echoes_alive` (unchanged) | unchanged |
| Path-end ledger | memo "Settled when you left" | `settled_on_leave` (unchanged) | unchanged |
| Return card | outcome line and `+N Ase` / `+N Ekwan` | `settle_*` (unchanged) | unchanged |

Rule from 3c: the sum of the rows must equal the payout. The "Fights" and "Found" rows keep that, because each is a sum of unsettled rows.
`ase_awarded` on a combat victory stays 0 (nothing reaches the balance), so the existing `add_ledger(ase_awarded)` shape holds. A new key on the resolve snapshot carries the gathered fight pay (`gathered_ase`).

### 5.2 What the confirmation panel shows

The same D-107 gathered line, now with the sum of all unsettled rows:
`In their packs: <Ase> Ase and <Ekwan> Ekwan.` (Jeff's words.) No split by source on the panel. No odds.
If only a fight is in the packs, the panel still shows the line. This fixes play test C.

### 5.3 "Nothing overcome yet"

It applies only when the packs hold no unsettled row AND nothing was settled earlier AND no objective is completed. A won fight, a found item of Ase and a completed objective all create a row, so the old row no longer shows after a won fight. D-110 F1 is unchanged: no outcome line on an empty leave.
Proposal for Jeff: the row text itself is an older placeholder. Option text: PROPOSAL "Nothing was gathered."

### 5.4 Copy (PROPOSAL; Jeff's words win)

| Surface | PROPOSAL |
|---|---|
| Fight victory row label | "Fight won" |
| Fight victory tooltip | "It goes in their packs. The Sanctum gets it when the path is done." |
| Money situation line | "They found 12 Ase. It goes in the packs." |
| Claimant good line | "She gave them 20 Ase for the way. It goes in the packs." |
| Path-end row "Fights" | "Fights won" |
| Path-end row "Found" | "Found on the path" |
| Defeat card note (option C) | "The packs were lost." |
| Defeat tooltip | Jeff's D-111 #10 stays for objective fights: "This one was lost, but we still earn a small part." |
| Empty return row (5.3) | "Nothing was gathered." |

The words "banked", "settled" (outside the memo row Jeff kept), "gathered" and "roll" are not used in player text. "Packs" is Jeff's word.

## 6. Exploit and risk check

| Attempt | Result |
|---|---|
| Leave and re-enter to repeat fights | A won fight is `resolved` and never targeted again. Its row id exists, so a repeat writes nothing. |
| A passed fight pays again on a revisit | It pays once, on the first win. A passed fight has no row until it is won. |
| Retreat and return | A retreat writes no row. The returned fight pays once at the win. Cost: 10 Ase and a turn. |
| Lose a fight, retry | Victory only writes the row. A defeat of a normal fight writes none. One win, one row. |
| Repeat the same win by reload | `build_final_snapshot` may run again. `EarningsService.add` is idempotent. |
| Hostile-Claimant fight pays twice (talk then fight) | Different ids (`contact.` and `enc....claimant`). The fight is the failed branch, so a good-contact row cannot exist for the same situation. |
| Farm side fights on a replay | 2 Ase per fight at realm.01 (6 x 0.35). Poor. Holds D-53. |
| Farm found Ase on a replay | Found rows are unscaled (money 8 to 20, Claimant 20). On a replay they are 23% of the income. The tooltip "All of it earns less" (D-111 #5) is false for them. Options: keep unscaled (pick for this story, no recorded value moves), or give found rows `scaled: true` (moves the money and Claimant tests). Jeff decides. |
| Deliberate defeat as a free exit | Open under option A. Closed by option C. |
| Settle roll gamble with fights | A fight is worth 6. The roll costs 65% in expectation. Banking a fight early is a bad rate. Same as objectives. |
| Money no longer pays at once | The player cannot use found Ase to pay the retreat (10) inside the path. Retreat is denied when the balance is short (D-79). Minor. Flag for the play test. |

Failure modes by Standing:
- Standing 1: the party has 2 Echoes and about 0 Ase. A won fight puts 6 in the packs, which the player cannot spend. The pay is only felt after the path. Risk: the fight pay is invisible until then. The Resolve card line (5.4) and the leave panel carry it.
- Standing 6: fights are 2% of the price of Echo 10 (210). Meaningless on its own. The pay is a floor, not a lever.
- Standing 9: same. The realm scale lifts it. No special case.
- A player who never reads the card: the packs are summed on the leave panel and the path-end ledger. Nothing is lost by not reading.

Pillar check:
- Legible without a raw ID: yes. One word, "packs".
- Survives a player who never reads: yes.
- Produces a decision: yes. A side fight pays a little and risks Echoes and fear. The leave roll then taxes holding a full pack.
- Interacts with fear: the fight is where fear rises. The pay does not bypass it.

## 7. Recorded values and tests that move (list only; nothing was run)

| Group | Prediction |
|---|---|
| `data/balance.json` | Add `data.rewards.encounter_weights.fight`. No existing key changes. |
| `tests/EconomyCharacterizationTests.gd` | `settle_*` tests (fixtures on objective dicts); encounter payer tests (~lines 185, 1168, 1499); stage payer matrix rows (new "Fights" and "Found" rows). |
| `tests/EconomyRewardTests.gd` | `reward_encounter_complete` calls (~188, 231, 423, 869): victory now returns gathered Ase. |
| `tests/ResolvePayoutUITests.gd` | Payout row labels; gathered line; the empty-leave row. |
| `tests/VentureCharacterizationTests.gd`, `tests/RetreatTests.gd`, `tests/PendingResultTests.gd` | Money and Claimant paid at once (assertions on the balance); defeat behaviour (option C). |
| Fingerprint suites (`FlowFingerprintTests`, Seek copies) and `combat_baseline`, `combat_roundtrip` | The resolve snapshot of a normal-fight victory gains a ledger row and a key. FINAL hashes of victory modes may move. Predict one cause. |
| `snapshot` suite key lists | New resolve key (`gathered_ase`) and a new stage-record key list. |
| Save repair tests | Default `earnings: []` on stages. |
| New tests | Row idempotence; fight not paid twice for an objective fight; Claimant fight id; settle covers all sources with one roll; leave then fight then path end pays only the new row; replay resets rows; defeat option C; item field empty; invariant "completed objective has a row". |

## 8. Build plan (backend before UI)

| Step | Work | Files |
|---|---|---|
| 7.0 | Measure: normal fights available and visited per path, and money situations visited, on real generated realms (RUN REQUEST to the main chat). Confirms the 0.75 visit share. | a probe under `tests/` |
| 7.1 | Config and design numbers. `mid-game-designer` authors `encounter_weights.fight`. | `data/balance.json`, `RewardCalc.cfg_num` readers |
| 7.2 | Stage model field `earnings: []`, save repair default, `EarningsService` (add, plan, mark, lost) as pure statics. | `core/realms/StageModel.gd`, `core/save/SaveService.gd`, new `core/economy/EarningsService.gd` |
| 7.3 | Move objectives to rows (hooks, plan, leave, stage payer, preview). Re-run the 6.1 tests to prove no total moved (worked example 74 must hold). | `StageSettlementService.gd`, `EconomyService.gd`, `RewardCalc.gd`, `ActiveStageService.gd`, `ObjectiveModel.gd` |
| 7.4 | Encounter payer: victory row, defeat per Jeff's pick. | `EconomyService.reward_encounter_complete`, `FlowEncounterState.gd`, `ActiveStageService.claim_situation_defeat_consolation` |
| 7.5 | Found Ase into rows (money, Claimant good). Optional: Jeff may cut. | `SituationEngagementService.gd`, `ContactController.gd` |
| 7.6 | Snapshots: gathered key, ledger rows, `carry_home_preview` total, `PendingResultService` replay of the new key. | `ResolveSnapshotBuilder.gd`, `VentureResolveSnapshotBuilder.gd`, `PendingResultService.gd` |
| 7.7 | Tests and re-records with attribution (RUN REQUEST). | tests listed in section 7 |
| 7.8 | UI: rows, situation-card wording, panel line, empty-row condition. Jeff picks copy. | `ui/` Resolve and confirmation screens |
| 7.9 | Docs: `decisions.md`, `ANSWERS.md` if needed, `CONVENTIONS.md`, `integration-map.md`, follow-ups. QA by a different agent. | docs |

Risks:
1. A missed objective-completion hook loses a payout. Mitigation: grep for every `["completed"] = true`, the invariant test, the settle-time safety net.
2. Moving objectives into rows touches the 6.1 worked example and many tests. Mitigation: do 7.3 alone, prove no total moves, then add the new sources.
3. `build_final_snapshot` mutates save data and can run twice. Idempotent rows cover it. A cleaner fix (move payment into the dispatch step) is out of scope.
4. Option C is a behaviour change that Jeff has not seen. Do not build it without his pick.
5. Money no longer reaches the balance mid-path. Play test.
6. The 0.75 visit share is a guess. Step 7.0 can change the pick for the fight number.

Not covered here: other encounter kinds (omen, ritual, obstacle, structure, contact roles) and item rows. Jeff designs them after this story (D-114, follow-up 48). The shape in 3.2 takes them as new `source` values.

## 9. Kinds that exist in the code (list for the follow-up)

| Group | Values | File |
|---|---|---|
| Situation types | combat, npc, loot, money, omen, obstacle, ritual, structure | `SituationModel.gd` |
| Pool weights (of 12) | combat 3, npc 2, loot 2, money 1, omen 1, obstacle 1, ritual 1, structure 1 | `SituationModel.SITUATION_TYPE_POOL` |
| Objective types | combat, shrine, recover, protect, endure, pursue, guide_spirit, boss (stub) | `ObjectiveModel.gd` |
| Contact roles | witness, guide, charge, claimant, temporary_ally | `data.contact.roles` |
| Contact outcomes | good, partial, failed | `data.contact.outcome_thresholds` |
| Ways to enter ENCOUNTER | combat situation; objective situation; hostile-Claimant forced fight; (a failed non-objective Charge adds pressure to the next protect or endure fight) | `route`, `ContactController` |
| Panel kinds of explore cards | acknowledge (omen, npc), take (loot, money), leave (ritual), choice (obstacle, structure) | `data.stages.situation_resolution` |
| Currency sources outside objectives today | money 8 to 20, good Claimant 20, defeat consolation, passive time income | see section 0 |
| Item source today | loot kinds: herb_bundle, cloth_scrap, carved_token (stored in `explore_map.loot_results`) | `data.stages.situation_resolution.loot` |

## 10. GDD conflicts (listed, not edited)

| GDD item | Result |
|---|---|
| 19.2 Ase: "paid when the player performs actions that animate, invoke, shape... " and the uses list (summoning, rites, Thread handling) | Not a conflict. The text names Ase uses, not Ase sources. The GDD names no fight as an Ase source. If Jeff wants it, add one line. |
| 19.2 Ekwan: shaped matter, stored labor | Pick 1.1 A keeps fights Ekwan-free. Option B would need a line. |
| 20.8: an unresolved path keeps its locked instance; reruns preserve what the player learned | No conflict. Rows follow the stage instance. |
| 20.10: "retreat from the stage map with intel", "no-battle return with useful information" | Intel still returns. Currency in the packs is taxed by the roll (already decided in D-104 to D-106). |
| 20.10 / 20.17 death and failure | Option C makes a defeat worse than withdrawal. This fits the GDD intent but is not written there. |
| 21.1 early economy | Cadence is open in the GDD. The numbers here are Jeff's to set. |
| D-25 (no mid-path preview) | The leave panel and the cards show gathered amounts. Jeff already allowed the panel (D-102). Confirm the fight and found lines on the cards. |
| D-22, D-89 | Reversed for the normal fight by D-113. D-28 is kept. |
| D-72 rule 4, D-111 #5 (tooltip "All of it earns less") | Found rows break the tooltip on a replay unless they are scaled (section 6). |
| ANSWERS #87 / D-114 | Met by 3.2: no source pays the balance. The defeat consolation is the one place that needs the bank code at the moment of defeat (option C). |

## OPEN — questions and assumptions

ASSUMED: Visit share 0.75 of the normal fights and money situations that exist on a path (range 0.5 to 1.0). | WHY: the path ends when the required objectives are done, so not every situation is visited; no measure exists. | WRONG IF: the party visits nearly everything or almost nothing. The totals in 2.2 and 2.3 shift by up to 1.5 Ase per path. Step 7.0 measures it.
ASSUMED: One in five contacts is a Claimant and half of Claimant talks end good. | WHY: five roles, no weights found in the code I read. | WRONG IF: the role draw is not uniform. It changes "found Ase" by about 1 Ase per path.
ASSUMED: A defeat leaves the path open and the packs unsettled today, as I read `settle()` and the defeat branch of `_build_resolve_actions`. | WHY: the defeat card only goes to the Sanctum and nothing marks the stage failed. | WRONG IF: a defeat resets or closes the path somewhere I did not read. Then the exploit in 1.4 is smaller.
ASSUMED: Fight Ase takes the realm scale and the replay factor; found Ase does not (as today). | WHY: matches objectives and the 5.15 comment. | WRONG IF: Jeff wants "all of it earns less" to include found Ase.
ASSUMED: The Ekwan field exists on every row and is 0 for fights. | WHY: D-28. | WRONG IF: Jeff takes option 1.1 B.
ASSUMED: Writing the fight row inside `build_final_snapshot` (where the payer lives today) is acceptable. | WHY: smallest change; the row is idempotent. | WRONG IF: `mechanics-developer` says the builder runs on a path that has no combat result.
BLOCKED: Defeat option: C (lose the packs, keep the consolation), B (roll), or A (leave as today)? | CHECKED: D-105, D-106, D-108, `_build_resolve_actions`, `StageSettlementService.settle`. | NEED: Jeff's pick. Default if none: A, with the exploit logged as a follow-up.
BLOCKED: Fight base 6 (pick), 4 or 9? | CHECKED: `phase5-tuning-proposal.md` cadence table, `balance.json`. | NEED: Jeff, after step 7.0 gives the visit share.
BLOCKED: Do found Ase (money, good Claimant) join the packs in this story (step 7.5), or later? | CHECKED: D-114 says "all currency from any source". | NEED: Jeff. I recommend now, or the packs line is false.
BLOCKED: Do found rows take the replay factor? | CHECKED: `contact_claimant_good_comment` in `balance.json`, D-111 #5. | NEED: Jeff.
BLOCKED: Is the middle word of the empty return row ("Nothing was gathered.") acceptable, and the other PROPOSAL lines in 5.4? | CHECKED: D-107, D-111. | NEED: Jeff (player copy is his).
BLOCKED: How does the roll treat an item row later (whole item carried or lost; share of a stack)? | CHECKED: D-114, ANSWERS #87. | NEED: Jeff, in the follow-up on items. The `items` field is reserved only.
BLOCKED: Does a retreat-denied player who held found Ase lose a useful retreat? | CHECKED: D-79. | NEED: a play test.
