# V2-ECONOMY-004 Part A — Phase 5 design advice (round 1, sr-game-designer)

Written in STE. Every number marked PROPOSAL is advice. Jeff decides each one. No value is in `data/balance.json`.
Tags: READ = from code, data or docs. COMPUTED = my arithmetic (Godot `roundi` rounding, half away from zero). ASSUMED = not verified.
Inputs: D-04, D-09 to D-16, D-22 to D-37, `phase1-characterization.md`, `phase3-weights-proposal.md`, `phase3b-design-check.md`, `phase4-ekwan-proposal.md`,
`data.rewards`, `data.summoning`, `data.economy`, `data.skills`, `RealmService.calculate_stage_reward`, `PaceService.max_bonus_ase`, GDD §5, §7.1, §10.6, §19.1, §20.12, §20.14, §21.1, ANSWERS #64.
Skills used: `game-mechanics-designer` (sources and sinks, cadence formulas), `game-design` (clarity and satisfaction check), `echoes-sankofa-gdd` (pillar scan).
D-37 applied: "a summon" = the UNCALLED summon (60 Ase). Called (150) and chosen (400) are rare goals.

## 0. Findings first

1. Stage rewards do almost all the work. Accrual is a trickle (section 2.3).
2. Today (Set B plus all bonuses) the fixture run pays about 65 Ase per stage. That is about one uncalled summon per stage. Jeff's target is one per 2 stages. So the target needs about half of today's income, about 24 to 30 Ase per stage.
3. The virtue bonus is the largest single line (59% of the stage payer, 70 of 118 in the fixture run). It has three hidden inputs. Replay does not scale it. So a replay pays 92% of a first run (241 against 262). At the redo floor (0.5) a replay still pays 166. That is a faucet that works against D-04.
4. The pace bonus is 1 Ase on almost every type (5% of base 8 to 16 rounds to 1; base 8 rounds to 0). The "bonus with a visible goal" exists but pays nothing worth a goal.
5. The Echo bonus grows with party size. It is a small positive feedback loop (more Echoes, more Ase, more summons). Party cap not checked (ASSUMED bounded by party slots).
6. Growth pillar: GDD §7.1 and §10.6 name Storyweight, Threads and Continuity as the growth spine. Ase is a tool, not the growth. No GDD text I found makes realm virtue an Ase payer (grep of "realm virtue" and "virtue.*reward": only §11 line 1831, a list of virtue names). The virtue bonus comes from the REALM-005 story, not from the GDD. So removing it does not touch the pillar. The Echo-survival bonus does serve the pillar (people, not units), so it stays.

## 1. Reading of "XCOM style" (ASSUMED)

ASSUMED reading: each stage and objective shows a FIXED reward before the player commits (like the mission panel in XCOM). Resources are scarce, so the player must choose between summoning, skills and retreat. There is at most one visible bonus goal. Losses cost something real (soldiers, here Echoes). No hidden formula changes the number between the promise and the payout.

One confirming question for Jeff: "Should the player see the exact Ase and Ekwan of a stage before entering it, with the payout equal to that promise, and the only variable part a visible bonus goal?"

## 2. Faucet and sink map

### 2.1 Sinks (READ: Phase 1 section 3, `data.summoning`, `data.skills`, `data.vows`)

| Sink | Price (Ase) | Note |
|---|---|---|
| Summon, uncalled | 60 | The repeatable one. Target: one per 2 stages. |
| Summon, called | 150 | Special case (D-37). |
| Summon, chosen | 400 | Special case (D-37). |
| Skill unlock | 40 each, 14 definitions | Paid per Echo per skill. Gated by `min_standing` (3 for the skill read) and calling family. |
| Vow break | `tikoro_nko_agyina` 60/120/250/500; `praye_wokabomu` 60/120; `obi_nnim_kyere` 60/100 | Goals or penalties: open (D-32). |
| Retreat before round 1 | 30 | Paid whether the retreat works or not. Partial pays 0 until one objective is won (D-14). |
| Institution assign | 5 | |
| Ekwan (separate) | Hearth 10, Training grounds 15, unassign 3, vow breaks 15 to 100 | See section 5. |

