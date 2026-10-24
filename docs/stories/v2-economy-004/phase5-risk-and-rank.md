# V2-ECONOMY-004 Phase 5 — Risk and rank (D-47), sr-game-designer

Written in STE. Every number is a PROPOSAL. Jeff decides. Nothing is in `data/balance.json`. No code was run.
Tags: READ = from a file I opened. COMPUTED = my arithmetic. ASSUMED = not verified. PREDICTED = not measured.
Inputs: D-40 to D-47, `phase5-design-advice.md`, `phase5-echoes-alive-recheck.md`, `core/economy/RewardCalc.gd`, `core/combat/PaceService.gd`,
`RealmService.contribute_segment`, `data.threads`, `docs/stories/pace-reward/follow-ups.md` item 1 and `decisions.md` D-04, GDD §5, §7.1, §14.3, §20.17.

## 1. How rank works today

READ: `RewardCalc.compute` (one call per fight), `_rank_for`, `_compute_rank`.

Formula for a WIN:
- numerator = `base` + `rank_enemy_bonus` (5 per enemy defeated, ally kills out) + `echo_bonus` (10 per Echo alive) + `pace_bonus`.
- `max_possible` = `base` + (reached or total enemies x 5) + (`total_echoes` x 10) + `max_pace_bonus`.
- `base` = weights of completed objectives plus the fought one (D-15, MODE_COMPLETED_PLUS_FOUGHT).
- score = numerator / `max_possible` x `redo_multiplier`. Grade: S >= 0.90 (only when `run_count` is 0), A >= 0.75, B >= 0.55, C >= 0.35, D >= 0.15, else F.
- A DEFEAT uses `roundi(base x 0.25)` as numerator, so it always ranks lower.

Where speed enters (READ): only the `pace_bonus` term, in the numerator and in `max_possible`.
- Pace modes: `COMBAT`, `PURIFY_SHRINE`, `RECOVER`, `PURSUE`, and GUIDE_SPIRIT in its escort variant. `PROTECT`, `ENDURE` and other GUIDE_SPIRIT fights have no pace term (`PaceService.is_pace_mode`).
- The pace bonus is `roundi(pace_stage_base x 0.05 x fraction)`. The fraction is 1.0 at or below 1.1 x par, 0.0 at or above 1.6 x par, and linear between.
- With Set B weights the maximum is 1 Ase (0 for base 8). Example: `combat` base 10, 3 enemies, 2 Echoes: `max_possible` = 10 + 15 + 20 + 1 = 46. Speed is 1 of 46 = 2% of the score.

Where survival enters (READ): `echo_bonus` (10 per Echo alive) and the `total_echoes x 10` ceiling.
- Same fight, one Echo lost, full pace: (10 + 15 + 10 + 1) / 46 = 0.78 = A. All home, slow: 45 / 46 = 0.98 = S.
- So today one lost Echo costs 22% of the score, and the whole speed term costs 2%. Rank today measures survival and kills, and almost nothing of speed.

Also READ: rank is graded per fight, not per stage. Rank feeds the Thread: `RealmService.contribute_segment` runs once per stage, from the stage-clearing fight. `data.threads.segment_quality_by_grade`: S and A = clean, B, C, D = compromised, F = broken.
`pace-reward/follow-ups.md` item 1 (measured, 336 fights): without the old speed cliff almost every win is S and every loss is F. So rank today is close to "did you win".

What the D-40 removal breaks: the enemy term leaves both sides of the ratio. The remaining terms are `base` (8 to 16), the Echo term and the pace term. The ratio then depends mostly on `base`, which has nothing to do with skill.

## 2. Principles used to judge the options

