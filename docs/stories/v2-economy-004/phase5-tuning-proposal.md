# V2-ECONOMY-004 Phase 5 — Tuning proposal (round 4, sr-game-designer)

Written in STE. Every number is a PROPOSAL. Jeff approves line by line. Nothing is in `data/balance.json`. No code was run.
Tags: READ = from a file I opened. COMPUTED = my arithmetic (scratch script outside the repo; Godot `roundi` rounding). ASSUMED = not verified.
Rank order of options follows D-48: game quality (clear, engaging, fun, Echoes pillar). Build cost is only in section 10.
Inputs: D-36 to D-55, `phase5-design-advice.md`, `phase5-feel-review.md`, `phase5-echoes-alive-recheck.md`, `phase5-risk-and-rank.md`, `data.rewards`, `data.summoning`, `data.skills`, `data.economy`, `data.sanctum`, `data.combat`, `data.vows`, `data/realms.json`.

## 0. Common assumptions (used in every table)

| # | Assumption | Tag |
|---|---|---|
| 1 | Realm.01 stage: 1 pre-boss objective, drawn about evenly from the 7 types (Phase 1: 98 to 120 of 700 per type). Realm.02 stage: 1.51 objectives on average (Phase 1: 611 of 1187 stages have 2). | READ |
| 2 | The player takes the biggest party it can: party = min(roster, 5). `data.sanctum.party_max_size` = 5. | READ / ASSUMED |
| 3 | A stage takes about 10 minutes in realm.01 and 15 in realm.02 (more objectives). Online accrual 18 Ase per hour gives 3 and 4.5 Ase per stage. | ASSUMED |
| 4 | The player enters stage 0 with about 0 Ase and the opening has bought Echo 2 (D-39). "Echo 3" is "the first summon after the opening". | READ (D-39) |
| 5 | Stage Ase = objective weights (x realm scale) + stipend (2 per Echo alive in the party, cap 10; D-43, D-44). No enemy, virtue or speed Ase (D-40, D-49). All Echoes survive (no losses) unless said. | READ |
| 6 | First run of a realm unless the table says "replay". Replay: objective Ase and Ekwan x 0.35, stipend halved (1 per Echo, cap 5) (D-53, D-54). | READ |

## 1. Objective Ase weights (all 7 types)

PROPOSAL: Set B x 2. This keeps the Set B order (D-09) and the pace-reward ratios, and gives the income the cadence needs (section 3).

| Type | Today (set B) | PROPOSAL (x2) | Stage Ase, realm.01, party of 2 (weight + 4) |
|---|---|---|---|
| pursue | 8 | 16 | 20 |
| combat | 10 | 20 | 24 |
| recover | 12 | 24 | 28 |
| protect | 12 | 24 | 28 |
| endure | 14 | 28 | 32 |
| shrine | 15 | 30 | 34 |
| guide_spirit | 16 | 32 | 36 |
| boss | 0 | 0 | 0 |

COMPUTED: mean weight over the 7 types = 24.9. Pool mean stage Ase, realm.01, party of 2 = 24.9 + 4 = 28.9.

Phase 1 fixture run (`guide_spirit`, `protect`, `combat`, `combat`; party of 2; first run; no accrual):

| Stage | Arithmetic | Stage Ase | Running total |
|---|---|---|---|
| 0 `guide_spirit` | 32 + 4 | 36 | 36 |
| 1 `protect` | 24 + 4 | 28 | 64 |
| 2 `combat` | 20 + 4 | 24 | 88 |
| 3 `combat` | 20 + 4 | 24 | 112 |

Run total 112 = 28 per stage. Today (all bonuses, set B) the same run pays 258. Round 1 targeted 24 to 30 per stage: this meets it.
Replay of the same run (COMPUTED: roundi(weight x 0.35) + 2 x 1 per stage): 13 + 10 + 9 + 9 = 41 = 10 per stage, 37% of the first run.

Stages to afford the first uncalled summon (Echo 3, price 60) from about 0 Ase. Whole stages; stage Ase from the table above; "with accrual" adds 3 Ase per stage (assumption 3):

