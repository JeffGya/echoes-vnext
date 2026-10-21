# V2-ECONOMY-004 Phase 5 — Risk and rank, feel review (round 3, game-feel-developer)

Written in STE. Every number is a PROPOSAL. Jeff decides. Nothing is in `data/balance.json`. I ran no code and no Godot.
Tags: READ = from a file I opened. COMPUTED = my arithmetic. ASSUMED = not verified.
Reviewed: `phase5-risk-and-rank.md` (sr-game-designer), `decisions.md` D-42 to D-47, `phase5-echoes-alive-recheck.md`.
Scale: FEELS RIGHT / RISKY / WRONG. Each reason is tagged anticipation (what the player sees before), feedback (at the moment), consequence (what changes next).

## 0. Findings first

1. The player has no named lever that trades speed for safety. Canon allows levers (GDD 7.3), but the pace documents name none, and the two shipped directives are about scouting style, not about hurry. Today "Swift" reads as strength and luck, not as a choice. This is false agency (game-design skill). It is the main risk of Option C.
2. The real risk choices the player has are bigger than a fight: which realm to enter (GDD 20.8: realm order is player-chosen, difficulty scales with completed realms), whom to bring, and whether to retreat or fight on. Jeff's wish ("risk their Echoes, find the balance") is already served there. A speed mark is a weak place to put it.
3. Option C's binary "Swift" does not match the shipped three-state pace colour (`full`, `partial`, `none`, approved in pace-reward D-25). The designer puts the line at fraction 0.5, in the middle of `partial`. The player would see amber and not know if the mark holds.
4. Option C is a re-design of what the combat rank measures and of the Thread tier link. The pace-reward story already filed that as a separate story (`pace-reward/follow-ups.md` item 1, D-04). Part A only needs a re-base of the rank, because D-40 removes the enemy term.
5. My recommendation differs from the designer's: ship Part A without any Ase paid for speed, re-base the rank with survival-led points (status quo for Threads), and put marks, rank pay and the Thread link in the rank story after a probe. Section 6.

## 1. Verdict per option

### Option A — separate fixed pace bonus (max 6), rank re-based minimally: WRONG

- Anticipation: the bonus is a goal only on pace types (about two thirds of stages). The player sees a 6 Ase prize and no stake on the other side.
- Feedback: a "Bonus 0 / missed" row on a slow, careful win reads as a fine. Jeff already named this.
- Consequence: table 4.4 of the designer shows a loss paying more (10 Ase for 3 of 3 slow is 6, against 10 for 3 of 2 fast). It breaks D-42 in the numbers. A fast run that lost an Echo can also rank S (table 4.1) and keep the Thread clean, against GDD 14.3. I agree with the designer.

### Option B — rank points 0.40 win + 0.40 home share + 0.20 pace; one Rank row pays by grade: RISKY

- Anticipation: the player sees one grade. They cannot predict it from a formula of three terms (hidden formula; false depth risk).
- Feedback: good. No row is ever a "miss". A slow win is "A, 4 Ase". The best result is a goal, not a fine.
- Consequence: speed can offset a loss. A party of 3 that loses 1 and wins fast scores 0.87 = A = a clean Thread (designer table 4.2). The Ase is still lower than all-home. The grade letter says "equal". For the pillar (D-42) the letter matters more than the Ase: it tells the player that a death was free if they were quick. Also against GDD 14.3 ("deaths ... lower recovery quality, not only the letter grade"; lines 2094-2114).
- Good use: as an INTERNAL rank score with no Ase attached, it is close to today's behaviour (section 6).

### Option C — two visible marks (All home, Swift), grade S/A/B/C, pay 8/4/2/0 plus the stipend: FEELS RIGHT as a structure, RISKY as specified

- Anticipation: two named goals on one list is the clearest form of the three. A new player can predict the grade 8 of 10 times (game-design Clarity test): the marks ARE the formula. RISKY only because Swift has no known lever (section 2) and because its threshold clashes with the three colour states.
- Feedback: the all-home steady player gets A, a clean Thread, 4 Ase. That is a good base case, not a penalty. The second mark is a visible extra.
- Consequence: a death takes the grade down two steps (A to B, or S to B), makes the Thread compromised, and removes 2 Ase of stipend and 2 to 6 of rank pay. The cliff is real (section 3). Speed never buys back a death, which is right for D-42.
- Checks I ran on the designer's tables: C is monotone in survival at every pace (table 4.3), and the Ase check holds (best loss case 6 against worst all-home case 10; table 4.4). The pillar test passes.

