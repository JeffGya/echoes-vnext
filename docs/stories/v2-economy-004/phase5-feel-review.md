# V2-ECONOMY-004 Part A — Phase 5 feel review (round 2, game-feel-developer)

Written in STE. Every number marked PROPOSAL is advice. Jeff decides. Nothing here is in `data/balance.json`.
Tags: READ = from a file I opened. COMPUTED = my arithmetic. ASSUMED = not verified. "Starting value" = a number to test, not a fact.
Reviewed: `phase5-design-advice.md` (round 1). Cross-read: D-04, D-09 to D-37, ANSWERS #64, `pace-reward/design.md` section 6 and `follow-ups.md`, the UI session's `v2-payout-explanation/decisions.md` (read-only), GDD sections named in section 6.

## 0. Findings first

1. The designer assumed the 52 opening Ase is unspent when the first summon is considered. The GDD says the opening Ase pays the SECOND Echo before the first stage (sections 20.7, 22.4 step 4, 20.12). So the player starts stage 0 with about 0 Ase. The "first summon in 1 to 3 stages" is the THIRD Echo. This changes the cadence reading (section 2.1).
2. The designer's fixture table puts a 6 Ase bonus on stage 1, which is a `protect` stage. `protect`, `endure` and the `guide_spirit` protect variant have NO pace bonus (`pace-reward/design.md` line 61-62, 148). About one third of realm.01 stages cannot pay a bonus (COMPUTED, section 1.4). So "24 to 30 per stage" is really "24 to about 28".
3. The pace bonus is a three-state curve today (`full`, `partial`, `none`), shown as colour in the fight (`design.md` section 6). The designer's "fixed amount, met or not" turns it into a binary. That breaks the shipped colour meaning.
4. "Echoes alive" at 6 each is half of the income and arrives with every win. It reads as a stipend, not as care. Permadeath is core (GDD 20.10, line 4338), so a lost Echo costs far more than 6 Ase. The row cannot carry that weight.
5. A retreat that costs 30 (one full stage of income) and pays 0 is a trap for a new player. GDD 20.10 calls withdrawal a "safety valve" available from the start.
6. A pre-entry reward promise is possible and honest, but only per objective, and only after the objective is revealed. A total promise is not honest (section 3).

## 1. Verdict on Structure R and its numbers

Scale: FEELS RIGHT / RISKY / WRONG. Each line: anticipation (before) · feedback (at the moment) · consequence (next).

### 1.1 Shape of R: 3 win rows (objectives overcome, Echoes alive, bonus) — FEELS RIGHT, with two repairs

- Anticipation: three rows are few enough to learn. Each row answers one question: "what did we do, who came home, were we quick".
- Feedback: the rows match the shipped UI causes (`objectives_overcome`, `echoes_alive`, `bonus_earned`/`bonus_missed`). The UI loses `enemies_defeated` and `realm_virtue` as Ase rows. The "Enemies defeated" chip can stay as plain information (UI D-05). Removing the two rows removes two tooltips that needed an explanation ("The realm rewards the virtue the party showed here" explains nothing). Good for readability.
- Consequence: the player sees which choice moved the number. The old virtue row had no player lever. Removing it is right for Clarity (game-design filter).
- Repair A: the bonus row must be absent, not zero, on no-pace stages (`design.md` D-06 already says so). R must say so in its text.
- Repair B: R says "Echoes alive" and "bonus" once per stage. The shipped UI pays and shows both per FIGHT (UI D-12: fight cards show fight rows; stage-ending card adds the Stage group). In realm.01 a stage is one fight, so no difference. In realm.02 (1 or 2 objectives; Phase 1 section 2) the difference doubles those rows. Jeff or the designer must pick one. I advise per fight, because it matches the built UI and the pace bonus is per fight in the code.

### 1.2 Income "about 24 to 30 Ase per stage" — RISKY

- Anticipation: the player thinks in whole stages, not averages. With price 60 and income 22 to 28 (no bonus, 2 Echoes), two stages give 44 to 56. That is 4 to 16 short. The summon lands after stage 3 whenever the bonus is missed or absent. The cadence is 2 stages only when the bonus is earned twice in a row (28 + 28 = 56 plus accrual about 6 = 62, a narrow pass).
- Feedback: "4 short" is the worst moment: the bar is almost full and the player must play a whole stage for nothing. It reads as a tease.
- Consequence: real cadence swings between 2 and 3 stages, and then spending on skills and retreat pushes it longer. "About one per 2" is met only by a lucky run.
- Resolution (PROPOSAL, Jeff decides): state the target as the WORST normal case. Starting value: two stages without any bonus clear 60 with accrual. That needs about 27 gross per stage without bonus (objectives + Echoes). The bonus then gives a lead, not a gate. Spending leaks (skills, retreat, vows) already supply the "hard to attain" feel. If Jeff wants the cadence "about 2 to 3", keep R as it is and say so in the target.