| Stage type repeated | Cumulative Ase after stage 1 / 2 / 3 | Stages (no accrual) | Stages (with accrual) |
|---|---|---|---|
| pursue (20) | 20 / 40 / 60 | 3 | 3 (23 / 46 / 69) |
| combat (24) | 24 / 48 / 72 | 3 | 3 (27 / 54 / 81) |
| recover, protect (28) | 28 / 56 / 84 | 3 | 2 (31 / 62) |
| endure (32) | 32 / 64 | 2 | 2 |
| shrine (34), guide_spirit (36) | 34 / 68, 36 / 72 | 2 | 2 |
| fixture run | 36 / 64 | 2 | 2 |
| pool mean (28.9, with accrual 31.9) | | 3 | 2 (31.9 / 63.8) |

Reading: Echo 3 arrives in 2 stages for most draws and in 3 for the cheapest types (pursue, combat). That meets "1 to 3 stages". One stage is not possible with these weights, because stage 0 pays at most 36. Reaching 60 in one stage would need weights of about 3.5 x set B (COMPUTED: 60 − 4 = 56 over a 16 weight). That would break the "then one per 2 stages" cadence. I do not advise it.

## 2. Realm scale (D-55)

PROPOSAL: a fixed per-realm scale on objective Ase and objective Ekwan. It does not touch the stipend (cap 10). It stacks with the replay factor: objective Ase = roundi(sum of weights x realm scale x replay factor), rounded once on the stage sum (ASSUMED stacking order).

| Realm | Scale | Reason |
|---|---|---|
| realm.01 | 1.00 | Anchor. |
| realm.02 | 1.25 | "Later realms pay more" (D-55) with the pay per MINUTE only slightly higher, not per stage. |

COMPUTED, party of 5, no replay, accrual included (assumptions 1 and 3):

| Realm.02 scale | Objectives per stage (24.9 x 1.51 x scale) | Stage income (+ stipend 10 + accrual 4.5) | Per 10 minutes of play | Against realm.01 (37.9 per stage, 37.9 per 10 min) |
|---|---|---|---|---|
| 1.00 | 37.5 | 52.0 | 34.7 | 0.92 x per minute |
| 1.25 (PROPOSAL) | 46.9 | 61.4 | 40.9 | 1.08 x per minute |
| 1.50 | 56.3 | 70.8 | 47.2 | 1.25 x per minute |

Reading: at 1.00 realm.02 pays less per minute than realm.01 although it is "later". At 1.25 it pays 8% more per minute and 62% more per stage. At 1.50 the house fills too fast (section 3). The per-stage jump (38 to 61) is mostly the second objective, not the scale. Player-facing: a stage with two objectives shows two rows of pay, so the jump is readable.

Rule for later realms (PROPOSAL): scale = 1 + 0.25 x (realm position − 1), so realm.03 = 1.50, realm.04 = 1.75. Rule applies to objective Ase and Ekwan only. Re-check it when realm.03 stage counts and objective counts exist (not designed). The position is the realm's fixed place in `realm_order` (data), not the order the player starts them. Today's multiplier depends on the start order; the new rule does not.

Ekwan (COMPUTED): Set B mean = 3.57 per objective. Realm.01 stage 3.6, realm.02 stage 3.57 x 1.51 x 1.25 = 6.7. Fixture run first time 3 + 3 + 2 + 2 = 10; replay about 0.35 of that, rounded once per stage. Hearth (10) takes 3 stages in realm.02. Set B still fits (round 1 section 5).

## 3. Summon price by roster size (D-55)

### 3.1 What the game wants: population range (GDD gap, question)

READ, what the GDD says:
- §18.8 (lines 3325 to 3335): high Continuity is possible in a small house and in a large house; "population count alone" should not define maturity; the player should not be forced into "one ideal population model".
- §20.8 "Current generation model" (lines 3867 to 3881): Realm difficulty scales mainly with completed Realm count; roster and house strength are only a "secondary smoothing factor".
- §20.17 (line 4338) and §14.3: permadeath is core; deaths lower Thread quality.
- `data.sanctum.party_max_size` = 5 is the only number about group size. The GDD names no roster target, no house capacity and no population limit. The "exact reserve capacity" open item (line 2225) is about Threads, not Echoes. §21.1 leaves the summon cost open.

