# V2-ECONOMY-004 Phase 5 — Running tally review (D-65), sr-game-designer

Written in STE. Every number is a PROPOSAL or an example. Jeff decides. No code was run. Nothing is in `data/balance.json`.
Tags: READ = from a file I opened. COMPUTED = my arithmetic. ASSUMED = not verified.
Rule D-48: options are ranked by game quality (clear, engaging, fun, Echoes pillar). Build cost is not used.
Question: does a running tally of Ase and Ekwan (paid only at the stage end) fit the GDD concept, and is it a good mechanic?
Short answer: a persistent coin counter does not fit and gives little. The decision it would support is real, but the better home for it is the point of decision (return or retreat), plus story-shaped progress on the mid-stage card. Details in section 7.

## 1. Concept fit (GDD)

READ, what the GDD says and what I take from it:

| GDD source | What it says (my words) | Effect on a tally |
|---|---|---|
| §2 pitch (line 50 to 56) | "You do not command heroes." The Keeper helps broken stories become people, then risks them in Realms. | The Keeper observes and guides. A counter is an observation, so it does not break this. It does shift attention from people to a number. |
| §5 (lines 120 to 160) | Realms are trials of memory and sacrifice, "not just combat content". Risk creates attachment payoff. | A coin counter inside a trial of sacrifice frames the Realm as loot. A gauge or a story mark does not. |
| §7.3 (lines 244 to 260) | Guidance over control: observe, guide, the Echo interprets, a visible consequence. Outcomes must be legible. | A tally is legible only if its meaning is exact (see section 4). |
| §14.1 and §14.2 (lines 2063 to 2093) | Each stage adds a recovery segment to ONE Realm track. It is "intentionally not a shard inventory". Partial recoveries must not become "a third currency". | The GDD already has the in-realm accumulator: the recovery track (stories), not coin. A running Ase counter is a second accumulator that sits next to it. It also reads like a held partial reward, which §14.2 warns against. |
| §19.2 Ase (lines 3456 to 3475) | Ase is the life-source currency, paid when the player animates, invokes, shapes or enacts change. Offline accrual is framed as the flame "gathering charge" while the Keeper is away. | A flame that gathers charge fits the fiction. A number of coins does not. |
| §19.2 economic rule (about line 3488 to 3492) | Baseline Realm entry should not cost Ase. Ase should "gate how the player shapes a run, sanctifies an action, or invokes extra force". | The GDD intends some Ase use inside a run. Today only the retreat (10) is such a use. See gap question 1. |
| §20.8 (lines 3838 to 3866) and §20.9 (lines 4004 to 4018) | Stage objectives may begin partially unknown. Hidden, not random. The player should feel "I do not yet know exactly what is waiting". | A tally must never show a total or a "of N" Ase figure, because that would reveal how many hidden objectives remain. |
| §20.10 (lines 4020 to 4040) | A failed or withdrawn run must still return useful things: intel, revealed objective requirements, objective location. "Reruns are part of learning". | In canon, what an unfinished run carries home is KNOWLEDGE first. A tally that says "carried home: 2 Ase" under-describes this. |
| line 3753 (first session) | The player returns with an ember, some Ase, partial recovery or intel, and a small reward. | Ase coming home with the party is canon. Ase counted inside the Realm is not named. |

Verdict on fit (separate parts):
- A NUMBER that counts up during a stage fights the Realm fiction (trial of sacrifice, not loot) and doubles the recovery track. It fits §19.2 only if it is shown as the Ase flame, not as coin.
- A GAUGE of the flame gathering charge fits §19.2 (the offline text already uses the picture).
- A figure of what the party carries home if it leaves fits §20.10 if intel is part of it.

## 2. Is it a good mechanic on its own merits?

### 2.1 What decision does it give the player?

READ: what exists inside a stage run today. The player can continue, return home at the map (D-14: 12% of completed weights), or retreat before round 1 (10 Ase; D-46, D-14). Objectives pay only when completed (D-11), the stage pays at its end (D-44, D-65), a defeat pays 25% of the fought weight (D-13).

COMPUTED example, realm.02, scale 1.25, first run, stage with a `recover` (24) and a `combat` (20), party 4:
- After the first objective: stands to bring home at the stage end = (24 x 1.25) = 30 Ase (first objective only), plus 20 x 1.25 = 25 if the second is won, plus stipend 8.
- Leave now: 12% of 30 = 3.6, so 4 Ase (if the scale applies to the partial; QUESTION 3).
- Defeat in the second fight: consolation 25% of 25 = 6 Ase. The 30 is not paid.
- So leaving carries about 12% of what staying can bring, and a defeat loses almost all of it.