### 1.3 Echoes alive at 6 each — RISKY

- Anticipation: the player sees "6 per Echo" and learns "bring everyone". That is fine. It also teaches "summon more Echoes, earn more Ase" (small loop; the designer noted it).
- Feedback: with 2 of 2 alive the row shows +12 on almost every win. A row that never changes becomes wallpaper. The player does not read it as care.
- Consequence: when an Echo dies (permadeath, GDD 20.10 / line 4338: Echo removed from roster, morale and fear ripple) the row drops by 6. The ledger shows -6 next to the loss of a person. The number is too small to mean anything and too visible to ignore. Reading "6 Ase" next to a death trivialises it.
- Resolution (PROPOSAL):
  1. Keep the row but make it show a count, not only a sum: "Echoes home: 2 of 2". The count is the meaning, the Ase is the side effect.
  2. Do not rely on this row to price a death. The death ripple in the Sanctum carries that cost (GDD 20.10 package). The row only needs to pay a small, stable amount.
  3. Cap the counted Echoes (starting value: 3) so income does not grow past the cadence target as the roster grows. Ask Jeff if a cap is wanted. Party cap: not checked (ASSUMED, as the designer assumed).

### 1.4 Bonus 6 flat — RISKY

- Facts (READ): pace modes are COMBAT, PURIFY_SHRINE, RECOVER, PURSUE and the GUIDE_SPIRIT escort variant. No-pace modes are PROTECT, ENDURE and the GUIDE_SPIRIT protect variant (`design.md` lines 61-62). Realm.01 counts (Phase 1 section 2): protect 88, endure 104 of 700 stages, so 27%. `guide_spirit` is 84; if half are protect variants (ASSUMED 50/50), that adds 6%. COMPUTED: about one third of realm.01 stages pay no bonus.
- Anticipation: during the fight the goal is visible as colour only (three states). Before the fight nothing shows the goal or its size. ANSWERS #64 allows "before OR during", so it is met in letter. At 1 Ase nobody cared. At 6 Ase (20% of income) the player will care, and the player has levers before the fight (party, directives, limited guidance). A goal worth 6 that the player cannot see until the fight starts is not a goal the player can aim at.
- Feedback: a binary "met / missed" replaces the curve. The shipped `partial` state would pay between 0 and 6. Keep the curve with a fixed maximum of 6. Then "partial" is a fair middle and a miss never feels like a cliff. A binary at 6 makes a miss feel like a fine.
- Fairness of a miss: fair when (a) the player could see the goal before the fight, (b) the colour went to `none` in plain view during the fight, (c) the row says it in the player's terms ("not quick enough", UI tooltip, already written). (b) and (c) exist. (a) does not. So a miss feels fair only after the pre-fight cue exists.
- Consequence: a missed bonus costs 6 of about 28. It does not stop progress. That is the right size for a bonus: it rewards, it does not punish.
- Resolution (PROPOSAL): keep the curve, set the maximum to 6, add a pre-fight cue "quick win pays up to 6" on pace types only, show nothing on no-pace types. Correct the fixture: stage 1 (`protect`) pays 24, not 30. Realistic mean with the bonus: about 24 + 0.64 x 6 = 28 at best (COMPUTED); lower with partial and missed bonuses. The "30" end of the band cannot be reached on average.

### 1.5 Replay flat 0.5 — RISKY