### 2.2 Faucets (READ)

| Faucet | Value |
|---|---|
| Opening | 40 (first trial) + 12 (awakening boost) = 52. The 40 `awakening_ase_grant` is not paid (Phase 1). |
| Stage payer + fights | About 65 per stage today (fixture; section 3.3). |
| Retreat / return-home partial | 12% of completed weights (D-14): 0 to 2 Ase. |
| Defeat consolation | 25% of the fought weight (D-13): 2 to 4 Ase. |
| Online accrual | 0.3 per min = 18 per hour. Needs the Ase flame. At most 18 per settle (3600 s cap). |
| Offline accrual | About 18 per return at the typical multiplier. At most about 31. |
| Claimant contact (good), situation "money" | 20; 8 to 20. Rare. |

### 2.3 How much accrual contributes

Stage length in real time: no doc or code states it. GDD §20.14 puts the first 30 minutes at "likely 1 to 3 stages" including onboarding. ASSUMED: 8 to 12 minutes per stage in the middle game. A 4-stage `realm.01` run is then 32 to 48 minutes.

| Item | Ase |
|---|---|
| Online accrual per stage (10 min) | 3 |
| Online accrual per `realm.01` run (4 stages, 40 min) | 12 |
| Offline accrual per return | 18 typical, 31 at most |
| One day: one 1-hour session plus one return | about 36 |

COMPUTED: 36 per day is 0.6 of an uncalled summon per day. 12 per run is about 10% of a recommended run (96 to 120). Accrual is a welcome-back floor. It is not a driver. The stage payer must carry about 90% of the pace. If Jeff wants offline Ase to matter, the rates (`ase_online_per_min_base` 0.3, offline 0.005 per second times 0.06) need a separate decision. I do not advise it for this phase.

### 2.4 What Jeff's targets mean in Ase per stage

Formula: needed stage income S = (price − starting Ase) / n stages. For a steady cadence S = price / n − accrual per stage (about 3).

Uncalled (60), the main case:

| Target | Starting Ase 52 (opening, unspent) | Starting Ase 0 |
|---|---|---|
| First summon in 1 stage | 8 | 60 |
| in 2 stages | 4 | 30 |
| in 3 stages | 2.7 | 20 |
| Steady: one per 2 stages | 30 gross, about 27 net of accrual | same |

Reading: with the 52 opening, ANY stage income of 8 or more finishes the first summon in 1 stage. That is what GDD §20.12 says ("one proper stage reward"). A stage income of 24 to 30 also gives 2 to 3 stages if the opening grant is not counted. So S = 24 to 30 satisfies both readings of "1 to 3 stages". PROPOSAL: aim at S = 24 (no bonus earned) to 30 (bonus earned).

Called and chosen (D-37 says "much larger"; my reading: much larger than the 2-stage uncalled cadence). Pure saving, at S = 24 to 30, no other spending:

| Grade | Price | Stages of pure saving at S 30 / 24 | PROPOSED cadence range (stages) | In `realm.01` runs (3 to 4 stages; use 4) |
|---|---|---|---|---|
| Called | 150 | 5 / 7 | 8 to 12 | 2 to 3 |
| Chosen | 400 | 14 / 17 | 25 to 40 | 6 to 10 |

Reasons: a called summon should cost the player about 4 to 6 uncalled summons of delay, so it is a decision (breadth now or a chosen calling later). The player also pays for uncalled summons, skills and retreats, so real cadence is longer than pure saving. At the current prices (150, 400) pure saving gives 5 to 7 and 14 to 17 stages. That is shorter than my proposed ranges. Two ways to reach the ranges: (a) keep the prices and trust that other spending stretches the cadence; (b) raise the prices. PROPOSAL if Jeff wants the ranges as PURE saving: called about 250 to 300, chosen about 700 to 1000. I advise (a) first and measure (a playtest question), because a price change also moves the `summoning` tests.

Note: `calling_weights` gives an uncalled summon a random calling. A called summon lets the player pick the calling. That is a real decision. It supports a high price.

