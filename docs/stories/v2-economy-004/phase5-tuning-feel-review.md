# V2-ECONOMY-004 Phase 5 — Tuning proposal, feel review (round 5, game-feel-developer)

Written in STE. Every number is a PROPOSAL. Jeff decides. Nothing here is in `data/balance.json`. I ran no code and no Godot.
Tags: READ = from a file I opened. COMPUTED = my arithmetic. ASSUMED = not verified. MEMORY = from my general knowledge of other games, not checked now.
Rank order follows D-48: game quality first (clear, engaging, fun, the Echoes pillar). Build size is not used.
Reviewed: `phase5-tuning-proposal.md` (sr-game-designer), `decisions.md` D-40 to D-56, my earlier files. `phase5-risk-probe.md` does not exist yet, so nothing here uses probe data.
Scale: FEELS RIGHT / RISKY / WRONG. Each reason is tagged anticipation (what the player sees before), feedback (at the moment), consequence (what changes next).

## 0. Findings first

1. The summon price curve is good for pacing. It is only fair if the player can SEE the next price, the house count that sets it, and a plain reason. Without that it reads as a hidden formula and a tax.
2. Counting living Echoes only is right for recovery after loss. It gives no Ase profit from a death (section 4). The risk is tone: a lower price shown right after a death.
3. The weight ORDER (pursue lowest, guide_spirit highest) was never checked against effort or danger. Its stated reason for pursue no longer holds after D-11 (section 5). Verify it with data before the player learns it.
4. A flat premium makes called and chosen cheaper in relative terms as the house grows. At Echo 12 a called summon is +30% over an uncalled one. That breaks "special and rare" (D-37).
5. A curve of x1.2 per Echo closes the large-house path (Echo 16 costs about 620). GDD 18.8 says large houses must be valid. Add a plateau.
6. The doubled weights, realm.02 scale 1.25, skill prices, retreat 10 and unchanged accrual all feel right.

## 1. Per knob

