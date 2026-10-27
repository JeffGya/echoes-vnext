# V2-ECONOMY-004 Phase 5 — Echoes-alive recheck (D-41), game-feel-developer

Written in STE. Every number is a PROPOSAL. Jeff decides. Nothing is in `data/balance.json`.
Tags: READ = from a file I opened. COMPUTED = my arithmetic. ASSUMED = not verified.
Inputs: D-39, D-40, D-41 (`decisions.md`), `phase5-feel-review.md` (my round 2), `phase5-design-advice.md` (round 1).

## 1. Curve for 1 to 5 Echoes alive (full party = 5, `data.sanctum.party_max_size`)

Reading A: flat amount per Echo up to a cap. Reading B: the total falls by a percentage for each missing member.
Both readings give the SAME table when the percentage is taken from the full-party total (not compounded).

| Echoes alive | Total Ase (PROPOSAL) | Per Echo | Reading B: 10 x (1 - 20% x missing) |
|---|---|---|---|
| 1 | 2 | 2 | 10 x 0.2 = 2 |
| 2 | 4 | 2 | 10 x 0.4 = 4 |
| 3 | 6 | 2 | 10 x 0.6 = 6 |
| 4 | 8 | 2 | 10 x 0.8 = 8 |
| 5 | 10 | 2 | 10 x 1.0 = 10 |

COMPUTED: 2 Echoes pay 4 and 5 Echoes pay 10. Both targets in D-41 hold. The party-of-2 maximum "4 maybe" is not a special case. It falls out of 2 Ase per Echo. One rule covers every party size: PROPOSAL 2 Ase per Echo alive, cap 10 (the cap equals 5 x 2, so the cap only matters if `party_max_size` rises).

Why not a compounding percentage (each missing member removes X% of what is left):
- To pay 4 at 2 Echoes, X is about 26%. The table becomes 10 / 7.4 / 5.4 / 4.0 / 2.9 (COMPUTED).
- Per Echo that is 2.0 / 1.85 / 1.8 / 2.0 / 2.9. A lone Echo gets the highest rate. The player cannot predict it. This fails the Clarity test.
Use the linear table. The player can learn "2 per Echo" in one result.

## 2. Alive at the end, or Echoes lost?

PROPOSAL: count the Echoes ALIVE at the end of the win. Show the count as alive of started ("4 of 5").

Fairness check:
| Case | Pay under "alive at end, 2 each" | Pay under "percent of lost, from the starting party" |
|---|---|---|
| Party of 5, lost 1 | 8 | 8 (20% off 10) |
| Party of 4, lost 0 | 8 | 10 if the full total is kept, or 8 if the maximum follows party size |
| Party of 1, lost 0 | 2 | 10 if the full total is kept |

- A "lost" rule that keeps 10 for a clean small party pays a lone Echo the same as a full party. That is a solo-farm incentive and it rewards bringing fewer Echoes. Reject it.
- If the maximum follows party size (2 per Echo started), "lost" and "alive" give the same Ase. Then "alive" is the simpler rule and needs no memory of the starting size.
- The two cases in the brief (5 lost 1, 4 lost 0) both pay 8. They differ only in the count shown ("4 of 5" and "4 of 4"). The count carries the difference in care. I think that is fair: the Ase pays who came home, the count shows who did not.
- Bringing a bigger party pays more (+2 each). The incentive is mild. The party also faces more risk and the real cost of a death is the Echo (GDD 20.10, line 4338: "permadeath remains core").

Edge cases to decide (ASSUMED, not checked):
1. "Alive" means not dead. A downed Echo that survives counts. A withdrawn Echo counts as alive. Ask Jeff and mechanics-developer.
2. Timing: pay per fight win (as the shipped UI does, UI `decisions.md` D-12) or once on the stage-ending card. Per fight, the realm.02 maximum is 10 per fight, so up to 20 per stage with 2 objectives (Phase 1 section 2). Once per stage keeps "10 at most" true per stage but conflicts with D-25 (mid-stage cards show fight rows only). I advise per fight, and Jeff should know the stage maximum is 10 times the number of fights. In realm.01 a stage is one fight, so it does not matter there.

## 3. How the player should read it