## 3. Simplifying the bonuses

### 3.1 Per component

| Component | Today | Advice | Reason (pillar / XCOM / UI cost) |
|---|---|---|---|
| Virtue bonus (`virtue_bonuses`, `stage_index_bonus_per`) | 10 to 25 per stage, hidden formula, not scaled by replay | REMOVE as a row. Merge its job (later content pays more) into one visible realm scale (see order multiplier). | Pillar: no GDD basis; growth lives in Storyweight and Threads. XCOM: violates "no hidden formula" (three inputs). It is 59% of the payer, so it hides the objective type order that Set B built. Replay does not scale it (faucet). UI: removes one row that needs a three-part explanation. Loss: stage depth no longer raises pay. The player never saw that rule, so little is lost. |
| Enemy bonus (5 per enemy) | 15 in the fixture fight | REMOVE. | Every objective type already includes the fight (Phase 3 finding). It pays encounter size, which the player does not control in an autobattler. XCOM does not pay per kill. GDD §5: "Realms are not just combat content". UI: removes a row. Cost: `RewardCalc` rank uses `enemies x 5` in `max_possible`; the rank formula must change with it (mechanics-developer). |
| Echo bonus (10 per surviving Echo) | 20 in the fixture fight | KEEP, simplify: lower per-Echo value, one row "Echoes alive". | Pillar: Echoes are people. A loss must cost something visible. Per Echo (not all-or-nothing) so a chosen sacrifice (GDD §5 "sacrifice") has no cliff. XCOM: casualties are the real cost. Cost: grows with party size (small feedback loop). Lower value and party cap limit it. |
| Pace bonus (5% of base) | 1 Ase everywhere | KEEP the goal, CHANGE to a fixed amount. | It is the only "bonus objective with a visible goal" (ANSWERS #64). At 1 Ase it is noise. A fixed amount makes the goal worth reading. UI: row exists already (`bonus_earned` or `bonus_missed`). |
| Replay multiplier (0.9 ladder, floor 0.5, base only) | Run 2 pays 92% of run 1 | SIMPLIFY: one flat factor on the whole stage sum, no ladder. Row shows only on a replay. | A ladder is a hidden rule (the player cannot predict run 4). A flat factor is predictable. Growth for an Echo comes from the run itself (Storyweight, Threads), not from Ase, so low Ase on replay does not hurt the pillar. Ekwan follows (D-30). |
| Realm order multiplier (`realm_order_multiplier_step` 0.5) | x1.0 for the first started realm, x1.5 for the second started | MERGE into one fixed per-realm scale on the objectives row. | Today it depends on the ORDER the player starts realms, not on the realm. A fixed scale per realm is predictable and shows before entry. PROPOSAL default: 1.0 for `realm.01`, 1.5 for `realm.02` (same as today for the normal order). Jeff may set 1.0 for both. |
| Defeat consolation | 25% of fought weight | KEEP (D-13). | Already one row. Not in scope. |

### 3.2 Recommended structure (call it R) — 3 rows in a normal win

Stage Ase = round( (sum of completed weights x realm scale) + (Echoes alive x a) + (b if the pace goal is met) ), then x r on a replay.
PROPOSAL values: weights = Set B (unchanged), realm scale 1.0 / 1.5, a = 6 per Echo, b = 6 fixed, r = 0.5 flat.
Rows in a win: objectives overcome, Echoes alive, bonus. Conditional: replay, consolation. Today: 7 rows.

Fixture run (stage 0 `guide_spirit` 16, stage 1 `protect` 12, stage 2 `combat` 10, stage 3 `combat` 10; 2 Echoes alive; `realm.01`, scale 1.0):

| Stage | Objectives | Echoes alive (2 x 6) | Subtotal | + bonus 6 |
|---|---|---|---|---|
| 0 | 16 | 12 | 28 | 34 |
| 1 | 12 | 12 | 24 | 30 |
| 2 | 10 | 12 | 22 | 28 |
| 3 | 10 | 12 | 22 | 28 |
| Run total | 48 | 48 | 96 (24 per stage) | 120 (30 per stage) |

Replay at r = 0.5: 48 without bonus, 60 with bonus (rounded once on the sum).

### 3.3 Alternative (call it M) — 2 rows in a win

Purer XCOM: fixed objective pay plus one bonus. No Echo-survival pay.
Weights x2 (Set B shape kept), realm scale, b = 6, r = 0.5. Same totals by design.

| Stage | Objectives (2 x weight) | + bonus 6 |
|---|---|---|
| 0 | 32 | 38 |
| 1 | 24 | 30 |
| 2 | 20 | 26 |
| 3 | 20 | 26 |
| Run total | 96 (24 per stage) | 120 (30 per stage) |

Cost of M: nothing in Ase rewards keeping an Echo alive. That weakens the people-first pillar. It also doubles the Set B weights, which Jeff approved at the Set B scale (D-09 allows Phase 5 to scale). I recommend R.

### 3.4 Comparison on the Phase 1 fixture run (stage payer + fights, 3 enemies, 2 Echoes; no replay unless noted)

| Variant | Stage 0 | Stage 1 | Stage 2 | Stage 3 | Run | Per stage |
|---|---|---|---|---|---|---|
| Today (Set B, all bonuses): weight + virtue + 35 | 16+10+35 = 61 | 12+15+35 = 62 | 10+20+35 = 65 | 10+25+35 = 70 | 258 (262 with 1 Ase pace x4) | 64.5 |
| R without bonus | 28 | 24 | 22 | 22 | 96 | 24 |
| R with bonus | 34 | 30 | 28 | 28 | 120 | 30 |
| M without / with bonus | 32 / 38 | 24 / 30 | 20 / 26 | 20 / 26 | 96 / 120 | 24 / 30 |
| Today, replay (run_count 1, x0.9 on base and fight): roundi(w x 0.9) + virtue + roundi(35 x 0.9) | 14+10+32 = 56 | 11+15+32 = 58 | 9+20+32 = 61 | 9+25+32 = 66 | 241 | 60 |
| Today, replay at floor (x0.5) | 8+10+18 = 36 | 6+15+18 = 39 | 5+20+18 = 43 | 5+25+18 = 48 | 166 | 41.5 |
| R, replay (x0.5) | | | | | 48 to 60 | 12 to 15 |

Fight arithmetic today: 3 enemies x 5 + 2 Echoes x 10 = 35. Pace today: `roundi(base x 0.05)` = 1 for bases 10, 12, 16 (and 15, 14); 0 for base 8 (COMPUTED; base 8 gives 0.4).

Realm 02 (rough, ASSUMED 4 enemies, 3 Echoes, 1.51 objectives per stage from Phase 1 counts, mean Set B weight 12.4): today about 105 per stage; R at scale 1.5 about 52 (28 objectives + 18 Echoes + 6); R at scale 1.0 about 43. Not measured. Jeff should expect realm.02 pay to be about half of today and still above realm.01.

### 3.5 What the player sees

Clarity: a player predicts the payout from the objective type before entering. No hidden growth by stage index. Satisfaction: the Echoes row and the bonus row change with what happened in the fight. A player who never reads the ledger still gets a fair result (the fixed part is the larger part: 50% of R).

## 4. Skill unlock cost advice

Facts (READ): 40 Ase for each of 14 definitions. Paid per Echo per skill. Gated by Standing (3 / 6 / 9 milestones) and calling family. Each Echo can reach about 3 skills by Standing 9 (GDD milestone package: 1 active, 1 passive, 1 utility). So skill spend scales with roster size.

Intent: a skill is a decision "deepen this Echo, or summon another". Jeff allows "even higher" than 40. An uncalled summon is 60.

PROPOSED range: 60 to 120 Ase. Reasons:
- Below 60 a skill is cheaper than a new Echo, so the player never faces the choice.
- At 60 to 90 a skill costs 1 to 1.5 uncalled summons. This keeps the choice real.
- Above 120 the cost passes 4 stages of income. With 3 skills per Echo and a roster of 5, the player needs 15 skills and the cost blocks the growth pillar (Echo growth over time).
- Optional shape: price by milestone (Standing 3 skill 60, Standing 6 skill 90, Standing 9 skill 120). The data already has an `ase_cost` per skill, so this needs no code (mechanics-developer to confirm). It makes later Standing cost more and matches "mastery costs more".

Stages to afford (ceil, one purchase, no other spending; S from section 3):

| Price | S = 24 | S = 30 | Today's income (S = 65) |
|---|---|---|---|
| 40 (today) | 2 | 2 | 1 |
| 60 | 3 | 2 | 1 |
| 80 | 4 | 3 | 2 |
| 100 | 5 | 4 | 2 |
| 120 | 5 | 4 | 2 |
| 150 (called summon) | 7 | 5 | 3 |
| 400 (chosen summon) | 17 | 14 | 7 |

Standing 1: no skill is affordable by rule (Standing gate). Standing 3: the player has played several stages, so 60 to 80 is 2 to 4 stages. Standing 9: late; 120 is a deliberate saving goal.

## 5. Ekwan (set B) and the sinks

Set B Ekwan on the fixture run: `guide_spirit` 3 + `protect` 3 + `combat` 2 + `combat` 2 = 10 per run, 2.5 per stage (COMPUTED from D-29). Hearth (10) takes about 4 stages. Both institutions (25) take about 10 stages. Replay at 0.5 pays about half (round once on the sum).

Verdict: Ekwan amounts still fit. Ekwan is independent of the virtue and fight bonuses, so structure R or M does not move them. The ratio is Ase:Ekwan about 10:1 per stage (24 to 30 : 2.5), and price ratio about 6:1 (60 : 10). That keeps Ekwan scarce (D-04). Do not scale Ekwan with the Ase weights unless Jeff wants the first institution faster. Option: apply the realm scale to Ekwan too (one visible scale). Not needed now.

Sink gaps (report only): after both institutions, Ekwan has no use until Part B (D-32 note). Vow-break Ekwan 20 to 100 is 8 to 40 stages of Ekwan at 2.5 per stage. Jeff must decide if vow breaks are goals or penalties.

## 6. Risks and unknowns

1. Stage real time is unknown (ASSUMED 8 to 12 minutes). Accrual per stage depends on it. A playtest or log measurement should replace the assumption.
2. The fixture is one run with 3 enemies and 2 Echoes. Real enemy counts and party sizes are not measured.
3. Rank and the bonuses are coupled. `RewardCalc` rank uses `base + enemies x 5 + echoes x 10 + max_pace` (Phase 3 section 6). Removing the enemy bonus or changing the Echo bonus changes rank ratios and may move rank thresholds and the fingerprint constants. Needs mechanics-developer and one attributed re-record.
4. The pace bonus applies only in pace modes. If many fights have no pace goal, the average stage income is nearer S = 24 than 30.
5. Retreat costs 30 (about one stage of income) and the partial pays 0 until a win (D-14). Retreat is a pure loss of about one stage. This may be intended scarcity. It may also stop players from retreating. Jeff should decide (a lower retreat price is an option).
6. Vow-break tier 4 costs 500 Ase, about 17 stages. Out of scope; flagged.
7. Realm 02 income is a rough estimate (section 3.4). If it must stay near 30 per stage, set the realm scale to 1.0 and accept that the second objective per stage doubles realm.02 weights.
8. Skills: pay per Echo per skill. A large roster multiplies skill demand. At 90 Ase and 10 Echoes with 3 skills each, the total is 2700 Ase (about 90 stages). The Standing gate spreads it over time, but watch it.
9. Removing the virtue bonus ends a REALM-005 behavior and its tests (`calculate_stage_reward` and the key `virtue_bonuses`). That is a removal under AGENTS.md rules (full-repo audit). The Resolve card row `realm_virtue` leaves the UI contract (D-19, D-23). The UI session must be told. This is a scope decision for Jeff, not part of Part A today.
10. Failure modes: a player who ignores the bonus loses 6 per stage (20%) and still progresses. A player who hoards can afford the chosen summon in 14 to 17 stages. At Standing 1 the player has 52 Ase and the first stage finishes the first summon. A replay farm yields 12 to 15 Ase per stage under R (today 41 to 60).
11. Pillar pass: R keeps Echoes-alive pay (people), removes pay that is not tied to growth, and leaves Storyweight, Threads and Continuity untouched.

## OPEN — questions and assumptions

ASSUMED: "XCOM style" means fixed, visible-before-entry rewards, scarcity that forces priorities, one visible bonus goal, no hidden formulas, and real cost for losing Echoes | WHY: Jeff left the phrase undefined; this is the common reading for XCOM mission panels | WRONG IF: Jeff means something else (for example a strategic resource layer, or research-driven rewards).
BLOCKED: Does Jeff want the exact reward shown before entering a stage, with the payout equal to that promise? | CHECKED: D-36, D-17, ANSWERS #64 (goal visible before or during the fight; result states cause) | NEED: Jeff's yes or no. A yes also asks for a pre-entry preview (D-25 says no mid-stage preview).
ASSUMED: "much larger" (D-37) means much larger than the uncalled cadence of 2 stages; so called 8 to 12 stages and chosen 25 to 40 stages | WHY: coordinator reading, relayed with D-37 | WRONG IF: Jeff wants called and chosen to be only somewhat rarer (for example 5 to 7 stages, which the current prices already give).
ASSUMED: The opening Ase (52) is unspent when the first summon is considered | WHY: GDD §20.12 says the opening grants almost enough Ase | WRONG IF: the first trial or the awakening boost is spent first (for example on a retreat) or the 40 `awakening_ase_grant` is paid later (V2-ECONOMY-002).
ASSUMED: Stage length is 8 to 12 minutes | WHY: GDD §20.14 (30 minutes covers onboarding and 1 to 3 stages) | WRONG IF: a real stage takes much longer or shorter; accrual per stage changes in proportion.
ASSUMED: Realm.02 figures use 4 enemies and 3 Echoes | WHY: no measurement exists | WRONG IF: real fights differ.
ASSUMED: `ase_cost` per skill can differ by skill with no code change | WHY: the key sits in each definition's `unlock_conditions` (READ) | WRONG IF: the code reads one shared value.
BLOCKED: Should the virtue bonus be removed from the game (a REALM-005 behavior), not only simplified? | CHECKED: GDD grep (only line 1831 names virtues), `RealmService.calculate_stage_reward`, `data.rewards` | NEED: Jeff's decision and a mechanics-developer audit of consumers.
BLOCKED: Should realm.02 pay more than realm.01 (scale 1.5) or the same (1.0)? | CHECKED: `realm_order_multiplier_step` 0.5, Phase 1 section 1.2 | NEED: Jeff.
BLOCKED: Should the flat replay factor be 0.5 or another value, and should replay Ase be lower than the Ekwan? | CHECKED: D-30, `redo_penalty_*` | NEED: Jeff.
BLOCKED: Retreat price (30) and vow-break prices: keep or change? | CHECKED: Phase 1 section 3, D-14, D-32 | NEED: Jeff.

## Hand-off for `game-feel-developer`

Please read this file and check how the rewards FEEL, not the numbers. Check three things. (1) Cadence: with 24 to 30 Ase per stage, does one uncalled summon per 2 stages feel like steady progress or like a wait? Look at the gap between stages 1 and 2, and at the first summon after the opening (one stage, with 52 Ase already in hand). (2) Readability: in structure R the win shows three rows (objectives, Echoes alive, bonus). Is a 6 Ase bonus visible and anticipated before the fight, as ANSWERS #64 demands, and does the "missed" state feel fair and not like a penalty? Does the ledger make the Echoes-alive row feel like care for people, not a score? (3) Anticipation: what should the player see before the stage (fixed reward, if Jeff confirms the XCOM reading) and at the saving moment (a visible progress toward the next summon, skill, or called summon)? Tell me where the called (8 to 12 stages) and chosen (25 to 40 stages) waits need a visible goal so the player does not forget them, and whether the retreat cost of 30 reads as a fair choice or as a trap.