### Option C2 (softer for parties of 4 or more): RISKY

- It protects a clean Thread for one death in a large party. It also teaches "one in four is an acceptable loss when I am fast". That is the trade Jeff wants. But it makes the rule party-size dependent, so the player cannot predict it as simply as "any death compromises". It also makes speed matter for the Thread tier, against the designer's own clean rule that only survival moves the tier. I would hold C2 until the probe shows how often a single death happens in a party of 4 or more.

## 2. Is risk a real, fair choice in Option C?

Answer: not at the level of Swift, as the docs stand today. Plainly:

READ (levers named in canon and docs):
| Lever | Source | Does it trade speed for safety? |
|---|---|---|
| Formation, set before the fight | GDD 7.3 ("may prepare a formation") | Possible. A formation changes distance. But the par is computed from that same distance (mean Echo distance to the nearest enemy / move range; `pace-reward/design.md` par definitions). A closer start shortens the par too. So formation does not directly buy pace. Unproven. |
| Broad party intent (directive) | GDD 7.3, 20.11; CONVENTIONS 928-957 | Two directives exist: `Scout Carefully` (survival_bias, avoid_overcommit, prefer_disengage) and `Seek Signs` (clue_seeking, reporting, exposure_acceptance). Scout Carefully leans to safe and slow. Seek Signs leans to exposure. This is the closest thing to a safety-for-speed lever. But both are scouting styles and GDD 20.11 keeps the opening to these two. Whether they change fight speed or loss rate is not measured. |
| Limited spatial guidance during the fight | GDD 7.3 | Named in canon. Whether it is built and what it does to pace is not in the docs I read. |
| Playback speed | GDD 7.3 | Cosmetic. It must not change results (my hard constraint). Not a lever. |
| Party choice (who and how many) | Roster | A stronger party wins faster and loses fewer. That is not a trade. It is growth. |
| Retreat or fight on | GDD 20.10; D-46 | A real risk lever, but about survival and the stage, not about speed. |
| Realm order | GDD 20.8 | A real risk lever at the macro level. |

The pace-reward `design.md` and `decisions.md` contain no word about directives, guidance or any lever for pace (I searched: 0 hits). The pace goal was designed as a result of the fight, not as a choice.

What this does to "Swift": it becomes a mark earned by party strength and matchup. A stronger party earns it more. A careful player is not choosing to be slow; they are just weaker, or unlucky with the board. The mark then rewards power, which growth already rewards. Players will read an unearned Swift as "my party is not good enough yet", not as "I chose safety". That is not a penalty feel if the card says nothing negative, but it is not a risk choice either. Jeff's goal ("not always take the safe route") is not served by it.

Where the real risk choices are, and what would make them fair:
1. Retreat versus fight on (D-46: price about 10, no stipend, partial payout kept). The player sees the cost and the stake, and decides. This is a real, fair risk choice already, if the price is shown before the choice and the stake (Thread, stipend) is known.
2. Realm order (GDD 20.8): the player picks a harder realm early and risks more for higher objective pay (realm scale). This is the cleanest "risk and reward" in the game. It needs no mark.
3. A speed lever: if Jeff wants Swift to be a choice, a lever must exist. I cannot design it in this review (it is a combat or directive item). I name the need: a player action whose stated effect is "hurry" and whose stated cost is "more exposed". Until then, I advise not to put Ase on Swift.

Probe request (for qa-verifier or mechanics-developer, not for me): over many fights, compare, per directive and formation, the Swift rate and the Echo loss rate. If neither moves, Swift is luck. If Swift correlates with more losses, there is a hidden lever.

## 3. Does C punish a slow, careful player? Is a death too crushing?