QUESTION for Jeff: what population range does the game want? Options, ranked by game quality:

| Option | Range | Feel | Price curve (ratio per Echo) |
|---|---|---|---|
| P-A (recommended) | Comfortable 7 to 10; soft ceiling about 12 | A house you can know. 5 in the party, 2 to 5 at home. Rotation after injury and death is possible. 10 Echoes have 45 pairs of bonds (n x (n−1) / 2), 7 have 21. Each Echo still gets story attention. The player feels the house getting "full" at 9 to 10: a new face is a decision, not a habit. | x1.2 |
| P-B | Small 5 to 7 | Tight family. Every Echo matters, the party is nearly the whole house, permadeath hurts most. Little room to rotate. Risk: one bad run leaves the party short and the house empty (replacement price must fall when the roster falls). | x1.35 |
| P-C | Large 12 to 16 | A village. More social variety. Price is a light brake only. Risk: attention thins, the bond graph (66 pairs at 12) outgrows what the player can read, Echoes become units (pillar fails). | x1.1 |

I recommend P-A. Reasons (game quality): the pillar is attachment and growth over time. A house the player can hold in mind keeps each Echo a person. A price that slows but never stops growth keeps the choice open (GDD §18.8: no single ideal). At 10 Echoes the player has about 2 reserves, which makes a death survivable without making Echoes disposable.

### 3.2 The curve (P-A)