Decision value: the choice "press on or go home" exists today, but the player has no number to weigh. A visible figure would make the choice readable. But the choice is dominated by the Echoes, not by Ase:
- The gap between "leave now" (about 4) and "finish" (about 63) is large, so in Ase terms the player nearly always continues.
- The real trade is: finish and risk Echoes, or go home with everyone and almost nothing. That is the fair risk choice Jeff asked for (D-47). Ase makes the cost of caution visible. The Echoes make the cost of risk visible. Both must be on the screen, or the choice reads as greed.

### 2.2 Tension and the pillar (D-42)

- Loss aversion: a figure that grows ("earned so far 30") makes leaving feel like losing 30. This pushes the player to press on. For the pillar (keep Echoes alive) this is the wrong push. A figure framed as "carried home if you leave" avoids it, because it shows a small positive number, not a lost large one.
- Temptation in numbers (COMPUTED): the tally is 24 to 60 Ase. The stipend is 2 per Echo. Replacing a lost Echo costs the next summon price (60 at Echo 3, 145 at Echo 8) and the person. So Ase never outweighs an Echo in a rational comparison. The risk is not the arithmetic; it is the attention. A number the player watches each fight pulls the eyes from fear, morale and wounds.
- Sunk cost: a counter that only goes up encourages "one more fight". The mid-stage card is where the player should read the party (fear, morale, who is hurt). Put the person first.

### 2.3 Other merits and costs

| Merit or cost | Notes |
|---|---|
| Reward frequency | A stage run of about 10 to 15 minutes pays at its end. Mid-stage feedback today is the objective mark and the fight result. A tally adds anticipation. The same anticipation comes from the objective mark and the gauge, with no number. |
| Redundancy | The tally is a function of objectives overcome and fixed weights. It carries no new information beyond "N objectives overcome" and the weight table. It translates progress into Ase. |
| Two scores | The game already has rank (a grade). A tally is a second score, and Ase has no use inside the Realm. A number you cannot spend inside the Realm reads as a score. |
| Honesty cost | A tally must obey the rules in section 4 (floor figure, replay, scale, rounding once on the stage sum, the defeat loss). Each rule is a place for the player to feel cheated. |
| Fit with XCOM reading (round 1) | A visible reward is XCOM-like (a mission panel). A running counter during the mission is not; XCOM shows the reward before and after. A counter at the decision point is closer. |
| New system cost on the player's attention | The tally becomes a fourth thing to read on the stage screen after map, party and objectives. |

## 3. Forms and their feel

| Form | What the player sees | Feel | Fit | Honesty risk |
|---|---|---|---|---|
| A. Exact numbers: "earned so far: N Ase, M Ekwan" | A growing pair of numbers | A loot counter. Clear, but it frames the Realm as a till. Loss aversion pushes the player to press on. | Weak (§5, §14.2) | "Earned" is untrue: a defeat or a retreat pays only a fraction. The word breaks the honesty rule. Rounding once on the stage sum means partial sums can differ from the end by 1. |
| B. Gauge: the flame gathers charge, no numbers until the stage end | A glow or fill that rises with each objective overcome | Warm and wordless. Anticipation without arithmetic. Fits "Ase as living force". Low precision, so it gives no decision data. | Strong (§19.2 flame) | Low. A gauge never states a figure. It must not look full before the stage end if a second objective remains. It must not drop on a defeat without a cause. |
| C. "Carried home if you leave now" beside what is at stake | One small figure (the D-14 partial) at the moment of the return or retreat decision, with the Echoes' state | Honest and decisive. The number appears when it matters. Risk: it can read as "the price of cowardice" (a penalty feel). | Good if intel is part of it (§20.10) | Medium. The figure is exact and small. Show it only as what is carried, never as what is lost. |
| D. None (status quo, D-25) | Nothing in Ase until the stage end | Clean. Keeps eyes on the Echoes and the map. The mid-stage card has less to say. | Good (§5, §14.2) | None |
| E. Variant: story-shaped progress + C at the decision point | Mid-stage card shows objectives overcome as marks, "home N of M" as a count, and the flame B as a glow. The return and retreat confirmation shows C. | Mixed, but each part has one job. | Strong | Low if the rules of section 4 hold. |

## 4. Honesty rules (so the player never feels cheated)

These apply to any form that shows a figure (A, C, E).