| Knob | Verdict | Why |
|---|---|---|
| Objective weights x2 (size) | FEELS RIGHT | Anticipation: a stage pays 20 to 36, so one result moves a goal of 60 by a third to a half. That is the step size I advised (2 to 3 results per goal). Feedback: the numbers are big enough to read, small enough to feel scarce. Consequence: Echo 3 in 2 stages for most types, 3 for pursue and combat. That is inside "1 to 3" (D-36, D-39). |
| Weight order (pursue 16, combat 20, recover 24, protect 24, endure 28, shrine 30, guide_spirit 32) | RISKY | See section 5. The order came from type descriptions, not from measured effort or risk (`phase3-weights-proposal.md` line 20, ASSUMED). |
| Realm.02 scale 1.25 | FEELS RIGHT | Anticipation: "later pays more" is true per stage (61 against 38) and slightly true per minute (+8%). Feedback: a two-objective stage shows two rows of pay, so the jump is readable. Consequence: Echo 5 to 8 arrive in 1.4 to 2.4 stages, faster than "one per 2" early in realm.02, then the price slows it. Acceptable. Check: the GDD says 4 to 6 stages per Realm (20.8), the data uses 3 to 4 and 5 to 7 (designer gap 5). |
| Summon price curve for Echo 3 to 12 (60, 70, 85, 100, 120, 145, 175, 210, 250, 300) | RISKY | Right shape, but see sections 2 to 4: it needs a visible next price and reason, a plateau for large houses, and a tone rule after a death. |
| Called and chosen as roster price + fixed premium (+90, +340 to 800) | RISKY | Readable ("choosing costs a fixed 90 more"). But rarity decays: called is 2.5x an uncalled summon at Echo 3 and 1.3x at Echo 12 (COMPUTED from the designer's table: 150/60, 390/300). A chosen calling then becomes a routine late buy. See section 6, item 4. |
| Skill unlock 60 / 90 / 120 by Standing, flat against roster | FEELS RIGHT | Anticipation: the price sits beside a Standing gate the player already sees. Feedback: the Echo changes at once. Consequence: depth stays flat while breadth gets dearer, so the economy leans from collecting to deepening near Echo 7 to 8. That serves the pillar. Condition: depth must be available. Skills need Standing 3 / 6 / 9, so a house of low-Standing Echoes has nothing to deepen. Then a priced-up summon is the only sink and the wall feels invisible. Playtest: at Echo 8, does the player have a skill they can buy? |
| Retreat 10 | FEELS RIGHT | A flat price protects people (more Echoes at risk, same price). It is a visible, fair choice. It stays cheap enough not to stop risk-taking (D-47): the stakes are the Thread and the Echoes, not the 10 Ase. |
| Vow break prices unchanged | not judged | I have no feel evidence on vows. One flag from the designer's own finding: `VowService.spend_ase` denies the whole spend when funds are short. The player must be told why, in the moment. A silent refusal is a Clarity failure. |
| Accrual unchanged (about 7 to 9% of a stage) | FEELS RIGHT | It cannot fill the house alone (Echo 8 in about 4 days of accrual alone). It stays a welcome-back trickle (GDD 19.2: never the primary source, tapering). The return message should name it. |
| Replay 0.35 on Ase and Ekwan; stipend halved (D-53, D-54) | FEELS RIGHT | Replay pays about 40% of a first run, so it cannot farm a house (4 to 18 stages per Echo). Its purpose is mastery and Threads (D-53). Risk: a replay stage pays 10 to 17. Do not let the Thread-quality goal depend on Ase. |
| Stage Ekwan and sinks | not changed | Agreed with the designer: Ekwan has few sinks until Part B. |

## 2. The cadence feel: the first summon, then the filling house

First summon (Echo 3) from about 0 Ase: after stage 0 the bar shows 24 to 36 of 60; after stage 1 it passes 60 for most draws. This is steady: two results fill one goal. For pursue and combat stages it takes a third result (20 or 24 each). A third result is acceptable, and it matches GDD 20.14 (1 to 3 stages in 30 minutes). One stage is not possible, and the designer is right not to chase it (it would need about 3.5x weights).

The house filling:
| Stretch | What the designer's table gives | How it feels |
|---|---|---|
| Echo 3 to 4 in realm.01 | about 2 stages each | Steady. A new face about every 2 stages. |
| Echo 5 to 8 in realm.02 | 1.4 to 2.4 stages each | Fast and rewarding: the house grows, the player is trusted. |
| Echo 9 to 12 in realm.02 | 2.9 to 4.9 stages each | The house visibly fills. A 3 to 5 stage wait is long but not a wall IF the player has other things to buy and can see the goal. |

Does a rising price read as a fair house growing, a punishment for success, or an invisible wall? It depends on three things the table does not show:
1. Anticipation. The player must know the price BEFORE they start saving: "next Echo: X". If the price is only visible on the summon screen, saving feels like walking into a wall.
2. Feedback. At each result the card should show how far the stage moved the goal ("now 52 of 85"), as in my round 2 section 2.1.
3. Consequence. The price must not move without a cause the player can see. Two cases break trust: an Echo arrives by recruit (the earned return, ANSWERS #28; designer risk 8) and the price rises while the player is saving; an Echo dies and the price falls. In both cases the new price and its cause must appear at the same moment as the event.

What the player must be able to know (not a UI design):
- The number of living Echoes in the house.
- The price of the next Echo, and the one after it (starting value: two prices ahead). The curve is then visible, not a hidden formula.
- A plain reason for the rise. Direction (copy is Jeff's, and the frame is a proposal, not canon): the price is what it costs to hold one more life in the house. This ties the price to LIVING Echoes in the fiction. A death frees room; a summon takes it. Ase is "living spiritual force spent" (GDD 19.2), so the frame fits. QUESTION for Jeff: is this fiction acceptable? Without any reason, a price that rises is a tax.
- Called and chosen: the fixed extra for choosing, shown as its own line, not folded into the total.

## 3. Population regulation: "the house is full" or "the game taxes me"?

Honest answer: a price alone usually reads as a tax. It reads as "the house is full" only when the player sees a reason tied to the house. A bare number going up reads as the game charging for success.

What I know of other games (MEMORY, not verified now; use only as pattern evidence):
- Idle and incremental games commonly raise the price of each purchase by a fixed ratio per item owned. Players read this as a treadmill, a pace brake, not as a world rule. It works for pacing and not for fiction.
- Roster games with permadeath, such as Darkest Dungeon, limit the roster through a building the player expands, not through a rising price per recruit. The limit is a place in the world.
- Gacha games commonly cap the roster with slots, and sell slot expansion. The limit is explicit and countable.
I do not know how any one of these games measured player reaction. I use them only to say that a visible, countable limit is a common pattern for "full", and a rising price is a common pattern for pacing.

GDD context (READ):
- 18.8 (lines 3325-3336): a smaller house can reach high Continuity; a larger house can reach it too; "population count alone" must not define maturity; the player must not be "forced into one ideal population model".
- 19.2 (line 3496): Ekwan is "shaped matter, stored labor, and build capacity"; its uses include rooms and buildings.
- 20.8: roster strength is only a secondary smoothing factor for difficulty.
- I found no GDD text on roster capacity or a population target (grep for capacity, housing, beds, roster limit).

Options (designer's P-A, P-B, P-C), ranked by game quality:
| Option | Verdict | Reason |
|---|---|---|
| P-A: comfortable 7 to 10, soft ceiling about 12 | FEELS RIGHT, with a plateau | A house the player can know supports the pillar (attachment and growth over time) and leaves 2 reserves behind a party of 5 under permadeath. Soft regulation fits 18.8 better than a hard cap. |
| P-B: 5 to 7 | RISKY | One bad run empties the house. The party is the whole house. The rising price at Echo 8 is 235 (x1.35), which makes recovery after a wipe slow. Only safe if living-only counting makes rebuilding cheap. |
| P-C: 12 to 16 | RISKY | The brake is too light to regulate (the designer's own reading). The attention and bond-graph concern (66 pairs at 12) is real for the pillar. |

Recommendation (PROPOSAL): P-A, with two repairs.
1. A plateau, so a large house stays possible (GDD 18.8). With x1.2 per Echo, Echo 13 to 16 cost about 360, 435, 520 and 625 (COMPUTED from the designer's formula). That closes the large-house path, against 18.8. PROPOSAL: from Echo 12 add a fixed step instead of a ratio (for example +50 per Echo), so a player who chooses a big household can still reach it slowly. Jeff decides the number.
2. A visible reason and a visible next price (section 2). Without them P-A is a tax.
Option to discuss with Jeff (new mechanic, not a repair; GDD 19.2 lists rooms and buildings as an Ekwan use): a house-capacity rule through rooms built with Ekwan would make "the house is full" literal and readable, and it gives Ekwan a sink. It is a different design from a price curve. I do not recommend inventing it in this phase. I name it as the better long-term form of "full", for the sr-game-designer to weigh against the price curve.

## 4. Does counting LIVING Echoes only create a perverse feeling?

Incentive check (COMPUTED from the designer's curve): the price drop from one death is one step: 120 to 100 at roster 6, 175 to 145 at roster 8, 250 to 210 at roster 10, so 20 to 40 Ase. The lost Echo cost at least its own summon price (60 to 250) plus any skills (up to 270). A player never gains Ase by letting an Echo die, for any ratio below 2. There is no Ase incentive to sacrifice. Good.

Remaining problems:
1. Tone. A summon screen that shows a cheaper price right after a death says "replacements are cheaper". It cheapens the person. This breaks the D-42 feeling (survival must feel rewarding). Fix: show the new price as the plain next price, with the house count ("7 living"). No "discount" wording, no highlight on the change, no comparison line against the old price. Let the Sanctum death ripple (GDD 20.10) land first.
2. Fodder risk. Deliberately sending weak Echoes into danger to lower the price is not profitable (above), but a stage with a loss now has a small silver lining. The Thread rule (D-50: any death compromises the Thread) and the stipend loss keep a cost on every death. Keep both.
3. Why living-only is right: a wipe (for example 2 of 5 lost) leaves the player with a smaller house and a smaller income (stipend). A price that did not fall would trap them. Counting living Echoes gives a way back. This supports D-47 (the player may take risks and live with loss).
4. Fix for any remaining doubt (PROPOSAL, for Jeff): never describe the price change in terms of a death. The price follows the count of living Echoes in the house. That is all.

## 5. Weights ordering and doubling: does payout feel right per type?

Size: doubled weights give 16 to 32 per objective. Right for the cadence (section 1).

Order (READ: `phase3-weights-proposal.md` lines 11 to 39, 55 to 66, and `phase4-ekwan-proposal.md` line 31, 207):
- The order is the sr-game-designer's judgement from type descriptions ("my judgement", line 20). It was not checked against fight length or loss rate.
- `pursue` is lowest because (line 39) it "pays even when the player skips it". D-11 (pay only completed objectives) removed that reason. The low pursue weight now rests on nothing.
- `guide_spirit` is highest (32) with a low Ekwan on purpose: "reads as Ase (life force), not matter". That fits GDD 19.2 (Ase animates; Ekwan is matter and labour). It is a good fiction reason. FEELS RIGHT for that type.
- `endure` 28 and `shrine` 30 come after `protect` and `recover` at 24. A hold-the-line fight with no early end earns more than a recover. Plausible, unverified.

Feel consequences:
- Anticipation: the player cannot see the order today. It becomes visible only when the later pre-entry estimate exists (D-38: per revealed objective). Then the order is a message: "this is worth more". It must agree with the felt difficulty, or the player stops trusting the numbers.
- Feedback: the stage-ending card shows one "objectives overcome" row with a total. The player cannot learn the order from the card alone. The ledger tooltip would have to name the objective types.
- Consequence: a 2x spread between pursue (16) and guide_spirit (32) makes income swing by luck of the draw. Echo 3 takes 2 or 3 stages by draw, not by skill. That is a luck feel unless the player can read the stage lead and choose.

Verdict: the ORDER is RISKY. Resolution (PROPOSAL): before the player sees it, check the order against two measurable things per type: median fight rounds and Echo loss rate per fight. The risk probe (D-52) records loss rate; ask it to report per objective type too. If the data disagrees with the order, change the order, keep the doubling.

## 6. Disagreements with the designer, ranked

| Rank | Disagreement | Reason | Proposed resolution |
|---|---|---|---|
| 1 | The rising price is described as a lever, without the visible next price and reason | Without them it is a hidden formula, and it reads as a tax (Clarity) | Make "living count, next price, price after, reason" part of the proposal itself (section 2) |
| 2 | x1.2 forever | Closes the large-house path (Echo 16 about 620), against GDD 18.8 | Plateau after Echo 12 (section 3) |
| 3 | Weight order is accepted as set | Never measured; pursue's reason is gone after D-11 | Check against rounds and loss rate per type before showing it |
| 4 | Called and chosen as a flat premium | Called goes from 2.5x to 1.3x the uncalled price; rarity decays; D-37 wants them special | Keep the premium visible as its own line; test whether players buy called whenever affordable late. If yes, raise the called premium toward 150 to 180 (about 2.5 to 3 realm.02 stages of extra saving). Jeff decides |
| 5 | Living-only is advised mainly as an economy rule | Its real risk is tone after a death, not a perverse Ase incentive | Keep it. Add the display rule: no discount wording (section 4) |
| 6 | Skill price "does not rise with roster" as an automatic pull to depth | Depth is gated by Standing; low-Standing houses have nothing to buy | Playtest the case "Echo 8, all Echoes below Standing 3"; if it stalls, pace Standing growth or accept it until Part B sinks |
| 7 | The opening summon (Echo 2: 60 against 52 Ase) left as a question | The first purchase being 8 short is the worst moment to meet a wall (GDD 20.12 says "almost enough") | Resolve before the tuning is final; the designer's idea of 50 for Echo 2 is acceptable |
| 8 | Agreed with: doubled weights, realm.02 1.25, skills 60 / 90 / 120, retreat 10, accrual unchanged, replay 0.35 | Pass the filter | No change |

### What I would tell Jeff in 5 lines

1. The numbers mostly feel right. Echo 3 in 2 to 3 stages, then a house that fills and slows, is a good shape.
2. A rising summon price reads as a tax unless the player sees the living count, the next two prices and one plain reason.
3. Counting living Echoes only is safe: a death never pays Ase. Just do not show a "cheaper now" message after a death.
4. Add a plateau after about Echo 12, so a large house stays possible (GDD 18.8), and watch that called and chosen stay rare late.
5. Check the weight order against real fight data first. Pursue's low weight lost its reason when D-11 landed.

## 7. Sources used

Skills loaded in this session: `game-design` (Clarity, Motivation, Satisfaction tests; perverse incentive and false-agency checks); `echoes-sankofa-gdd` (canon lookup by line range). No other skill.

GDD (`docs/Echoes vNext Working GDD.md`):
| Lines | Section | Used for |
|---|---|---|
| 3325-3336 | 18.8 High Continuity through different house shapes | No single ideal population; large and small houses are both valid |
| 3454-3515 | 19.2 Currency roles (read earlier) | Ase is living force; Ekwan is shaped matter, labour and build capacity; offline accrual never primary |
| 3838-4003 | 20.8 (read earlier) | Realm difficulty by completed Realms; roster only secondary |
| 4116-4172 | 20.12, 20.14 (read earlier) | Opening Ase almost enough; 1 to 3 stages in 30 minutes |
| 4018-4026, 4334-4342 | 20.10, death and loss (read earlier) | Permadeath core; death ripple |
| 2094-2114, 2590-2612 | 14.3, 15.6 (read earlier) | Deaths lower Thread quality; remedy routes |
Grep of the GDD for capacity, housing, beds, "roster limit", "house size": no roster or population limit text. Lines 2225 (reserve capacity, about Threads) and 3529 (loadout) are not about Echoes in the house.
Other READ: `phase5-tuning-proposal.md` (all); `decisions.md` D-40 to D-56; `phase3-weights-proposal.md` lines 11 to 66; `phase4-ekwan-proposal.md` lines 31 and 207; my files `phase5-feel-review.md`, `phase5-echoes-alive-recheck.md`, `phase5-risk-feel-review.md`.
Not read: `data/balance.json`, the objective handlers, the roster and party text near GDD lines 311, 4564 and 4581. MEMORY claims in section 3 are unverified general knowledge.

GDD gaps (QUESTIONS for Jeff):
1. What population range does the game want? GDD 18.8 names none.
2. Is the fiction frame "the price of holding one more life in the house" acceptable, or does the price need another reason?
3. Should population be limited by a price curve alone, or also by house space built with Ekwan (GDD 19.2 lists rooms as an Ekwan use)?
4. How does the opening afford Echo 2 (52 Ase against 60)?
5. Is `pursue` still optional (skippable) after D-11, and does it deserve the lowest weight?

## OPEN — questions and assumptions

ASSUMED: The designer's price table (Echo 3 to 12) and stage income figures are correct as given | WHY: I did not recompute the whole table; I checked drops and ratios only | WRONG IF: the designer's income assumptions (stage time, party size, no losses) differ in play
ASSUMED: No release or dismiss action exists | WHY: the designer reports none in `SanctumService` | WRONG IF: a release action exists; then the living-only price could be reset by the player
ASSUMED: Recruits (ANSWERS #28) arrive without a price and raise the next price | WHY: designer risk 8 | WRONG IF: recruits do not count in the house
ASSUMED: My MEMORY examples (idle price ratios, Darkest Dungeon roster building, gacha slot caps) are accurate in outline | WHY: general knowledge | WRONG IF: Jeff wants evidence; then a source search is needed
BLOCKED: Population range (P-A with plateau, P-B, P-C) | CHECKED: GDD 18.8, grep for capacity | NEED: Jeff
BLOCKED: Reason shown for a rising price (fiction frame) | CHECKED: GDD 19.2 | NEED: Jeff (copy and fiction)
BLOCKED: Is a rooms-with-Ekwan capacity rule wanted instead of, or beside, the price curve? | CHECKED: GDD 19.2 | NEED: Jeff and sr-game-designer
BLOCKED: Weight order check by fight rounds and loss rate per objective type | CHECKED: phase 3 proposal (judgement only) | NEED: the risk probe (D-52), if it can report per type
BLOCKED: Called and chosen premium value and whether they should keep a visible separate line | CHECKED: designer section 3.3 | NEED: Jeff, and a playtest on late called purchases
BLOCKED: Echo 2 price against 52 opening Ase | CHECKED: designer question 4, D-39 | NEED: Jeff or mechanics-developer