Rule (PROPOSAL): the price of the NEXT uncalled summon depends on the number of LIVING Echoes on the roster before the summon. Echo 3 = 60 (D-36, D-37). From Echo 4: round-to-5 of 70 x 1.2^(k − 4).
Counted roster: every living Echo on the roster, in the party or not. A dead Echo does not count (D-45 "home" = not dead), so a death lowers the price of the next Echo: rebuilding after a loss is cheaper. A recruited Echo (the earned return, ANSWERS #28) counts but is not priced.

Stage income used: realm.01 for Echo 3 to 6, realm.02 for Echo 5 to 12 (a player with 4 Echoes has played about 4 stages of realm.01). Both are shown; use the one that matches the player's place. COMPUTED: income = 24.9 (x realm factor) + stipend 2 x min(roster, 5) + accrual.

| Echo # | Roster before | Price (uncalled) | Cumulative price | Realm.01 income | Stages to afford, realm.01 | Realm.02 income | Stages to afford, realm.02 | Stages to afford, REPLAY of realm.01 (income 13.7 to 16.7) |
|---|---|---|---|---|---|---|---|---|
| 3 | 2 | 60 | 60 | 31.9 | 1.9 | 55.4 | 1.1 | 4.4 |
| 4 | 3 | 70 | 130 | 33.9 | 2.1 | 57.4 | 1.2 | 4.8 |
| 5 | 4 | 85 | 215 | 35.9 | 2.4 | 59.4 | 1.4 | 5.4 |
| 6 | 5 | 100 | 315 | 37.9 | 2.6 | 61.4 | 1.6 | 6.0 |
| 7 | 6 | 120 | 435 | 37.9 | 3.2 | 61.4 | 2.0 | 7.2 |
| 8 | 7 | 145 | 580 | 37.9 | 3.8 | 61.4 | 2.4 | 8.7 |
| 9 | 8 | 175 | 755 | 37.9 | 4.6 | 61.4 | 2.9 | 10.5 |
| 10 | 9 | 210 | 965 | 37.9 | 5.5 | 61.4 | 3.4 | 12.6 |
| 11 | 10 | 250 | 1215 | 37.9 | 6.6 | 61.4 | 4.1 | 15.0 |
| 12 | 11 | 300 | 1515 | 37.9 | 7.9 | 61.4 | 4.9 | 18.0 |

(Replay column: 0.35 x 24.9 + 1 per Echo in the party (cap 5) + 3 accrual = 13.7 at party 2, up to 16.7 at party 5.)

Reading:
- Early cadence holds. Echo 3 takes about 2 stages from about 0 Ase. Echo 4 takes about 2 stages in realm.01. That is "first summon in 1 to 3 stages, then about one per 2" (D-36, D-39).
- In realm.02 (where Echo 5 and later usually happen) the cadence is 1.4 to 2.4 stages for Echo 5 to 8, then slows to 3 to 5 stages for Echo 9 to 12. The house visibly fills.
- A full realm.02 run (6 stages, 61 each = 366 Ase) buys about 3 Echoes at Echo 7 to 9, 1.5 at Echo 10 to 11. COMPUTED: from Echo 3 to Echo 12 the price sum is 1515 = about 25 realm.02 stages = about 4 runs.
- Replay does not grow the house: 4 to 18 stages per Echo (D-53: replay is for mastery, Threads and story).
- Whole-stage view: the player thinks in whole stages. "2.4 stages" means 2 stages if the stage drew a high weight, 3 if not. Carry-over of unspent Ase averages this out.

Alternative curves (same method, for the options in 3.1; stages to afford in realm.02):

| Echo # | P-B (x1.35) price / stages | P-C (x1.1) price / stages |
|---|---|---|
| 5 | 95 / 1.6 | 75 / 1.3 |
| 6 | 130 / 2.1 | 85 / 1.4 |
| 8 | 235 / 3.8 | 100 / 1.6 |
| 10 | 425 / 6.9 | 125 / 2.0 |
| 12 | 770 / 12.5 | 150 / 2.4 |

Reading: P-C never slows below 2.4 stages, so it does not regulate. P-B reaches 12 stages per Echo at Echo 12: a brick wall that makes Echo 8 to 9 the practical end.

### 3.3 Called and chosen

Today: called 150 (2.5 x 60), chosen 400 (6.7 x 60). Two ways to make them rise with the roster:

| Option | Rule | Called at Echo 3 / 8 / 12 | Chosen at Echo 3 / 8 / 12 | Feel |
|---|---|---|---|---|
| X (recommended) | Same roster price + a fixed premium for choice. Called premium +90, chosen premium +340. | 150 / 235 / 390 | 400 / 485 / 640 | Readable: "choosing costs a fixed 90 more". Both stay a special case but never become out of reach. |
| Y | Multiply: called 2.5 x, chosen 6.7 x the uncalled price | 150 / 363 / 750 | 400 / 967 / 2001 | Late called and chosen are out of reach (chosen at Echo 12 = 33 realm.02 stages). The house is full anyway, but a Y player can never "reach" a hero Echo late. Feels like a wall. |

Reason for X: a late called summon (a chosen calling) is the player's reward for a mature house, not an extra brake on top of a brake. Roster price already regulates the count. The premium regulates the rarity. COMPUTED stages of pure saving at realm.02 income 61.4: called at Echo 8 = 235 / 61.4 = 3.8 stages; chosen at Echo 8 = 485 / 61.4 = 7.9 stages. In realm.01 early: called 150 / 31.9 = 4.7 stages, chosen 400 / 31.9 = 12.5 stages. D-37 asks for "much larger" than 2 stages. X meets it (4 to 8 stages of pure saving; 8 to 12 real stages when the player also spends on uncalled and skills; round 1 proposed 8 to 12 and 25 to 40). Chosen at 400 early is 12.5 stages of pure saving: lower than my round 1 range of 25 to 40. If Jeff wants chosen rarer, raise the chosen premium (PROPOSAL range 340 to 800). Jeff decides.

The price counts living Echoes the same way (3.2). The rule is one function: `price(grade, roster) = curve(roster) + premium(grade)`.

## 4. Skill unlock cost

READ: skills are paid per Echo per skill (`ProgressionController.handle_unlock_skill`). They need `min_standing` 3 and a calling-aligned family. GDD §19.2 "Ase" (lines 3456 to 3475) lists summoning, rites and Thread handling as the primary Ase uses. It does not list skill unlocks. GDD gap, question 3.

PROPOSAL: price by milestone, independent of roster size.

| Milestone | Today | PROPOSAL | Stages to afford, realm.01 (37.9) | Stages, realm.02 (61.4) |
|---|---|---|---|---|
| Standing 3 skill | 40 | 60 | 1.6 | 1.0 |
| Standing 6 skill | 40 | 90 | 2.4 | 1.5 |
| Standing 9 skill | 40 | 120 | 3.2 | 2.0 |

A full kit of 3 skills costs 270 Ase per Echo, which is 4.4 realm.02 stages.

How price and roster interact (COMPUTED, section 3.2 curve):
- Skill price does NOT rise with roster. Reason: skills are Echo growth (pillar). Making growth dearer for a large house would punish the player for caring about every Echo.
- The summon price rises. So breadth gets dearer and depth stays flat. The crossover: Standing 9 skill (120) equals Echo 7 (120); from Echo 8 (145) a deep skill is cheaper than a new face. The economy then pulls the player from breadth to depth around Echo 7 to 8. That serves "Echo growth over time beats simplicity" and gives the price curve a natural stopping point near 8.
- Skills cannot block Echo growth: the Standing gate (3 / 6 / 9) already spreads the demand over play time. At 10 Echoes, 30 skills would cost 2700 Ase (COMPUTED: 10 x 270), but no player holds 10 Echoes at Standing 9 together. Demand arrives one Echo at a time.
- Early (Standing 3 with the first Echo): 60 = the price of Echo 3. The player chooses between a second Echo and a skill. That is a real choice and it stays real.

Optional (Jeff): tier price without code, because `ase_cost` is already per skill (READ; mechanics-developer confirms).

## 5. Retreat and vow-break prices

Retreat (D-46): about 10 Ase. COMPUTED against stage income: realm.01 29 to 38 per stage, so 10 is 26 to 35% of a stage; realm.02 61, so 16%. The partial after the first win is 12% x completed weight (D-14): 12% x 24.9 = 3 Ase (D-14 pays 0 before a win). A retreat before a win is a net −10; after a win about −7. Compare a defeat: consolation 25% of the fought weight = 5 (combat) to 8 (`guide_spirit`) Ase, and the Echoes are at risk. The retreat price is the price of protecting people. It is a fair, visible choice. PROPOSAL: 10, as D-46. Keep it flat (not tied to roster): the more Echoes at risk, the more the player should retreat, so the price must not rise.

Vow-break Ase prices (READ): `tikoro_nko_agyina` 60 / 120 / 250 / 500; `praye_wokabomu` 60 / 120; `obi_nnim_kyere` 60 / 100. COMPUTED stages to afford, realm.01 / realm.02: 60 → 1.6 / 1.0; 100 → 2.6 / 1.6; 120 → 3.2 / 2.0; 250 → 6.6 / 4.1; 500 → 13.2 / 8.1.
- Tiers 1 to 3 (60 to 250) read as a heavy decision: 1 to 7 stages. They compete with an Echo at the same price. This keeps a vow break serious.
- Tier 4 (500) is 8 realm.02 stages, more than two Echoes at Echo 8. That fits a vow broken at the deepest level. PROPOSAL: keep all vow prices. Whether a vow break is a goal or a penalty is still open (D-32); the price table does not decide it.
- Flag (READ, Phase 1 section 6): `VowService.spend_ase` denies the whole spend when funds are short, so a broke player pays nothing. Not fixed here; report only.

## 6. Accrual

READ: online 0.3 per minute = 18 per hour; at most 18 per settle (3600 s). Offline: about 18 per return, at most about 31, only after the Ase flame wakes. GDD §19.2 (lines 3456 to 3475): offline accrual should be a "modest base trickle" that tapers. COMPUTED:

| Item | Ase | Share of a stage (realm.01 31.9 / realm.02 61.4) |
|---|---|---|
| Online per stage (10 / 15 min) | 3 / 4.5 | 9% / 7% |
| One day: 1 hour online + one offline return | about 36 | 1.1 realm.01 stages |
| Echo 8 price (145) from accrual alone | about 4 days | |
| Echo 12 price (300) from accrual alone | about 8 days | |

PROPOSAL: no change. Accrual stays about 7 to 9% of income, so it cannot grow the house by itself. That keeps the population lever honest: an idle player cannot fill the house. It still helps a returning player buy a retreat (10) or part of a skill. Doubling the weights makes accrual relatively smaller than in round 1 (10%).

## 7. Sinks: does Ase still overflow?

COMPUTED, a player who goes only for breadth: Echo 3 to 12 costs 1515 Ase, about 25 realm.02 stages of income (61 each). A player who takes skills at Standing 3 / 6 / 9 for 4 Echoes spends 4 x 270 = 1080. Together 2600 Ase, or about 43 realm.02 stages plus the realm.01 stages. Income over two realm runs (realm.01 4 stages x 38 = 152 and realm.02 6 stages x 61 = 366) is about 520 Ase. So the first 10 stages buy 4 to 5 Echoes plus a few skills, with no slack. Retreats (10) and vows (60 to 500) cost on top.

Verdict: Ase does not overflow (D-04 holds). It is the XCOM scarcity round 1 asked for: the player chooses between breadth, depth, protection (retreat) and vows. Risk: no slack. Part B adds Ase to crafting and rites (GDD §19.2: rites and Thread handling are also Ase uses). Then net cadence slows without any income change. Re-check Part B against this table. If playtests show the player stuck with no choice, the first lever is the realm scale (1.25 to 1.35), not the weights.

## 8. Effect of replay 0.35 and the realm scale on the first-summon maths

| Case | Income per stage | Echo 3 (60) | Echo 8 (145) |
|---|---|---|---|
| Realm.01 first run (party 2 to 5) | 31.9 to 37.9 | 1.9 stages | 3.8 stages |
| Realm.01 replay | 13.7 to 16.7 | 4.4 stages | 8.7 stages |
| Realm.02 first run | 55 to 61 | 1.1 | 2.4 |
| Realm.02 replay (0.35 x 1.25 x 37.5 = 16.4 + stipend 5 + accrual 4.5) | 25.9 | 2.3 | 5.6 |

Reading: replay pays about 40% of a first run in realm.01 and 42% in realm.02. A replay cannot farm a house (8 to 9 stages for one Echo at Echo 8). The player who needs an Echo should go forward. This matches D-53.

## 9. Knob table (current → PROPOSAL → decision)

| Knob (location) | Current | PROPOSAL | Decision |
|---|---|---|---|
| `data.rewards.objective_weights` | pursue 8, combat 10, recover 12, protect 12, endure 14, shrine 15, guide_spirit 16, boss 0 | 16, 20, 24, 24, 28, 30, 32, boss 0 | D-09, D-36, section 1 |
| `data.rewards.objective_ekwan` | set B 2 to 6 | unchanged (x realm scale, x replay) | D-29, D-30, D-55 |
| `data.rewards.enemy_defeated_bonus` | 5 | removed | D-40 |
| `data.rewards.echo_survived_bonus` | 10 per Echo (per fight) | replaced by stipend 2 per Echo, cap 10, once per stage, "home" = not dead | D-41, D-43, D-44, D-45 |
| `data.rewards.virtue_bonuses`, `stage_index_bonus_per`, `realm_order_multiplier_base`, `realm_order_multiplier_step` | 10/15/20, 5, 1.0, 0.5 | removed | D-40 |
| per-realm reward scale (new; place open) | none | realm.01 1.00, realm.02 1.25, rule 1 + 0.25 x (position − 1) | D-55, section 2 |
| `data.rewards.pace_bonus_pct` | 0.05 | no Ase for speed (the key leaves the payout; pace stays in rank) | D-49 |
| `data.rewards.pace_full_ratio`, `pace_zero_ratio` | 1.1, 1.6 | unchanged (rank) | D-49 |
| rank weights (new) | `rank_thresholds` S .90, A .75, B .55, C .35, D .15 on an Ase ratio | rank score win 0.40 + home share 0.40 + pace 0.20; thresholds unchanged | D-49, D-50 |
| `data.rewards.redo_penalty_per_run`, `redo_penalty_floor` | 0.10, 0.50 ladder | replaced by flat `replay_factor` 0.35 on objective Ase and Ekwan | D-54 |
| stipend on a replay (new) | n/a | 1 per Echo, cap 5 | D-53 |
| `data.rewards.defeat_factor` | 0.25 (also hard-coded in `EconomyService`) | unchanged; consolation on the fought weight | D-13 |
| `data.rewards.partial_intel_reward_factor` | 0.12 | unchanged | D-14 |
| `data.summoning.ase_cost_per_summon_by_grade.uncalled` | 60 (flat) | curve by living roster: Echo 3 = 60; Echo k ≥ 4 = round5(70 x 1.2^(k−4)) | D-55, D-36, D-37, section 3 |
| `data.summoning.ase_cost_per_summon_by_grade.called` | 150 | roster price + 90 | D-37, D-55 |
| `data.summoning.ase_cost_per_summon_by_grade.chosen` | 400 | roster price + 340 | D-37, D-55 |
| `data.summoning.ase_cost_per_summon` (flat fallback) | 60 | keep as the fallback | — |
| Price of Echo 2 (the opening summon) | 60 vs opening Ase 52 | QUESTION (section 11, question 4) | D-39 |
| `data.skills.definitions.*.unlock_conditions.ase_cost` | 40 (14 skills) | 60 / 90 / 120 by Standing 3 / 6 / 9 | D-36, section 4 |
| `data.combat.retreat_ase_cost` | 30 | 10 | D-46 |
| `data.vows.definitions.*.breaking_costs` (Ase) | 60 to 500 | unchanged | D-32 |
| `data.economy.ase_online_per_min_base` | 0.3 | unchanged | section 6 |
| offline accrual keys (`offline_start_factor` and others) | 0.06 etc. | unchanged | section 6 |
| `data.sanctum.party_max_size` | 5 | unchanged | D-41 |
| `data.institutions` assign 5 Ase, establish/unassign Ekwan | 5, 10/15, 3 | unchanged | Phase 1 |
| `first_trial_ase_reward`, awakening boost | 40, 12 | unchanged | D-39 |

## 10. Build cost (separate note, D-48; not used for ranking)

Per knob, the work for mechanics-developer is: weights, retreat, vow and skill costs are data edits. The stipend, the flat replay factor, the per-realm scale and the removal of the enemy and virtue bonuses are code changes already planned. The roster-based summon price is new: `SanctumController` (summon spend), the Summon snapshot and screen (price display), a count of living Echoes, and tests. The pace key retirement and the rank re-base move fingerprint constants. Each moved value needs one named cause and one re-record.

## 11. Gaps, risks and questions

1. QUESTION (GDD gap): which population range? GDD §18.8 names no ideal. Options P-A (7 to 10, soft ceiling 12; recommended), P-B (5 to 7), P-C (12 to 16) in 3.1.
2. QUESTION: should the price count only living Echoes (a death lowers the next price) or all Echoes ever summoned? I advise living: a loss can be rebuilt, which keeps permadeath bearable without making it cheap (the Echo is gone; the new one starts at Standing 1). Risk: a player could release Echoes to reset the price. ASSUMED: no release action exists (I found none in `SanctumService`). Mechanics-developer confirms.
3. QUESTION (GDD gap): GDD §19.2 lists summoning, rites and Thread handling as Ase uses. Skill unlock with Ase is a V2-PROG choice. Keep it, or move it (for example to Standing and Storyweight only, or to Ekwan)?
4. QUESTION: how does a player afford Echo 2 with 52 opening Ase when an uncalled summon costs 60? D-39 says the opening pays for it. CHECKED: `data.keeper_intro`, `awakening_ase_grant` (unpaid), Phase 1. NEED: mechanics-developer or Jeff. PROPOSAL if a price is needed: Echo 2 at 50.
5. GDD gap: §20.8 says "roughly 4 to 6" stages per Realm. `data/realms.json` uses 3 to 4 (realm.01) and 5 to 7 (realm.02). My tables use the data. If the GDD number wins, realm.01 runs are longer and income per realm is higher.
6. Risk: income saturates at party 5 (stipend 10). Bigger rosters add no income. That is intended (regulation). The player who rotates a reserve earns the same.
7. Risk: the 1.25 scale and the second objective make a realm.02 stage pay 62% more than realm.01. If Jeff reads "later realms pay more" as per stage, this holds; if per minute, the margin is 8%.
8. Risk: the recruit path (ANSWERS #28) adds Echoes with no price. It raises the next summon price. If recruits are common, regulation moves to the recruit chance (cap 75). Out of scope; flag.
9. Risk: tables assume no Echo dies. A death lowers income by 2 (stipend) and the next price, and costs the Thread quality (D-50). Both effects are small next to the loss of a person.
10. ASSUMED: stage time 10 and 15 minutes. If much longer, accrual per stage rises and the share of accrual grows. Check with a playtest log.

## OPEN — questions and assumptions

ASSUMED: Stacking order is objective Ase = roundi(sum of weights x realm scale x replay factor), rounded once on the stage sum | WHY: D-30 and D-54 say "rounded once" | WRONG IF: the scale is applied after rounding.
ASSUMED: The player always runs the biggest party (min(roster, 5)) and loses no Echo | WHY: simplest case for the cadence | WRONG IF: players keep a small party.
ASSUMED: No release or dismiss action exists | WHY: not found in `SanctumService.gd` | WRONG IF: a release action exists. Then the roster price needs a rule against price resets.
ASSUMED: Stage time 10 and 15 minutes | WHY: GDD §20.14 (first 30 minutes cover 1 to 3 stages and onboarding) | WRONG IF: stages are much longer or shorter.
ASSUMED: A stage in realm.01 draws its objective evenly from the 7 types | WHY: Phase 1 counts of 200 seeds | WRONG IF: the real draw is skewed (it was 84 to 120 of 700 per type).
BLOCKED: Which population range (P-A, P-B, P-C)? | CHECKED: GDD §18.8, §20.8 (generation model), `data.sanctum`; canon-index grep "roster", "population", "capacity" | NEED: Jeff.
BLOCKED: Called and chosen: premium (X) or multiple (Y); chosen premium 340 or higher? | CHECKED: D-37, D-55 | NEED: Jeff.
BLOCKED: Does the price count living Echoes only? | CHECKED: D-45, D-55 | NEED: Jeff.
BLOCKED: Skill unlock with Ase (GDD §19.2 does not list it): keep? | CHECKED: GDD lines 3456 to 3475, `ProgressionController.gd` | NEED: Jeff.
BLOCKED: How does the opening afford Echo 2 at 52 against 60? | CHECKED: Phase 1 section 3.3, D-39 | NEED: mechanics-developer or Jeff.

## Sources used

Skills: `game-mechanics-designer` (price curves, stages-to-afford, sink balance, proposals labelled), `game-design` (does the lever produce a decision, is it legible, is the house fill felt), `echoes-sankofa-gdd` (canon lookup through `docs/canon-index.md` line ranges). All three were loaded earlier in this session; I did not reload them for this file.

GDD citations (`docs/Echoes vNext Working GDD.md`):
- §19.2 Ase, lines 3456 to 3475: Ase pays summoning, rites and Thread handling; offline accrual is a modest, tapering trickle after the flame awakens. Supports section 6. No skill-unlock use is listed (question 3).
- §18.8, lines 3325 to 3335: a small or a large house can reach high Continuity; no single ideal population model. Supports the soft (not hard) regulation and the open question.
- §20.8 "Current generation model", lines 3867 to 3881: 4 to 6 stages per Realm; difficulty scales mainly with completed Realm count and secondarily with roster and house strength. Supports a price that rises with roster; gap against `realms.json` stage counts.
- §20.12, lines 4116 to 4135, and §20.14, lines 4153 to 4172: the opening nearly pays the first summon; about 2 Echoes and 1 to 3 stages in 30 minutes. Source of the cadence frame.
- §20.17, line 4338, and §14.3 (lines 2094 to 2112): permadeath is core; deaths lower Thread quality. Supports a price that falls with a death only slightly, and the stipend note.
- §21.1, lines 4468 to 4477: summon cost and early Ase cadence are open. These are Jeff's numbers.
- §5 (lines 120 to 160): the Sanctum builds attachment; the Realms test it. Supports the pillar argument for a house the player can know.
Other: `data/balance.json` blocks named at the top, `data/realms.json`, `ProgressionController.handle_unlock_skill`, `phase1-characterization.md` section 2 (objective counts) and section 3 (sinks and sources), decisions D-36 to D-55.
Not read: GDD roster and party-management text beyond the grep hits (line 311, 4564, 4581), and the Sanctum institutions section (4382 to 4445), so house capacity from institutions is not checked.