1. The shown figure never exceeds the final payout. Compute it as the FLOOR of the final stage sum for the objectives already overcome: roundi is applied once on the stage sum (D-30, D-54), so a partial figure may be 1 below the final. Show it as "at least".
2. The word "earned" is not used. The figure is what the party stands to bring home or what it carries, never what it "has". A defeat or a retreat pays only the consolation (25% of the fought weight, D-13) or the partial (12%, D-14). The player must know this before the figure appears.
3. The replay factor (0.35) and the realm scale (D-63) are inside the figure. The player never sees a number that the stage end then shrinks. On a replay the figure is lower from the first fight, and the card says why in the same words as the stage-end ledger (cause shown, ANSWERS #64).
4. The stipend is NOT in the tally. It depends on who is alive at the stage end (D-44, D-45). Show it as a count ("home N of M") or as "if all come home" with the number at the stage end only. A figure that drops when an Echo dies is a figure that charges a price for a death (D-42 forbids a price on a death).
5. Ekwan follows the same rules as Ase: completed objectives only, floor, scale and replay inside, rounded once on the stage sum.
6. The tally never shows a total or "of N". Counting only overcome objectives leaks no hidden objective (§20.8, §20.9). Optional objectives not overcome add nothing and are not named.
7. A boss stub adds 0 and is not listed (D-02, D-23).
8. If the stage ends in a defeat, the card states what is paid and why, in the same words as the ledger rows (`defeat_consolation`). A figure that was shown and then vanishes needs a cause.

## 5. Where the player would see it (no UI design)

| Place | Pros | Cons | My view |
|---|---|---|---|
| Stage explore screen (persistent) | Always visible | Constant number in the one place the player should read the map and the party. Strongest loss-aversion and coin-counter feel. | Not for A. B only, if at all. |
| Mid-stage Resolve card (after each fight) | The natural place for results. The card already holds the ledger idiom (D-24). | Today it is empty of Ase (D-25). A figure here is a reversal of D-25. | Good for story marks and B. C is possible here with the fought state. |
| Stage map | Shows progress by node | Danger of showing totals (§20.8 hidden objectives) | No figure on the map. A mark per overcome objective is fine. |
| Return and retreat confirmation (the decision) | The figure appears when it informs a choice. No constant counter. | A cost of caution may read as a penalty (D-47 worry). | Best place for C. |

## 6. The empty mid-stage card

D-25 stands until Jeff approves a change. The card today shows fight rows only, and the fight group is empty because fights pay no Ase and no Ekwan (D-28, D-40).

Recommendation for the card (GDD-led): do not fill the empty group with a Ase row. Replace the group, not the amount:
- Show the objective result as a mark ("overcome N" without a total Ase, honest to §20.8). Part of the existing `objectives_overcome` idiom.
- Show the Echoes count "home N of M" now, without Ase (the stipend arrives at the stage end).
- Show what the fight changed in the party (fear, morale, who is hurt). This is the information the next choice needs, and it serves the pillar. Not designed here; the feel agent owns it.
- If Jeff wants a currency feel, show the B glow brightening once per overcome objective, with no number.
- Do not show an empty fight group or a "0 Ase" row. A zero row teaches the player that the fight was worth nothing.

## 7. Recommendation (separate from the options; Jeff decides)

Recommend variant E, built from D and C and B, and not A.

1. Keep D-25: no running Ase and Ekwan numbers on the stage screen or the mid-stage card. A coin counter fights §5 and §14.2, invites loss aversion against D-42, and adds no information beyond the objectives overcome.
2. Add C at the decision point only: on the return or retreat confirmation, one exact line of what the party carries home, shown with the Echoes' state beside it. Include intel (the objective facts revealed) in "carried home", since §20.10 names intel as the useful return. This makes "press on or go home" visible without a persistent number. Wording is Jeff's.
3. Add B on the mid-stage card (optional): a wordless flame glow that rises per objective overcome. It gives the felt anticipation Jeff may be missing and it echoes §19.2 (the flame gathering charge). It carries no number, so it cannot lie.
4. Fill the empty fight group with story-shaped content (marks, "home N of M", party state), not with currency rows.

Why not A: "earned so far" is untrue by D-11, D-13 and D-14; it is the form most likely to make the player feel cheated; it puts a score in a trial of sacrifice; and it adds a second accumulator next to the recovery track.
Why not D alone: it leaves the choice to press on or go home with no readable stake. Jeff asked for that choice to be visible and fair (D-47).

Risks of the recommendation:
- C at the decision point can read as a penalty ("you carry 4 of 63"). Mitigation: show the Echoes safe and the intel gained beside it, and never use the word "lost".
- B gives no decision data. If it looks like a progress bar, the player may read "full" as "done". It must not fill past the objectives overcome.
- Both depend on the partial rule D-14 (12% after the first win, 0 before). The player who retreats before any win sees "0". That is honest but flat. The intel line keeps it useful.
- The D-14 partial figure has open points (question 3).
- A flame glow on the stage screen needs an in-fiction link between the Keeper and the party away. The GDD gives the Keeper a flame, not a link to a party (question 2). Treat B as optional.
- If Jeff later gives Ase an in-run use (GDD §19.2: "invokes extra force"), a running balance would then matter and A would be less wrong. The review changes if that happens.

## 8. Questions and gaps for Jeff

1. GDD gap: §19.2 says Ase can "gate how the player shapes a run, sanctifies an action, or invokes extra force". Today the only in-run Ase use is the retreat (10). Does Jeff want Ase to have an in-run use (for example a sanctified action)? If yes, Ase would have to be in hand during the run, and the stage-end payment (D-65) would need a second look. This review assumes no.
2. GDD gap: no GDD text links the Keeper's flame to the party in a Realm. May the flame glow (B) show a connection between Sanctum and Realm? That is a fiction question for Jeff.
3. Does the realm scale apply to the D-14 partial (12% of the scaled weight, or of the unscaled weight)? Does the replay factor apply to it? The honesty rules need one answer. READ: D-14 says "12% of the weight of completed objectives", and D-63 applies the scale to objective Ase and Ekwan.
4. Should the confirmation line include intel, and which facts (objective locations, requirements)? GDD §20.10 names these. Wording is Jeff's.
5. Is a defeat mid-stage supposed to lose the Ase of objectives already overcome (D-13 and D-14 say yes today)? If Jeff wants completed objectives kept on a defeat, a tally would then be honest as "earned". That is a rule change, not a display change.

## OPEN — questions and assumptions

ASSUMED: Ase has no in-run use except the retreat, and none is wanted now | WHY: D-65 states it | WRONG IF: Jeff wants "invoke extra force" in a run (question 1).
ASSUMED: The mid-stage card is the post-fight Resolve card and today has no Ase row (D-25) | WHY: D-25, D-65 | WRONG IF: the UI session has built a row there.
ASSUMED: Completed objectives pay nothing on a defeat or a retreat except the D-13 consolation and the D-14 partial | WHY: D-11, D-12, D-13, D-14 | WRONG IF: a later decision changed it.
ASSUMED: The example figures use realm.02, scale 1.25, party 4, weights from D-62 | WHY: D-62, D-63 | WRONG IF: Jeff changes weights or scale.
BLOCKED: Does the realm scale and the replay factor apply to the D-14 partial? | CHECKED: D-14, D-30, D-54, D-63 | NEED: Jeff or mechanics-developer.
BLOCKED: May the flame (B) link Sanctum and Realm in the fiction? | CHECKED: GDD §19.2, §2, §5 | NEED: Jeff.
BLOCKED: Should "carried home" include intel? | CHECKED: GDD §20.10 | NEED: Jeff.
BLOCKED: Any chance the game later lets Ase be used in a run? | CHECKED: GDD §19.2 | NEED: Jeff.

## Sources used

Skills: `game-design` (the 5-component filter, false-agency and false-immersion checks, "what just happened and why", reward feedback), `game-mechanics-designer` (reward must feed a decision, loss aversion, honest figures, reward frequency), `echoes-sankofa-gdd` (canon lookup through `docs/canon-index.md` line ranges). I loaded all three earlier in this session and did not reload them for this file.

GDD citations (`docs/Echoes vNext Working GDD.md`):
- §2 Core Concept, lines 44 to 56: the Keeper does not command heroes; risk the people in corrupted Realms.
- §5 Sanctum and Realms, lines 120 to 160: Realms are trials of memory and sacrifice; risk creates attachment payoff.
- §7.3, lines 244 to 260: guidance over control; legibility; observe, guide, interpret, consequence.
- §14.1 and §14.2, lines 2063 to 2093: one recovery track per Realm; not a shard inventory; no third currency.
- §19.2 Ase, lines 3456 to 3492: Ase as life force; flame gathering charge; modest offline trickle; Ase may gate a run, but Realm entry should not cost Ase.
- §20.8, lines 3838 to 3866, and §20.9, lines 4004 to 4018: partly unknown objectives; hidden, not random.
- §20.10, lines 4020 to 4040: failed or withdrawn runs return intel, revealed requirements and location.
- Line 3753: the first-session return carries an ember, some Ase, partial recovery or intel, and a small reward.
Other: `decisions.md` D-02, D-11 to D-14, D-24, D-25, D-28, D-30, D-40, D-42, D-44, D-46, D-47, D-54, D-62, D-63, D-65; `ANSWERS.md` #64 (cause shown on the result).
Not read: the core-loop section in full, the Resolve card code, and the stage explore screen UI. I did not check which objective-progress display already exists on the explore screen.