- Show a count: "Echoes home 2 of 2". The count is the meaning. The Ase is the side effect.
- Do not show a price on a death. No "minus 2" line, no "you lost 2 Ase". The row shows the amount paid, nothing else.
- A missing Echo is a story beat and belongs to the Sanctum death ripple (GDD 20.10: Echo removed from roster, morale and fear ripple), not to the ledger.
- Honest limit: 2 Ase is about 3% of an uncalled summon (2 / 60). It will not change what the player does in a fight. The player cares about Echoes for other reasons. The stipend is an acknowledgement in the ledger, not an incentive. If Jeff wants an incentive, the amount must be larger, and then D-41 "not game-changing" is broken. Keep the small value and do not describe it as an incentive in any tooltip.
- A row that pays 4 at every win becomes wallpaper. This is acceptable for a stipend. The count display gives it a reason to be read on the one day it changes.
- Tooltip direction (copy is Jeff's): plain, short, about who came home. The shipped text "Each Echo still standing when the fight ends earns Ase." still fits.

## 4. Cadence with a small stipend (third Echo in 1 to 3 stages from about 0 Ase, then one uncalled summon per 2 stages)

With the stipend at 4 to 10, the objectives must carry about 80% to 85% of the income. Round 1 used Set B weights (16, 12, 10, 10) plus 12 for two Echoes. The stipend is now 4 for two Echoes, so the weights cannot stay as they are.

COMPUTED, party of 2, price 60, accrual about 3 per stage (round 1 section 2.3):
| Item | Value |
|---|---|
| Income needed for two stages to clear 60 without a bonus | (60 - 6) / 2 = 27 per stage |
| Stipend at 2 Echoes | 4 |
| Objectives must carry | about 23 per stage on average |
| Set B mean of the fixture (16, 12, 10, 10) | 12 |
| Factor needed | about x2 (Set B x2 = 32, 24, 20, 20; mean 24) |
| Income per stage, party 2, no bonus | 28 (32+4, 24+4, 20+4, 20+4: mean 28) |
| With the bonus (max 6) | up to 34 |

- PROPOSAL: scale the Set B objective weights by about 2 (the designer's alternative M, round 1 section 3.3) or choose per-type values that average about 23 to 24. Jeff approves each value.
- The spread between types stays: the lowest Set B type is 8, so x2 gives 16 + 4 = 20. Two such stages give 40 + 6 = 46, short of 60. That is a 3-stage summon for low-type stages. It is "about 2 to 3", as in my round 2 section 1.2. The cadence is a mean, not a promise for each pair of stages.
- From about 0 Ase, the third Echo: stage 0 (about 28) + stage 1 (about 28) + accrual about 6 = 62. It lands after stage 1 or stage 2, inside "1 to 3 stages" (D-36, D-39).
- Party growth: going from 2 to 5 Echoes adds only 6 Ase per stage (about +21% on 28). The positive loop (more Echoes, more Ase) is now weak. It does not break the cadence. This resolves round 1 finding 5.
- Ekwan: its own weight set (D-29), so scaling the Ase weights does not move it. Rank: the rank ratio uses `enemies x 5` and the echo term, so it must be re-based with D-40. The mechanics-developer owns that. Not part of this review.
- Realm.02: stages have 1 or 2 objectives (Phase 1 section 2). Doubled weights on two objectives would pay about 2 x 24 + stipend. This repeats the realm.02 inflation risk from my round 2 section 1.8. Keep per-run cadence in mind when the realm scale is set.

## 5. Change to my earlier verdict

Round 2 section 1.3 said RISKY (stipend at 6 per Echo, half of income, never changes, trivial next to permadeath).
New verdict: FEELS RIGHT, on these conditions:
1. The rate is small (2 per Echo, cap 10), so it is a stipend and no longer half of income.
2. The row shows a count and carries no price on a death.
3. The Echoes cap is set by the party cap (5), which removes my earlier cap request.
4. The objective weights are raised so the cadence target holds (section 4).
Remaining risk (low): wallpaper, and the fact that 2 Ase will not change player behaviour. Neither needs a fix.
Round 2 disagreement #4 is closed. The closing note: the "do not price the death" advice still holds.

## 5b. Making survival feel rewarding (D-42)

Jeff's goal (D-42): keep Echoes alive, guide them to finish their stories and grow. Survival must be rewarded and feel rewarding. The Ase stipend (D-41) is one channel. Small must not mean unnoticed.

Principle: the Ase is the smallest part of the reward. The first reward is the moment: the player sees that everyone came home. People first, number second.

### (1) What the player sees and feels

| When | What the player must see or know | Feel it should give |
|---|---|---|
| Before the fight (anticipation) | The standing rule: who goes, and that bringing all of them home is worth something. Shown next to the quick-win rule, as a rule, not as a promise. | "I am responsible for these people." |
| During the fight | Nothing new. The fight runs by itself (GDD 4: the Keeper is "not a general issuing direct orders"). Do not add a live survival counter. A live counter pulls attention to a number. | Tension stays with the Echoes. |
| At the result (feedback) | The party shown together before any number. Each Echo marked as home, one after another, a short beat each (starting value 100 to 150 ms, test it). The count completes ("5 of 5"). Only then the Ase line appears. Pacing rule: people resolve first, then the ledger. | Relief, then a small thanks. |
| When all are home | One extra, quiet beat: the count lands whole. Not a fanfare, not a grade. A short, warm line. No "perfect" or "flawless" label (that is a score). | Pride and care. |
| When one is lost | The count lands with a held beat. The lost Echo is named. No celebration. No "minus" figure. The stipend line simply pays less. | A story beat, not a penalty. |
| After (consequence) | The Sanctum "post-stage consequence pass" (GDD 22.4 step 7) shows that the survivors are home. Social density rises with presence (GDD 18.1). The first social beat happens after the first stage whether it was won or lost (GDD 20.13). | The house is fuller. |

All of this is presentation only. It changes no simulation outcome. Timing and sequencing come first, effects last.

### (2) Making the stipend read as care and pride, not a score

PROPOSAL (direction only, no final copy, Jeff owns wording):
1. Order on the card: the party, then the count, then the Ase. The Ase is the smallest element of the three.
2. Name the row for the people, not the state. Direction: "home" (people came home) rather than "alive" (a status). The current chip label "Echoes alive" (UI D-05) and tooltip text can follow. Jeff decides.
3. Voice: short, plain, about who came home. Family-record register. For example in direction: "All five came home." Not "Survival bonus", not "Echoes alive: +10".
4. Ase shown as a quiet figure beside the count, not as a headline. No colour or size that makes it look like a score.
5. No grade, no star, no "perfect" tag for a full party. A tag turns care into a score and makes a lost Echo look like a failed run.
6. Word rule (UI D-04): the Ase is "earned".
7. Do not describe the stipend as an incentive in any text (see section 3 of this file).

### (3) Canon channels where survival already pays, or could

I did not invent any mechanic. READ = in GDD or code docs I opened. GAP = not found; stated as a question.

| Channel | What canon says (READ) | Does survival pay here? |
|---|---|---|
| Growth through Storyweight and lived experience | GDD 7.1: Storyweight is "the main visible Echo progression spine"; growth "also includes lived experience, social shaping". GDD 10.1: Storyweight is "recovery, integration, lived formation, and growing narrative weight". | By structure: a dead Echo is removed from the roster (GDD 20.10, line 4338) and stops growing. Survival is the condition for every later growth. This is the strongest channel and needs no new mechanic. GAP: does a stage lived through add Storyweight or Standing directly? I did not find it in the ranges I read. |
| Skills (Standing 3 / 6 / 9) | Round 1 section 4: skills cost Ase per Echo per skill (40 each today; PROPOSAL 60 to 120). | A dead Echo loses every skill bought for it. At 60 to 120 per skill that is 1 to 4 stages of income per skill. Survival protects an Ase investment. The stipend is small beside it. This is the real "economy" reward for survival. Say it to Jeff plainly. |
| Threads | GDD 7.1: Threads are "recovered story fragments returned from stages and Realms". GDD 10.6: recovered stories must change Echo growth, house state, future options, relationships, Realm meaning. Pace-reward `follow-ups.md` item 1: rank feeds Thread quality through `RealmService.contribute_segment` (S and A: clean; B to D: compromised; F: broken). | Only through the rank. Whether the rank counts living Echoes depends on the rank formula (Phase 1: the rank denominator includes an Echo term). After D-40 the rank is re-based. GAP, QUESTION: after the re-base, does the rank still reward bringing Echoes home? If not, Thread quality stops rewarding survival. |
| Continuity | GDD 18.1: Continuity measures rituals, vow adherence, "recovered Threads brought home", relationship growth, "Echo presence and social density". | Presence and density need living Echoes. Survival feeds Continuity indirectly. GAP, QUESTION: no stage-level survival input to Continuity was found. |
| Bonds | GDD 10.2: relationships help complete, distort, pressure or stabilise Echo identity. | Bonds need two living Echoes. A death cuts them. GAP, QUESTION: is there a canon "bond gain when a stage is survived together"? Not found. |
| Death ripple | GDD 20.10 / line 4338: Echo removed from roster; morale and fear ripple. | This is the cost of failure. It already exists as a consequence. |

Grep result (I ran it): the GDD has no hit for "survived", "survive", "came home" or "returned alive". Canon does not name a direct survival payment in a non-Ase channel. Survival pays through continuity of growth, not through a stage-end reward.

### (4) Is anything beyond the Ase stipend needed in Part A?

Recommendation (PROPOSAL):
1. Inside Part A: the capped stipend (D-41), the count in the row, and the rule that the rank re-base (D-40) keeps a survival term. The last item is a QUESTION for the mechanics-developer: confirm it, because Thread quality depends on the rank.
2. Separate item (UI / game-feel, not Part A): the result-moment sequence in section 5b (1) and (2): party first, count, then Ase; the Sanctum consequence pass naming survivors. It is presentation. It needs the UI design session and Jeff's wording.
3. Separate item (design, Jeff decides): any new non-Ase growth payment for survival (for example Standing or bond gain for a survived stage). Canon has no such mechanic. It would be a new mechanic and needs `sr-game-designer`. I do not recommend inventing it in Part A (one story, one subject).
Reason: Part A is an Ase and Ekwan payout story. The "feels rewarding" goal is met mostly by the moment and by the protection of growth and investment, not by raising the stipend.

### (5) Does anything in the reward set work AGAINST survival?

| Item | Risk | Verdict | What to do (PROPOSAL) |
|---|---|---|---|
| Quick-win bonus (max 6) | Rewards speed. In an autobattler, speed comes from aggressive party and directive choices, which can raise the chance of losing an Echo. 6 Ase is 3 Echoes of stipend. | RISKY, low | Keep the bonus independent of survival. Do not couple them. Measure it: in a probe, compare the loss rate of fights that win the bonus and those that do not (a qa-verifier or probe task). The bonus does not exist on `protect`, `endure` and the `guide_spirit` protect variant, so a third of stages carry no pressure at all. |
| Retreat price | Retreat is the main survival tool (GDD 20.10 safety valve). A price of 30 (one stage of income) pushes the player to stay in a fight they might lose. | WRONG at 30 | Lower to about 8 to 10 (my round 2 section 2.3). Show the price before the choice. |
| Stipend on a retreat | If a retreat paid the stipend, "enter and retreat" could net a profit (stipend up to 10 against a price of 8 to 10). | Do not pay | Show the count "home" on a retreat, with no Ase. The count still reads as care. |
| Replay factor 0.5 | Halving the stipend on a replay tells the player that keeping people alive matters less the second time. | RISKY, small | PROPOSAL: do not apply the replay factor or the realm scale to the stipend. The farm risk of a capped 10 is negligible. One extra rule, but it protects the meaning. Jeff decides. |
| Realm scale | Scaling the stipend by realm scale would make survival worth more in later realms. Neutral. | Fine | Keep the stipend unscaled for simple reading. |
| Defeat consolation | A defeat pays a consolation of the lost objective. If the party is dead there is no stipend. | Fine | No change. |
| Completed-only rule | An objective that is not completed pays nothing, so a cautious party that retreats with everyone alive earns nothing. | Acceptable | The retreat price (low) and the visible "home" count balance it. |

Net: only the retreat price and, mildly, the replay factor work against survival. The bonus is neutral if measured and kept small.

## 6. Sources used

Skills: `game-design` (Clarity and Satisfaction checks, abuse-case check for the solo farm); `echoes-sankofa-gdd` (loaded in this session; I used the canon-index ranges, not the skill map file).
GDD (`docs/Echoes vNext Working GDD.md`), read earlier in this session:
| Lines | Section | Used for |
|---|---|---|
| 4018-4026 | 20.10 Failure and withdrawal | Permadeath core; death ripple |
| 4334-4342 | Death, withdrawal, loss | "permadeath remains core"; Echo removed from roster |
| 3819-3837, 4116-4172, 4625-4645 | 20.7, 20.12-20.14, 22.4 | Third Echo from about 0 Ase |
| 3454-3515 | 19.2 Currency roles | Ase role; offline accrual never primary |
| 97-114, 218-227, 349-356, 369-382 | 4, 7.1, 10.1, 10.2, 10.6 | Keeper role; Storyweight, Threads, bonds, visible consequences (section 5b) |
| 3014-3034, 3355-3366 | 18.1, 18.10 | Continuity measures Echo presence and social density |
Other: D-39, D-40, D-41 (`decisions.md`); UI `v2-payout-explanation/decisions.md` D-12 (per-fight rows); Phase 1 section 2 (objectives per stage).
Not verified: `data.sanctum.party_max_size` = 5 (taken from D-41, not opened).

Also read for section 5b: D-42; `pace-reward/follow-ups.md` item 1 (rank feeds Thread quality). Grep of the GDD for "survived/survive/came home/returned alive": 0 hits.

GDD gaps (QUESTIONS for Jeff):
1. Does a downed or withdrawn Echo count as alive at the end?
2. Is the stipend paid per fight or once per stage?
3. Does the GDD set a party cap of 5? I found none in the ranges I read.

## OPEN — questions and assumptions

ASSUMED: "Alive" means the Echo is not dead at the end of the win (downed or withdrawn Echoes still count) | WHY: permadeath is the only loss state I found (GDD 20.10) | WRONG IF: a downed Echo counts as not home
ASSUMED: The stipend is paid per fight win | WHY: matches the shipped UI row (UI D-12) and is identical in realm.01 | WRONG IF: Jeff wants "10 at most" per STAGE; then it pays once on the stage-ending card
ASSUMED: Accrual is about 3 per stage and the objective weights can be scaled about x2 without moving Ekwan | WHY: round 1 section 2.3; D-29 gives Ekwan its own set | WRONG IF: Ekwan derives from the Ase weights in code (mechanics-developer to confirm)
ASSUMED: Linear 2 per Echo (not compounding) is the intended "percentage per missing member" | WHY: it gives 4 at two Echoes and 10 at five, and per-Echo pay stays constant | WRONG IF: Jeff wants a steeper fall for the last survivors
BLOCKED: Per fight or once per stage for realm.02? | CHECKED: UI D-12, D-25, Phase 1 section 2 | NEED: Jeff
BLOCKED: Does a downed or withdrawn Echo count as alive? | CHECKED: GDD 20.10 | NEED: Jeff and mechanics-developer
ASSUMED: The post-stage Sanctum consequence pass (GDD 22.4 step 7) can name the survivors | WHY: GDD 22.4 lists it as part of the first session | WRONG IF: the pass is fixed text with no party data
ASSUMED: The probe for bonus-versus-loss-rate is a separate qa-verifier task | WHY: one story, one subject | WRONG IF: Jeff wants it inside Part A
BLOCKED: After the D-40 rank re-base, does the rank still reward bringing Echoes home (Thread quality depends on it)? | CHECKED: Phase 1 and `pace-reward/follow-ups.md` item 1 (not the rank code) | NEED: mechanics-developer
BLOCKED: Does canon give Standing, Storyweight, Continuity or bond gain for a survived stage? | CHECKED: GDD 7.1, 10.1, 10.2, 10.6, 18.1; grep found no survival text | NEED: Jeff or sr-game-designer
BLOCKED: Should the stipend skip the replay factor and the realm scale? | CHECKED: D-30, round 2 section 1.5 | NEED: Jeff
BLOCKED: Wording of the "home" row and the result moment | CHECKED: UI D-04, D-05 | NEED: Jeff (copy) and the UI session (layout)