Slow careful player: no, on the numbers. All home and slow = A, a clean Thread, full stipend, 4 Ase rank pay (designer table 4.4 shows 10 Ase against 14 for S: 4 less, 29% of the rank-plus-stipend sum, about 12% of a stage's income). The risk is in the display, not in the Ase:
- An empty "Swift" mark can read as "you failed". Direction: show the mark as earned or not yet earned in a neutral state. No red, no "missed", no zero row. The shipped muted "+0" row for the pace bonus (pace-reward D-28) is the pattern to avoid for new marks, or to reuse as a neutral pip.
- The base case must be named plainly as the good case (a clean Thread).

One death in a two-step drop plus a compromised Thread: what the player lives at that moment.
- The Echo is gone for good (GDD 20.10; line 4338: "permadeath remains core"; death ripple). That is already the heaviest consequence. A grade drop is small beside it.
- The Thread is compromised. GDD 14.3 supports it. GDD 15.6 says "not every wound should disappear cleanly" and names remedy routes (balancing virtues, Sanctum rites, relationship care). A compromised segment is therefore a story consequence with a path, not a dead end. This makes it fair, if the player can see that a path exists.
- The stipend loses 2. The rank pay loses 2 to 6. Ase impact is small (Ase is not the point).
- Crushing? The sum is large for one event: a person, a grade, a Thread tier, Ase. For a party of 2 this is the death of half the household: proportionate. For a party of 5 it is one in five and the same drop feels sharp. That is the case for C2 or for a softer rule; the data to decide it is the probe's loss frequency.
- Fair? Yes if the cause is readable: the card names the Echo, says why the Thread is marked, and shows no "minus" number against the person. The Thread consequence is the stake the player knew about before the fight (section 4).

What a stage with a loss looks like in the ledger (what the player must read; not a UI design):
- Objectives overcome: unchanged, full.
- "Home 3 of 4": the stipend for 3, no minus line (alive recheck section 3). The count carries the loss.
- Rank row: the grade and the two marks. "All home" shows as not earned in a neutral way. "Swift" shows its own state.
- The Thread tier appears with its cause in plain words: someone did not come home, so the Thread carries a mark. One mention, not repeated in two rows.
- The lost Echo is named once, in the Echo list the compact layout already shows (UI D-01), not in the ledger.
- Tooltips (UI D-02): the Rank row tooltip states what made the grade, in the "party" voice (UI D-06). Copy is Jeff's.

## 4. What the player must see BEFORE the fight, for the two marks

Not a UI design. The player must be able to know:
1. That a grade exists for this fight and that two things shape it: everyone coming home, and finishing quickly. In plain words, as a list of two goals.
2. Whether the quick goal exists on this objective type. On `protect`, `endure` and the `guide_spirit` protect variant it does not (`PaceService.is_pace_mode`; pace-reward D-06: show nothing). Show nothing there, not a crossed-out goal.
3. What "quickly" means in a way the player can act on. Today the round target (the par) is not in the snapshot (pace-reward D-20) and the pace shows by colour only (D-12). If Swift becomes a mark, the player needs at least the plain rule ("win before the colour turns") and, if Jeff allows, the target round. That reverses part of D-12 and D-20, so it is Jeff's call.
4. The stakes, stated once: if an Echo falls, the Thread will carry a mark (and where that matters). A risk is a fair choice only if the stake is known before it is taken.
5. For the retreat choice: the price (about 10), and what comes back (nothing until one objective is overcome; D-14).
6. The mark colours must match one meaning. The mark is binary but the colour has three states. PROPOSAL: either define Swift as the `full` state only (win by 1.1 x par; the colour is green), or collapse the colours to two states for Swift (held, not held). Do not draw the line inside `partial`. The designer's 1.35 x par would split amber into two meanings.

## 5. Scope: is C a Part A reward-tuning change?

Recommendation: no. Split it.

Reasons:
1. READ: `pace-reward/follow-ups.md` item 1 already filed "decide what the combat rank must measure" as a separate story, owner sr-game-designer with game-feel-developer. Option C is that story's answer.
2. C changes a game outcome, not only a payout: it moves the Thread tier on a single death (a survival rule; GDD 14.3) and retires `rank_thresholds`, `max_possible`, `pace_bonus_pct`. It needs a probe, a fingerprint re-record with attribution and a UI contract change (`rank_pay`, two marks). That is more than one subject.
3. The designer's own gap list says no GDD text sets what the combat grade measures (designer section 7, question 6). A design that has no canon behind it needs Jeff's explicit decision, outside a tuning phase.
4. What Part A cannot avoid: D-40 removes the enemy term, so the rank must be re-based. That is a consequence of Part A and belongs in it. The re-base must not change Thread outcomes (section 6).

## 6. My recommendation (separate from the designer's)

Recommended: Variant R0 — pay nothing for speed in Part A; re-base the rank; do marks and rank pay in the rank story.

Part A:
1. Ase rows in a win: objectives overcome, Echoes home (D-43, D-44), and replay or consolation when they apply. No bonus row. No rank pay row.
2. Objective weights carry the cadence. Without the 6 Ase bonus, the cadence target needs about 27 gross per stage without any bonus (my alive recheck section 4 already sized the weights for that; the bonus was extra). Nothing in my numbers needs the bonus.
3. Rank re-base (internal only, no Ase attached): points as in Option B (win 0.40, home share 0.40 x alive / started, pace 0.20 x fraction; no-pace modes divide by 0.80), same thresholds. Reason: it is independent of `base`, party size and Ase tuning; it keeps survival the largest term; and it is close to today's behaviour (today one lost Echo of 2 with full pace is A; under B it is A at full pace and B at partial). So Threads do not change in Part A. Thread tier changes stay a deliberate decision.
4. Pace stays as the in-fight colour and as a rank term. It pays no Ase. The Resolve card shows the pace state as information with no amount.

Rank story (separate, after Jeff decides what rank measures):
1. A probe: does any directive or formation move Swift or the loss rate (section 2)?
2. If a lever exists: Option C with the two marks, Swift tied to the `full` colour state, the Thread rule decided by Jeff (C or C2), rank pay set to keep the cadence.
3. If no lever exists: do not pay for Swift. Keep it a prestige mark. Put the risk reward in realm scale and objective weights (harder realm pays more).

Why R0 and not C now:
1. Swift has no proven lever (finding 1). Paying for it pays strength.
2. It keeps Part A one subject (one story, one subject).
3. It avoids a row that reads as a penalty. Jeff's own worry (D-47).
4. It keeps D-42: speed never pays more than survival, because speed pays nothing.
Cost: Jeff's wish for visible risk-taking waits for the rank story. Retreat versus fight on, and realm order, already carry it.

If Jeff wants a speed reward inside Part A anyway, choose C with these fixes: Swift = the `full` state only; "All home" alone gives A; no Ase on "Swift" below S (B and C pay 0 or 2 as the designer proposes); a neutral display for the unearned mark; a stated Thread stake before the fight; and a Jeff decision on C against C2.

### Disagreements with the designer, ranked

| Rank | Disagreement | Reason | Proposed resolution |
|---|---|---|---|
| 1 | Recommending C inside Part A | A rank redesign with a Thread rule and no canon definition of the combat grade; already filed as a separate story | Part A re-bases the rank (B points, no Ase); C goes to the rank story |
| 2 | Treating "risk lives in the player's tactics" as satisfied | No named lever; docs name none for pace | Probe first; if no lever, pay nothing for Swift |
| 3 | Swift at fraction 0.5 (1.35 x par) | Splits the shipped amber `partial` state into two meanings | Swift = `full` state only, or two colour states |
| 4 | Designer's tables treat "1.0 pace" as a result any party can reach | Pace is deterministic from board and party strength; weak parties never reach it | Report the Swift rate by Standing in the probe |
| 5 | "All home" alone gives S in no-pace modes | Easier S on about a third of stages; pays 8 against 4. Small | Acceptable; Jeff decides. Survival is the objective of `protect` and `endure`. |
| 6 | C2 held for later | Agree to hold, for a different reason | Hold C2 until the loss-frequency data exists |
| 7 | Agree: A is wrong; the Thread should drop on a death (GDD 14.3) | Same reading | No change |

### What I would tell Jeff in 5 lines

1. Option A is wrong: a loss can pay more. B hides a formula. C has the clearest shape.
2. Speed is not a choice yet: no player action trades speed for safety. The real risk choices today are realm order and retreat or fight on.
3. So do not pay Ase for speed in Part A. Re-base the rank with survival as the biggest term, so Threads stay as they are.
4. Move "two marks, rank pay and the Thread rule" to the rank story. First check by probe whether a directive or formation changes speed or losses.
5. When Swift returns, tie it to the green state only, show the Thread stake before the fight, and show an unearned mark without red.

## 7. Sources used

Skills loaded in this session: `game-design` (Clarity and Satisfaction tests, the false-agency check for risk without a lever, abuse cases); `echoes-sankofa-gdd` (canon lookup by line range). No other skill.

GDD (`docs/Echoes vNext Working GDD.md`):
| Lines | Section | Used for |
|---|---|---|
| 244-260 | 7.3 Guidance over control | Levers named in canon: formation, broad intent, playback speed, limited spatial guidance |
| 2094-2114 | 14.3 Segment quality | Deaths lower recovery quality, not only the grade |
| 2590-2612 | 15.6 Remedy and recovery | A compromised result has remedy routes; scars allowed |
| 4097-4115 | 20.11 Directives in the opening slice | 1 to 2 starter directives, scouting tone |
| 3838-4003 | 20.8 Stage structure (read earlier) | Realm order player-chosen; difficulty scales with completed realms |
| 4018-4026, 4334-4342 | 20.10; death, withdrawal, loss (read earlier) | Permadeath core; death ripple; withdrawal safety valve |
Other READ: `phase5-risk-and-rank.md` (all); `decisions.md` D-42 to D-47; CONVENTIONS lines 928-957 (DirectiveService registry); `pace-reward/follow-ups.md` item 1; `pace-reward/decisions.md` D-06, D-12, D-20, D-25, D-28; `pace-reward/design.md` section 6 (read earlier) and a search of `design.md` and `decisions.md` for directive, guidance, lever, control (0 hits).
Not verified: the code of `RewardCalc`, `PaceService` and the directive effects; the designer's rank numbers (I used its tables as given); whether limited spatial guidance is built.

GDD gaps (QUESTIONS for Jeff):
1. What must the combat grade measure? No canon text names it (GDD 14.3 says it "can influence" segment quality).
2. Is there any GDD text on a speed reward, or on a player action to "hurry"?
3. Should a death always mark the Thread, or may a fast win keep it clean?
4. May the target round of a quick goal be shown before the fight (reverses pace-reward D-12 and D-20)?

## OPEN — questions and assumptions

ASSUMED: The directives `Scout Carefully` and `Seek Signs` are the only combat-relevant intent levers today | WHY: CONVENTIONS 928-957 lists two registry entries; GDD 20.11 limits the opening to them | WRONG IF: a formation or guidance lever already changes pace and loss rate
ASSUMED: Pace is deterministic from board and party, so weaker parties reach Swift less often | WHY: `design.md` par definitions (distance and move range) | WRONG IF: the code adds randomness to the round count
ASSUMED: Internal rank points (Option B) leave Thread outcomes close to today's | WHY: designer table 4.2 against today's 0.78 = A example | WRONG IF: the real fight data shows a different spread (needs the probe)
ASSUMED: Dropping the Ase bonus does not break the cadence | WHY: my alive recheck section 4 sized the weights without it | WRONG IF: Jeff wants the weights kept at Set B values
BLOCKED: Do directives or formation change the Swift rate or the loss rate? | CHECKED: GDD 7.3, 20.11, CONVENTIONS 928-957, pace-reward docs (no mention) | NEED: a probe (qa-verifier or mechanics-developer, run by the main chat)
BLOCKED: Is limited spatial guidance built, and does it affect pace? | CHECKED: GDD 7.3 only | NEED: mechanics-developer
BLOCKED: Is the rank/Thread redesign a separate story, and who owns it? | CHECKED: `pace-reward/follow-ups.md` item 1 | NEED: Jeff
BLOCKED: One death compromising the Thread (C) or a softer rule (C2, B) | CHECKED: GDD 14.3, 15.6 | NEED: Jeff
BLOCKED: May the target round for the quick goal be shown before the fight? | CHECKED: pace-reward D-12, D-20 | NEED: Jeff
BLOCKED: Wording for the rank marks, the Thread stake and the neutral unearned state | CHECKED: UI D-04, D-06, D-07 | NEED: Jeff (copy), UI session (layout)