- Facts (READ): `run_count` counts completed plus restarted realm runs (`RewardCalc.gd:99`). GDD 20.8: a stage locks on first entry; reruns of an UNRESOLVED stage keep what the player learned; after the Realm is cleared and replayed, "a new stage instance can be generated".
- Anticipation: a flat factor is easy to learn. That part is right (clarity beats the ladder).
- Feedback: the tooltip says "The party has been here before. The whole stage earns less Ase and Ekwan." On a replay the stage is NEW (fresh objectives, hidden again, GDD 20.8). The player has not "been here before" in any way they can feel. Half pay for a new, hidden, possibly harder stage (difficulty scales with completed Realm count, GDD 20.8) reads as a penalty for playing.
- Consequence: the factor does its job (no farm). The cost is a replay that feels like punishment unless the replay pays in something else (Threads, Standing, Storyweight; GDD 7.1, 10.6 per the designer; I did not read them).
- Resolution (PROPOSAL): keep the flat factor. Do not choose the value from the farm risk alone. Ask Jeff what replay is FOR. If replay is for growth, 0.5 is fine. If replay is for the player who wants more Echoes, 0.5 is hostile. Also note: a retry of an unresolved stage is NOT a replay (GDD 20.8). The code must not apply the factor to a retry. READ: `run_count` is a realm counter, so it does not. Confirm with a test (mechanics-developer).

### 1.6 Skill unlock 60 to 120 — FEELS RIGHT

- Anticipation: the price shows next to a Standing gate the player already sees. A price tied to milestone (60 at Standing 3, 90 at 6, 120 at 9) tells the player "mastery costs more" with no explanation.
- Feedback: a skill bought for one Echo changes that Echo at once. That is the reward. The cost is felt as a trade against a summon.
- Consequence: the choice is real because a new Echo also raises income (Echoes row). Depth gives no income. So the economy pulls toward breadth. At 60 the skill and the summon cost the same and breadth wins by default. Starting value: price a first skill at 60 to 80 so the trade is a real one; test with a playtest (do players buy a skill before the third Echo?).
- Risk: per-Echo pricing multiplies with roster size (designer risk 8). Watch the first playtest.

### 1.7 Removing the enemy bonus and the virtue bonus — FEELS RIGHT