1. Monotonic in survival (D-42): at the same speed, more Echoes home must never give a lower grade or less Ase. A fast run that lost an Echo must never pay more than a slow run that kept all home.
2. Speed is a visible goal before the fight (ANSWERS #64) and an extra, not a cliff.
3. Loss has a visible cost; risk has a visible reward; neither reads as a fine ("game-design": Clarity, Satisfaction).
4. GDD §14.3 (READ): deaths and failures should lower recovery quality, not only the letter grade; S to A support stronger segments. So a death that compromises a Thread has canon support. Speed has no canon link to Thread quality.
5. GDD §5 and line 156 (READ): Realms are trials of sacrifice, and "risk creates attachment payoff". GDD §20.17 (READ, line 4338): permadeath remains core. Risk is canon. Sacrifice must be possible without a cliff.
6. Rank should not depend on party size or on Ase tuning. Today it does (`total_echoes x 10`, `base`).

## 3. Options

Common to all: objectives row, "Echoes home N of M" stipend (D-43, D-44, once per stage), replay and consolation rows as in round 1.
The levers of speed are unclear (see section 6, question 1): a choice needs a player lever that trades speed for safety.

### Option A — the bonus stays a separate fixed amount, rank only re-based

- Rows in a win: objectives, Echoes home, Bonus (pace, fixed). Rank is a separate grade shown on the card.
- PROPOSAL: pace maximum 6 Ase (fixed), 0 to 6 by the existing curve.
- Rank re-base (minimal): `max_possible` = `base` + 2 x Echoes started (cap 10) + 6; numerator = `base` + 2 x Echoes alive + pace.
- Finding (COMPUTED): this is wrong for D-42. A fast run that lost one Echo scores S; an all-home slow run scores B (table 4.1). Ase also breaks the principle: party of 3, one lost, full pace = 4 stipend + 6 bonus = 10 Ase; all home, slow = 6 Ase. Losing an Echo pays more.
- Fix inside A: pay the pace bonus only when nobody died. That is option C's mark in disguise. Or cap the pace maximum at 2 (the stipend step), which makes the bonus too small to read.
- Penalty feel: the bonus row shows "0 / missed" on slow runs. The player reads it as a fine (Jeff's worry).
- Thread: rank follows A's table. One lost Echo with full pace = S = clean thread. A death does not compromise the Thread. Conflicts with GDD §14.3.
- Cadence: unchanged from round 1 (bonus 6 if earned).

### Option B — speed folded into a rank score, rank pays Ase by grade

- Rank is decoupled from Ase amounts. Rank points (PROPOSAL): win 0.40, home share 0.40 x (alive / started), speed 0.20 x pace fraction. In a no-pace mode the speed share is dropped and the score is divided by 0.80.
- Thresholds stay 0.90 / 0.75 / 0.55 / 0.35 / 0.15 (PROPOSAL, to be measured). The S limit to `run_count` 0 stays. Rank is then independent of `base` and of party size.
- One row "Rank" pays by grade. PROPOSAL: S 8, A 4, B 2, C and below 0. The separate Bonus row leaves.
- Rows in a win: objectives, Echoes home, Rank. (Replay and consolation only when they apply.)
- Cost of a loss: the home share falls, so the grade falls and the pay falls. A loss never pays more (table 4.2 is monotonic).
- Reward of risk: a fast run adds up to 0.20, so it can lift a grade by up to two steps. All home plus partial speed = S.
- Penalty feel: the player never sees a minus. A slow run is "A, 4 Ase", not "bonus missed". The best result is shown as a goal.
- Thread: all home at any speed = A or S = clean. A lost Echo needs full speed to keep A (one of 2 or 3). So some losses stay clean. Speed can offset part of a loss.
- Weakness: a score from three terms is a hidden formula for the player. XCOM reading: less readable than marks.

### Option C — rank from two visible marks, shown before the fight

- Two marks, both shown BEFORE the fight and during it (ANSWERS #64): "All home" (no Echo dead) and "Swift" (win by round N, where N comes from par; the existing fight colour shows pace). PROPOSAL: Swift is earned at pace fraction >= 0.5 (round N = 1.35 x par).
- Grade for a win (PROPOSAL):

| Marks | Grade | Thread tier |
|---|---|---|
| All home and Swift | S | clean |
| All home | A | clean |
| Swift, but an Echo died | B | compromised |
| Neither | C | compromised |

- Optional: if more than half of the party died, D. A defeat keeps the existing F rule.
- Pay (PROPOSAL, same as B): S 8, A 4, B 2, C 0. One row "Rank", plus the stipend row "Echoes home".
- Rows in a win: objectives, Echoes home, Rank. Same as B. The rank row can show two small marks ("All home", "Swift") instead of a formula.
- Cost of a loss: the "All home" mark is gone: A to B at best, and the Thread becomes compromised (GDD §14.3). The stipend falls by 2.
- Reward of risk: "Swift" adds one grade (A to S, +4 Ase) only when everyone is home. Speed alone never raises a grade above what survival allows, so a death is never paid for.
- Penalty feel: each mark is an earned extra on a visible list, like an XCOM bonus objective. The base case (all home, steady) is A, a clean Thread and 4 Ase. A steady safe player is not punished.
- Hard edge: one dead Echo changes the grade by two steps (A to B, or S to B). This is a cliff at the "All home" mark. Variant C2 softens it: if no more than 1 of at least 4 Echoes died and Swift is earned, the grade is A. PROPOSAL only; it needs Jeff's view on "a sacrifice that still counts as clean".

## 4. Tables (combat objective, base 10; run 0; pace "slow" = fraction 0, "partial" = 0.5, "full" = 1.0)

### 4.1 What the minimal re-base gives (option A rank): score = (10 + 2 x alive + pace) / (10 + 2 x started + 6)
PROPOSAL values: stipend 2 per Echo, pace maximum 6. `max_possible` = 18 (1 Echo), 20 (2), 22 (3). Enemy term removed.

| Started / alive | Slow (pace 0) | Partial (pace 3) | Full (pace 6) |
|---|---|---|---|
| 1 / 1 | 12/18 = 0.67 B | 15/18 = 0.83 A | 18/18 = 1.00 S |
| 2 / 2 | 14/20 = 0.70 B | 17/20 = 0.85 A | 20/20 = 1.00 S |
| 2 / 1 | 12/20 = 0.60 B | 15/20 = 0.75 A | 18/20 = 0.90 S |
| 3 / 3 | 16/22 = 0.73 B | 19/22 = 0.86 A | 22/22 = 1.00 S |
| 3 / 2 | 14/22 = 0.64 B | 17/22 = 0.77 A | 20/22 = 0.91 S |
| 3 / 1 | 12/22 = 0.55 C | 15/22 = 0.68 B | 18/22 = 0.82 A |

Reading: with these numbers speed (6) outweighs survival (2 per Echo). "2/1 full" = S, and "2/2 slow" = B. This breaks principle 1. A guide for the minimal route: `max_possible` must follow the real terms, and the pace maximum must not exceed the stipend step. With base 16 (`guide_spirit`) the effect is smaller but has the same order. With a slow, all-home run no mode reaches S.

### 4.2 Option B (rank points 0.40 / 0.40 / 0.20)
score = 0.40 + 0.40 x (alive / started) + 0.20 x fraction.

| Started / alive | Slow | Partial | Full |
|---|---|---|---|
| 1 / 1 | 0.80 A | 0.90 S | 1.00 S |
| 2 / 2 | 0.80 A | 0.90 S | 1.00 S |
| 2 / 1 | 0.60 B | 0.70 B | 0.80 A |
| 3 / 3 | 0.80 A | 0.90 S | 1.00 S |
| 3 / 2 | 0.67 B | 0.77 A | 0.87 A |
| 3 / 1 | 0.53 C | 0.63 B | 0.73 B |

No-pace modes (protect, endure, non-escort guide): score = (0.40 + 0.40 x alive / started) / 0.80. All home = 1.0 S. One of 2 lost = 0.75 A. One of 3 lost = 0.83 A. Two of 3 lost = 0.67 B.

### 4.3 Option C (marks)

| Started / alive | Slow | Partial | Full |
|---|---|---|---|
| 1 / 1 | A | S | S |
| 2 / 2 | A | S | S |
| 2 / 1 | C | B | B |
| 3 / 3 | A | S | S |
| 3 / 2 | C | B | B |
| 3 / 1 | C | B | B |

With variant C2 (one death in a party of 4 or more, Swift earned): A. Not shown in the table because the table has at most 3 Echoes.

### 4.4 Ase for the same cases (stipend 2 per Echo + rank pay S 8 / A 4 / B 2 / C 0; objectives excluded)

| Started / alive, pace | Option A (stipend + bonus 0 / 3 / 6) | Option B | Option C |
|---|---|---|---|
| 3 / 3, slow | 6 | 6 + 4 = 10 | 10 |
| 3 / 3, full | 12 | 6 + 8 = 14 | 14 |
| 3 / 2, full | 4 + 6 = 10 | 4 + 4 = 8 | 4 + 2 = 6 |
| 3 / 2, slow | 4 | 4 + 2 = 6 | 4 + 0 = 4 |
| 2 / 1, full | 2 + 6 = 8 | 2 + 4 = 6 | 2 + 2 = 4 |
| 2 / 2, slow | 4 | 4 + 4 = 8 | 8 |

Check against D-42: A pays 10 (3/2 full) against 6 (3/3 slow). That is a loss that pays more. B and C never do (the best case with a loss is below the worst all-home case: B 8 against 10; C 6 against 10). 

## 5. Effect on the cadence and on Threads

Cadence (target: third Echo in 1 to 3 stages from about 0 Ase; then one uncalled summon per 2 stages; 24 to 30 Ase per stage in round 1):
- The rank pay is 0 to 8 per stage. ASSUMED player mix: all home 80% of stages, Swift on half of the pace stages. Mean rank pay is about 5 Ase (COMPUTED: 0.4 x 8 + 0.4 x 4 + 0.2 x 2 = 5.2). Round 1 assumed a bonus of 6 earned in every fight, and the mean earned bonus is lower (about 3 to 4), so B and C are neutral to slightly higher than option A.
- Spread between the best and the worst all-home route: 4 Ase per stage (S against A) = 0.07 of an uncalled summon per stage, 0.13 per 2 stages. The route changes the cadence by less than 15%. The objectives carry 60 to 80% of the income, the stipend 4 to 10, the rank 0 to 8.
- First summon (third Echo, about 0 Ase): stage 0 pays objectives (8 to 16) + stipend 4 + rank 2 to 8 = about 14 to 28. The first summon in 1 to 3 stages depends on the weights, not on the rank. Rank pay is not a target lever.
- The weights, not the rank, must be re-scaled to reach 24 to 30 (round 1 section 3, feel recheck section 4). Rank pay in B and C replaces the 6 Ase bonus; it does not add to it.

Threads (`segment_quality_by_grade`: S, A clean; B, C, D compromised; F broken):
- Today: almost every win is S; one lost Echo still gives A (0.78). Threads are clean after a death. This is not in line with GDD §14.3.
- A: one lost Echo + full pace = S (clean). Same as today for the death case; speed can now buy a clean thread after a death. Not recommended.
- B: all home = clean at any speed (A or S). A death keeps A only with full speed in a party of 2 or 3. So speed can offset one loss. Many losses = compromised.
- C: any death = compromised (B or C). All home = clean at any speed. Speed never changes the Thread tier on its own (A and S are both clean); only survival does. This matches GDD §14.3 and keeps "Swift" a pure Ase and prestige extra.
- PREDICTED, not measured: B and C spread wins over S, A and B better than today, which fixes the "almost all S" finding of the pace-reward story. A probe is needed (section 6, item 2).

## 6. Recommendation (separate from the options; Jeff decides)

Recommend Option C, with variant C2 held back until a probe shows how often a single death in a large party happens.

Reasons:
1. D-42: it is the only option where a death can never pay more and always costs something visible (the "All home" mark, the stipend, the Thread tier). Option A fails this in numbers (table 4.4).
2. D-47: "Swift" is a named, visible extra before the fight. It does not read as a penalty: the safe, steady result is a clean A with a full stipend. Speed adds a grade only when it costs nothing in lives; the risk lives in the player's tactics, and the card shows what it earned.
3. XCOM reading: two bonus objectives on a visible list. No ratio to read. The ledger shows one "Rank" row with two marks.
4. It removes the dependence of rank on `base`, on party size and on Ase tuning (principle 6). The rank no longer needs `max_possible` or `enemy_bonus_per`. The thresholds are not used in C (marks), and remain for B.
5. Fewer rows: objectives, Echoes home, Rank. The Bonus row and the grade-without-pay row both leave.
6. GDD §14.3: deaths lower Thread quality. C makes that exact.
7. Pillar (growth over time): rank is a story-quality signal tied to Thread quality, not a growth source; it asks the player to care about people.

Honest limit: C makes a single death a two-step drop. For a Thread, that is a strong statement. If Jeff wants "loss of one Echo is survivable", use B or C2.
Honest limit 2: "risk" is real only if the player has a lever that trades speed for safety. If the fight is automatic and no lever changes the speed, "Swift" is luck. See question 1.

What the build needs (for mechanics-developer, if Jeff approves): a mark computation in `RewardCalc` fed by the dead count and `pace_state`; `rank_thresholds`/`max_possible`/`enemy_bonus_per` retire for C; `pace_bonus_pct`/`pace_bonus` retire; new config for rank pay; one re-record of the fingerprint constants with attribution; the Resolve snapshot carries the marks; the UI contract (D-18, D-19) gains `rank_pay` and the two marks and loses `bonus_earned`/`bonus_missed`. The stage-ending rank: rank is per fight today, the stipend is per stage (D-44), the Thread uses the stage-clearing fight. Pay once per stage from the stage-clearing fight, with "All home" counted against the party that started the stage.

## 7. Questions for Jeff

1. Which player action trades speed for safety? (Directive choice, party choice, guidance.) Without one, "Swift" is not a choice. CHECKED: pace-reward `design.md`, `decisions.md` D-07 to D-12. NEED: mechanics-developer or a probe: do fast wins lose more Echoes?
2. Should one dead Echo always make the Thread "compromised" (C), or may a fast win keep it clean (B, C2)?
3. In no-pace modes (`protect`, `endure`, non-escort `guide_spirit`) no "Swift" exists. Should "All home" alone give S there (easier S), or A at most? ASSUMED: S, so pay stays equal.
4. Rank pay S 8 / A 4 / B 2 / C 0: once per stage, or per fight? Realm.02 stages with two objectives would pay twice per stage if per fight. ASSUMED: once per stage.
5. Should rank keep the "S only on run 0" and the redo multiplier? Out of scope; ASSUMED kept.
6. GDD gap: no GDD text sets what the combat grade measures (GDD §14.3 only says the grading model "can influence" segment quality). The pace-reward story D-04 also left it open. Jeff owns this definition.
7. GDD gap: no GDD text on a speed reward or on a "Swift" goal.

## Sources used

Skills: `game-mechanics-designer` (rank as a score, monotonic pay, cadence maths), `game-design` (Clarity, Satisfaction, false agency check on "risk" without a lever), `echoes-sankofa-gdd` (canon lookup via line ranges). I loaded all three earlier in this session, before round 1, and did not reload them for this file.

GDD citations (`docs/Echoes vNext Working GDD.md`):
- §5 Sanctum and Realms, lines 120 to 160: Realms are trials of memory and sacrifice; "risk creates attachment payoff" (line 156). Supports a visible risk choice.
- §7.1, lines 212 to 228: Storyweight, Threads and Continuity are the progression spine. Rank links to Threads, not to Ase growth.
- §14.3 Segment quality and Realm performance, lines 2094 to 2112: each stage gives one segment; quality follows stage performance; deaths and failures should lower recovery quality, not only the grade. Supports C.
- §20.17, lines 4206 to 4452, text at line 4338: permadeath remains core. Supports a real cost of loss.
- §19.10 and §21.1 (read in round 1): no cadence for Ase. Not a rank source.
Other: `RewardCalc.gd`, `PaceService.gd`, `RealmService.contribute_segment`, `data.threads`, `pace-reward/follow-ups.md` item 1, `pace-reward/decisions.md` D-04 and D-07 to D-12, `decisions.md` D-40 to D-47, `phase5-echoes-alive-recheck.md`.
Not read: GDD §20.10 (failure and withdrawal) beyond its title, and the pace-reward `design.md` beyond its par definitions.