- Enemy bonus: the player does not control encounter size in an autobattler. Paying for it gives no lever (ANSWERS #64: the result must state its cause; "more enemies" is not a choice). GDD 19.2 says Ase is paid for acts that "animate, invoke, shape, or spiritually enact change", not for kills.
- Virtue bonus: three hidden inputs, no lever, 59% of the payer. Removing it is a gain in Clarity.
- Cost for Jeff: the UI session has built a "Realm virtue" row and tooltip. Tell it.

### 1.8 Realm scale 1.0 / 1.5 — RISKY

- READ: the designer estimates realm.02 at about 52 per stage at scale 1.5 (not measured). That is a summon every stage. It contradicts the target "after that, one per 2 stages" in the long run.
- Feel: bigger numbers late feel like progress; the same price makes the economy go soft after realm.01. Anticipation of scarcity is lost exactly when the player has the most Echoes.
- Resolution (PROPOSAL): keep realm.02 pay near realm.01 per unit of play time. Realm.02 stages are longer (up to 2 objectives), so per stage it may be higher, but per run cadence should stay near one uncalled summon per 2 stages of play. Jeff decides; measure with the same fixture first.

### 1.9 Retreat before round 1 at 30 Ase — WRONG as it stands

- See section 2.3.

## 2. The three hand-off questions

### 2.1 Cadence feel

Filter: Satisfaction (progress is felt) and Clarity (the player predicts the step).

- Start of the game. READ: GDD 20.7 and 22.4 step 4 put the second Echo BEFORE the first proper stage. GDD 20.12 says the opening grants "almost enough Ase" and the awakening grants a one-time amount so the player can act at once. So the 52 Ase buys the second Echo (price 60; the player needs the last few Ase from somewhere, which the GDD does not say). The player enters stage 0 with about 0 Ase. The designer's "first summon after one stage with 52 in hand" is wrong.
- What the player lives (COMPUTED, R without bonus, 2 Echoes): after stage 0 about 28 of 60; after stage 1 about 52 to 58 of 60; the third Echo arrives after stage 1 or 2. That is "1 to 3 stages" in Jeff's target, and it matches GDD 20.14 ("1 to 3 stages into the opening Realm"). Good. The risk is the 52 to 58 case: 2 to 8 short (section 1.2).
- Steady or a wait? Two results per goal is steady: each stage fills about half of the bar and the player sees it move. Starting value: 2 to 3 results per goal feels like steady progress; 1 feels like a gift; more than 5 feels like a wait. Test: in a playtest, ask the player after each result "how far are you from the next Echo". A correct answer 8 of 10 times means the step is clear.
- The gap between stage 1 and stage 2 is filled by the Sanctum visit and the first social beat (GDD 20.13, 20.14), so the wait is not empty. Do not rely on that for later stages: after the opening there are fewer scripted beats.
- Called (8 to 12 stages) and chosen (25 to 40 stages) are a wait unless the goal is visible. Section 2.3.

### 2.2 Readability

- Is a 6 Ase bonus visible and anticipated before the fight? No. Only the in-fight colour exists (`design.md` section 6). Add a pre-fight cue on pace types (section 1.4). What the player must know before the fight: this objective has a quick-win bonus (yes or no), and its size.
- Does a missed bonus feel fair? Yes if the player saw the goal first, saw the colour turn `none`, and the ledger names the cause in plain words. Today the first is missing. Also fair only if the player had a lever: party and directives change pace. READ: the par is fixed at fight start from distance and move range (`design.md` section 3), so it is deterministic and learnable. That fits "hidden, not random" (GDD 20.8).
- Does Echoes alive read as care? Not as a number. It reads as care when it is a count of people ("Echoes home: 2 of 2") and when a missing Echo is named in the same card, not just a smaller sum. Do not price the person. Voice for Jeff to decide: the player-facing line is Jeff's. Direction only: plain, short, about who came home.
- The ledger is open the first time and closed after (UI D-03). Good for teaching. With fewer rows (3, not 7), the open ledger is short enough to read.

### 2.3 Anticipation

What the player must be able to know (not a screen design):

Before a stage:
1. The size of each objective's payout once that objective is revealed (section 3).
2. Whether this objective has a quick-win bonus, and its size.
3. The cost of retreat, and what it returns (nothing until one objective is overcome, D-14). Today the 30 Ase are paid "whether the retreat works or not" (designer, section 2.1). A cost the player discovers after paying is a trap.

While saving:
4. The current Ase and the price of the next uncalled summon.
5. After each stage result, how far the last result moved the goal ("+28, now 52 of 60").
6. For called (150) and chosen (400): a goal the player chooses to save for and sees all the time. Without it, called and chosen are never reached: the cheap uncalled summon is affordable first every time, so the player spends before reaching 150. The rarity then comes from player choice, not from price. That fits "hard to attain" only if the player KNOWS the choice exists. Starting value: show progress at the half-way mark with one clear moment (a message on the result) so a 25 to 40 stage goal is not forgotten.

Retreat 30: WRONG for a safety valve.
- READ: GDD 20.10 says map-level withdrawal for uncalled Echoes should be available from the start, as a safety valve.
- With income about 24 to 28 and often about 0 Ase at stage 0, 30 Ase is one stage of income (more than the player may hold). It is paid even when the retreat fails. A new player who senses danger and retreats loses a stage of progress and gets nothing. That teaches "never retreat", which makes the permadeath stakes (GDD 20.10) worse.
- What to do (PROPOSAL, Jeff decides): lower the price to about one third of a stage (starting value: 8 to 10); state the price before the choice; keep "pays 0 until one objective is overcome". Also decide the case "balance below the price". ASK mechanics-developer what the code does then (not checked).
- If Jeff wants retreat to be a hard choice, the cost can stay high for later realms only, never for the opening.

## 3. Pre-entry reward: the honest form of an ESTIMATE (D-38)

Jeff (D-38): no exact promise now. An ESTIMATE of Ase and Ekwan in the stage overview "would be nice". Not part of Part A; it needs its own design. This section advises on that design.

Facts (READ):
- GDD 20.7: before entry only a rough lead or target area is known; some objective details are hidden.
- GDD 20.8: good intel reliably reveals objective type and location. Other elements reveal unevenly. A stage has up to 3 objectives. The stage locks on first entry. "Anything shown as decision-critical must be readable and truthful."
- Payout depends on objective type (weight table), and only completed objectives pay (D-11, D-12).
- D-24: the stage-ending card previews the payment with the same code that pays. D-25: no mid-stage stage preview.

What an estimate may NOT do:
1. Show a number for an objective whose type the player has not learned. The number reveals the type (weights differ by type).
2. Show a total. The count of objectives, and which are optional, may be hidden. A total is wrong or leaks.
3. Show 0 for a hidden objective. Zero reads as "worth nothing". Hidden must read as "not yet known".
4. Count the conditional rows (Echoes home, quick-win bonus) as promised. They depend on the fight.

Options:

| Option | Shows | Honest? | Hidden-info fit | Feel |
|---|---|---|---|---|
| A. Revealed objectives only, exact | The weight of each objective whose type is known; "not yet known" for the rest | Yes, if labelled "if overcome" | Full. Scouting now reveals a reward, so intel pays off | Clear. Number equals the later ledger row, so no cheat feeling |
| B. Range per stage | One band "about X to Y" from the locked stage | Only if X is the true minimum and Y the true maximum of that locked instance | Weak. The band is computed from hidden content and narrows as intel arrives (a hidden signal) | Vague. Wide bands are useless; narrow bands leak the type |
| C. Coarse tier word | "Small / fair / rich" for the lead alone | Yes if tiers come from fixed thresholds | Fits 20.7 (a rough lead) | Safe but weak; hard to compare with the later number |
| D. A + range on the unknown part | Option A for revealed objectives, plus "and more" or a minimum for the unknown part | Yes if the minimum is real | Good | Honest; the open part is visible as open |

Recommendation (PROPOSAL): Option A, exact per revealed objective, with the words "if overcome". For the unknown part show only "more not yet known". No stage total. Show Ase and Ekwan side by side per objective, both from the same completed-only rule.

How estimate and payout must relate (so the player does not feel cheated):
1. One producer. The estimate per objective and the stage payment use the same row code (the D-24 pattern). A test proves estimate row == paid row for the same objective and the same state.
2. One rounding point. The payment rounds once on the sum (round 1 section 3.2). A per-objective estimate that rounds each objective can differ by 1 from the sum. Fix: show the estimate before the realm scale and replay factor are applied only if the overview says "base"; better, apply scale and replay inside the estimate, so the number is what would be paid for that objective. Then allow the final total to differ from the sum of estimates by at most the rounding of one step. Or round per objective in the payment too. Jeff decides; mechanics-developer states which one the code can support.
3. Never below what is paid. If the estimate and payout can differ, the payout must be at least the estimate for the same conditions. Under-promise, never over-promise. A lower payout than shown feels like theft; a higher one feels like luck.
4. Completed-only. The estimate says "if overcome". An objective the party skips or fails pays nothing (D-11). The ledger then shows "Objectives overcome 2 of 3". The estimate and ledger use the same words so the gap is explained.
5. Replay and scale show in the estimate when they apply (a replay stage shows the reduced number), so no cut appears for the first time at the result.
6. Conditional rows are rules, not numbers: "Echoes home pay X each" and "a quick win pays up to Y". They sit beside the estimate and are not added into it.
7. The estimate updates when intel arrives. A revealed objective gains its number. Nothing already shown may change. Because the stage instance locks (20.8), a shown number stays true.

What the backend would have to expose (names only, no design):
- a read-only list of objectives with a per-objective "revealed" state;
- for each revealed objective: its Ase and Ekwan if overcome;
- the standing per-Echo amount and the pace-bonus maximum for that objective type, or "none";
- the realm scale and the replay factor in force;
- a flag "unknown objectives remain".
The objective-reveal state exists in the intel system (GDD 20.8). I did not check how the code stores it (ASSUMED present).

Answer to the round 1 question: no exact whole-stage promise (D-38 agrees). The honest estimate is per revealed objective, exact, "if overcome".

## 4. Does GDD 20.8 or 19.2 change designer advice?

Changes:
1. Replay (20.8): the new stage instance after a Realm clear means "has been here before" is not true to the player. The tooltip and the 0.5 value need Jeff's view on what replay is for (section 1.5). A retry of an unresolved stage must NOT take the factor (20.8 "reruns of that unresolved stage should preserve what the player is learning").
2. Replay "farm" worry (round 1 finding 3): the farm is a new, hidden stage each time, not the same stage. The risk is real but the stage is different; a flat 0.5 is not the only tool. No change to the recommendation to use a flat factor.
3. Pre-entry preview (20.7, 20.8): total promise not possible; per-objective promise yes (section 3). Changes round 1's open question.
4. Starting Ase (20.7, 22.4, 20.12): the opening 52 pays the second Echo. Round 1's cadence table "starting Ase 52" is the wrong column. Use the "starting Ase 0" column (round 1 section 2.4).
5. Accrual (19.2): the designer's reading holds. 19.2 says offline Ase supports return cadence and is "never the primary source". It tapers with time away and falls toward near-zero with strain or vow fracture. So 18 to 31 per return is the ceiling, not the floor, in a strained house. No change to numbers. Feel: the return message should name it (19.2: "acknowledged with a short return message").
6. Ase sinks (19.2): Ase is also for rites and Thread handling. Those will compete with summons. The cadence "one per 2 stages" must be read as gross, before rites. If rites are added, net cadence slows without an income change. Flag for Part B.
7. "Baseline Realm entry should generally not cost Ase" (19.2): a retreat price is not an entry cost, but a high price near the entry decision feels like one. Supports lowering it (section 2.3).
8. Ekwan (19.2): "shaped matter, stored labor, build capacity". Round 1 leaves Ekwan alone. I agree. Its feel role: it arrives only on the stage-ending card (D-28, UI D-15), outside the Ase total. No change.

## 5. Disagreements with the designer, ranked

| Rank | Disagreement | Reason | Proposed resolution |
|---|---|---|---|
| 1 | "52 Ase unspent" (round 1 section 2.4, OPEN ASSUMED 3) | GDD 20.7, 22.4 step 4, 20.12: the second Echo is summoned before stage 0. | Use starting Ase about 0. The first summon after the opening is the third Echo, 1 to 3 stages in. |
| 2 | Bonus applied to every stage in the fixture; "30 per stage" | `protect`, `endure`, `guide_spirit` protect have no pace bonus. About one third of realm.01 stages. | Correct the fixture (stage 1 pays 24). Target band 24 to about 28. Show no bonus row on those types. |
| 3 | Pace bonus becomes "fixed, met or not" | Shipped design has `full`, `partial`, `none` and colour for each. Binary at 6 makes a miss feel like a fine. | Keep the curve. Fix only the maximum at 6. |
| 4 | Echoes alive: per-Echo flat at 6 | Half of income; never changes; trivial next to permadeath; grows with roster. | Show a count; cap counted Echoes (starting value 3); do not price the death. Jeff decides the cap. |
| 5 | Retreat 30 left as an open question | It is a trap for the opening, against the safety-valve text in 20.10. | Lower to about 8 to 10 and state before the choice (PROPOSAL). |
| 6 | Realm scale 1.5 | Realm.02 about a summon per stage; cadence breaks after realm.01. | Keep per-run cadence near realm.01. Jeff decides. |
| 7 | Replay 0.5 judged on farm risk only | The replay stage is new and hidden (20.8). Half pay reads as punishment unless replay pays elsewhere. | Ask what replay is for. Keep a flat factor. Never apply to retries. |
| 8 | Round 1 "R" ignores the shipped UI contract | UI built `enemies_defeated`, `realm_virtue` rows, per-fight Echoes and bonus rows. | Tell the UI session which rows leave. Decide Echoes-alive and bonus at fight level. |
| 9 | Round 1 asks for an exact pre-entry reward | Dishonest or leaking under 20.7 and 20.8. Jeff (D-38) wants only an estimate, later. | Option A of section 3: exact per revealed objective, "if overcome". |

Agreed with the designer: remove the enemy bonus and virtue bonus (section 1.7); keep Echoes-alive as a row; flat replay factor; skill price tiers by milestone; assume (a) for called and chosen (keep prices, trust spending).

### What I would tell Jeff in 5 lines

1. The shape of R feels right: three rows, each with a lever. The numbers need three repairs.
2. The opening Ase buys the second Echo (GDD 22.4), so the first summon is the third Echo, 1 to 3 stages in. Fix the table column.
3. Keep the pace bonus as a curve with a maximum of 6, and show the goal before the fight. About one third of stages have no bonus.
4. Lower the retreat price to about 8 to 10 and show it before the choice. A 30 Ase retreat is a trap in the opening.
5. Pre-entry (D-38): later, show an ESTIMATE only per revealed objective, "if overcome", never as a stage total. Called and chosen need one goal the player sees at all times.

## 6. Sources used

Skills loaded: `game-design` (5-component filter, "what just happened and why" test, cadence and feedback checks); `echoes-sankofa-gdd` (loaded; I did not open its map file `docs/skills/echoes-sankofa-gdd.md`, I used `docs/canon-index.md` ranges instead).

GDD ranges read (line numbers in `docs/Echoes vNext Working GDD.md`):

| Lines | Section | Used for |
|---|---|---|
| 97-114 | 4 Player Role and Fantasy | Keeper role: caretaker, not a general (autobattler fit) |
| 125-132 | 5 Sanctum and Realms (opening only) | Realms test what the Sanctum shaped |
| 3454-3515 | 19.2 Currency roles | Ase and Ekwan roles, offline accrual, no Ase for baseline Realm entry |
| 3819-3837 | 20.7 First proper Realm stage | Second Echo before stage 0; hidden details |
| 3838-4003 | 20.8 Stage structure, scouting, reruns | Lock on entry; new instance after Realm clear; intel rules; up to 3 objectives |
| 4018-4026 | 20.10 Failure and withdrawal | Permadeath core; withdrawal as safety valve |
| 4116-4172 | 20.12, 20.13, 20.14 | Opening Ase; social beat; first 30 minutes |
| 4334-4342 | Death, withdrawal, loss | "permadeath remains core" |
| 4625-4645 | 22.4 Foundation cutline | Summon of the second Echo is step 4, before the first stage |

Not read by me: GDD 5 (full), 7.1, 10.6, 21.1. I take the designer's citations of 7.1 and 10.6 on trust (not verified).

Per-claim citations:
- Second Echo summoned before stage 0: 20.7 (line 3821), 22.4 step 4 (line 4638), 20.12.
- Stage locks on entry, new instance after Realm clear: 20.8.
- Objective type and location are the reliable reveals; decision-critical info must be truthful: 20.8 "Current intel-reveal rule".
- Withdrawal is a safety valve; permadeath core: 20.10 (line 4018-4022), line 4338.
- Offline accrual supports cadence, never primary; tapers; baseline entry costs no Ase: 19.2.
- 1 to 3 stages in 30 minutes: 20.14.
- Pace modes and no-pace modes; three-state colour; no pace goal visible before the fight: `docs/stories/pace-reward/design.md` lines 61-62, 148, section 6.
- Realm.01 type counts: `phase1-characterization.md` section 2.
- Shipped UI rows, tooltips, fight/stage groups: UI `v2-payout-explanation/decisions.md` D-05, D-12, D-13, D-14, D-15.
- No mid-stage preview: D-25 (`decisions.md`).

GDD gaps (QUESTIONS for Jeff):
1. Where does the missing Ase for the second Echo come from (price 60, opening 52)? The GDD says "almost enough" (20.12) but names no source.
2. How long is one stage in play time? The GDD and code say nothing (the designer assumed 8 to 12 minutes).
3. What is replay for (Ase, growth, or story)? GDD 20.8 names new instances but not their reward intent.
4. Is there a party size cap? Not found.
5. Does a pace-type pre-fight cue break the "hidden, not random" rule? The par is derived from visible board data, so I think not; the GDD does not say.

## OPEN — questions and assumptions

ASSUMED: One third of realm.01 stages have no pace bonus | WHY: Phase 1 counts (protect 88, endure 104 of 700) plus half of `guide_spirit` as protect variant | WRONG IF: the escort/protect split of `guide_spirit` differs a lot, or realm.01 draws change
ASSUMED: The opening 52 Ase pays the second Echo, and the shortfall is covered by an unknown source | WHY: GDD 20.7, 22.4 step 4, 20.12 | WRONG IF: the second Echo is free (not a paid summon); then the designer's 52-in-hand reading is right
ASSUMED: A stage is one fight in realm.01 (one pre-boss objective, boss is a stub with weight 0) | WHY: Phase 1 section 2 | WRONG IF: the boss stub becomes a real fight
ASSUMED: The pace bonus is paid per fight in the code (as in `pace-reward` design) | WHY: `pace_state` is per encounter | WRONG IF: Part A already moved it to the stage level
BLOCKED: Is the "first summon" in Jeff's target the SECOND Echo (before stage 0) or the THIRD Echo (after the opening)? | CHECKED: GDD 20.7, 20.12, 22.4; D-36, D-37 | NEED: Jeff. I read it as the third Echo.
BLOCKED: What is replay for, and may the pre-fight cue for the pace goal exist? | CHECKED: GDD 20.8, `pace-reward/design.md` section 6 | NEED: Jeff
BLOCKED: What does the code do when the balance is below the retreat price? | CHECKED: not checked (read-only, no code dive) | NEED: mechanics-developer
BLOCKED: Should Echoes alive and the bonus pay per fight or per stage in realm.02? | CHECKED: UI D-12, round 1 section 3.2 | NEED: Jeff or the designer
BLOCKED: Pre-entry estimate (D-38, option A): does the UI session accept it, and which rounding rule? | CHECKED: UI D-12, D-13 | NEED: UI session via the main chat
