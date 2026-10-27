# V2-ECONOMY-004 Phase 5 — Running tally, feel review (round 6, game-feel-developer)

Written in STE. Every number is a PROPOSAL or an example. Jeff decides. I ran no code and no Godot.
Tags: READ = from a file I opened. COMPUTED = my arithmetic. ASSUMED = not verified. MEMORY = my general knowledge, not checked now.
Rank order follows D-48: game quality first (clear, engaging, fun, the Echoes pillar). Build size is not used.
Reviewed: `phase5-running-tally.md` (sr-game-designer), `decisions.md` D-14, D-25, D-42, D-47, D-65, `phase3b-design-check.md` (stage settlement facts).
Scale: FEELS RIGHT / RISKY / WRONG. Tags: anticipation (what the player sees before), feedback (at the moment), consequence (what changes next).

## 0. Findings first

1. A running tally in Ase is the wrong tool. The need behind it is real, but it is a need for stakes and meaning in the mid-stage moment, not for a number. Agree with the designer on A and on D-25.
2. A mid-stage card exists in a minority of stages. Realm.01 stages have one pre-boss objective (Phase 1: 700 of 700), so a realm.01 stage has no mid-stage objective card. In realm.02 about half of the stages have two (611 of 1187). Spend little on it, but make it good.
3. The "carried home" figure (C) is mostly 0 or about 4. Per D-14 it pays 0 until one objective is won, then 12% of its weight. Shown alone it reads as "this is all you keep". It needs a comparator, people and intel beside it. And the real cost of leaving is the 12% rule, not the display.
4. Unknown that decides whether "carried home" is honest: after a return home, is an overcome objective still overcome when the party comes back? GDD 20.8 says an unresolved stage locks and keeps what the player learned. If the objective stays overcome, leaving is a delay, not a loss, and the confirmation must say so.
5. I replace the designer's flame glow (B) with a state the player can keep or break: the stage's Thread, "whole so far". It is true, it needs no new fiction, and it puts the pillar (keep Echoes alive) on the mid-stage card.
6. Ase having no in-run use is not a design problem by itself. The felt gap is feedback. Three ways to give the moment meaning without paying Ase early are in section 5.

## 1. Verdict per form

| Form | Verdict | Anticipation | Feedback | Consequence |
|---|---|---|---|---|
| A. Exact "earned so far" | WRONG | The player starts to do arithmetic and to watch a till. The Realm is a trial of memory and sacrifice (GDD 5, lines 125-132), not loot. | "Earned" is untrue. A defeat pays 25% of the fought weight (D-13) and a return pays 12% (D-14). The number the player saw then shrinks: that is the cheated feeling. | Loss aversion (MEMORY: well documented in behavioural research) makes leaving feel like losing the figure. It pushes the player to press on. It also adds a second accumulator beside the recovery track, which GDD 14.1-14.2 refuses ("intentionally not a shard inventory"; no "third currency"). Only about half of realm.02 stages would show it. |
| B. Flame glow, wordless | RISKY | A glow that rises with each objective suggests a goal. The hidden objectives (GDD 20.8) mean the player cannot know when it is full. | Warm, but it carries no data. It repeats the objective mark. Colour or light alone is also weak for accessibility. | Needs a canon link between the Keeper's flame and a party away. I found none (GDD 19.2 uses the flame for offline gathering only). Replace with the Thread state (section 2). |
| C. "Carried home if you leave" at the decision | FEELS RIGHT only with a comparator; RISKY alone | The number appears when it informs a choice. Good. | Alone it reads "you get 4". Often it reads 0. A small number or a zero reads as a penalty. | It shows the true price of leaving. If the price feels too high, the cause is D-14 (12%, and 0 before a win). Display cannot fix a rule. See section 3. |
| D. None | RISKY alone | Clean, no loot frame. | The mid-stage win says nothing. The player gets a result with no moment. | Leaves the press-on-or-go-home choice with no readable stake. Fine as a base only if section 2 fills the moment. |
| E. Designer's: D + C + optional B + story content | FEELS RIGHT as a direction | Each part has one job. | The mid-stage card carries people, what was learned, and the choice. | Change three things: B becomes the Thread state; C gets a comparator and reassurance; the unknown in finding 4 must be answered. |

## 2. The empty mid-stage card: best content after a mid-stage win

What the player feels at that moment, in order:
1. Relief: "they made it".
2. Fear for the wounded: "how bad is it, who is shaken".
3. Curiosity: "what did that open up, what is next".
4. A decision: go on, or go home.

The card should answer in that order. People first, the number never. Content (what the player must be able to know; not a layout):
| Order | Content | Why | Source |
|---|---|---|---|
| 1 | The party together, each Echo in their current state (the ten emotional statuses, ANSWERS #66) and who is hurt. A count of who is still with the party. | Relief and fear. The player reads their people before anything else. | D-44: mid-stage cards show the count only |
| 2 | One short line about what the fight changed between them, in the project voice (plain, a family record, no system words). Only when the simulation has a real event to report (a refusal, a rescue, a shaken Echo). No invented lines. | The win feels like it happened to people. | Voice rule; GDD 7.3 chain: observe, guide, interpret, consequence |
| 3 | The objective result as a mark in story terms ("found", "done"), no Ase. If the fight was not an objective, say only that the way is open. | Clear cause for the win (ANSWERS #64). | `objectives_overcome` idiom |
| 4 | What is now known about the stage (a revealed objective type or place). | Curiosity; the reward of scouting. | GDD 20.8, 20.10 |
| 5 | The Thread state: "whole so far" while nobody has fallen. | The stake of the pillar made visible. See below. | GDD 14.1, 14.3; D-50 |
| 6 | The choice: go on or go home, with the section 3 content beside "go home". | The decision comes last, after the player has read the people. | GDD 20.10 |

Pacing (sequencing before effects): people resolve first, the choice appears after a short beat. The tap on any control must still answer at once.

The Thread state in point 5. D-50 says any dead Echo makes the stage's Thread compromised. Under the rank re-base (all home = at least A, clean; D-49), a stage with no death cannot end compromised. So "no one has fallen: the Thread is whole so far" is true at every mid-stage moment and can only get worse. A status that can be kept or broken is a better mid-stage reward than a gauge that only rises. It rewards survival (D-42) and makes the later risk readable (D-47). ASSUMED: the re-based rank never lowers a no-death stage below A (my round 3 section 6; unverified in code).

Do not show an empty fight group or a "0 Ase" row. The designer is right: a zero row says the fight was worth nothing.

The card must also work after a fight that is not an objective (an encounter on the way). That pays nothing (D-22). Points 1, 2, 4 and 5 still apply.

## 3. The return and retreat confirmation

Does "carried home" read as a fair choice or a penalty? Alone it reads as a penalty, because:
- It is often 0: in realm.01 a stage has one objective, so leaving before the win pays 0 (D-14). After one win in a two-objective stage it is 12% of that weight, about 4 Ase against about 60 at the stage end (the designer's example).
- It has no comparator. The player cannot see what finishing adds without a total, and a total would leak hidden objectives (GDD 20.8).

What must stand beside it (what to show, not a layout):
1. The people: everyone safe, with their state. This is the main reason to go home. It is the value of the choice.
2. What was learned: intel, revealed requirements, objective place (GDD 20.10: a failed or withdrawn run "returns intel"; reruns are "learning rather than pure punishment").
3. Whether the stage waits. GDD 20.8: an unresolved stage locks and keeps what the player learned. If an overcome objective stays overcome, say so plainly. This changes "carried home" from a loss to a delay. UNKNOWN in the docs I read: see BLOCKED 1.
4. A comparator that does not leak: if the next objective is revealed, its "if overcome" figure (the D-38 estimate form); if not, "not yet known". Never a total, never "of N".
5. The cost of the action in the same place: return home at the map versus a retreat before round 1 (10 Ase, D-46). Show which one the player is choosing.
6. Wording direction (copy is Jeff's): "carried", never "lost", "only" or "left behind". No red. Show the Ase line only when it is above 0. A line that reads "0 Ase" teaches nothing.
7. Reuse the shipped row vocabulary and its cause text ("The party left early. It keeps a small part of what it overcame.", UI D-05) so the confirmation and the stage ledger say the same thing.

Is the partial rule itself fair? That is Jeff's call, not a display call. Plainly: with 12% (D-14), leaving after a win throws away most of that win's pay (unless it stays overcome). If Jeff wants "go home" to be a fair option under D-47, the better fix is a rule: an overcome objective stays overcome and pays at the later stage end. Display cannot do that.

One more risk. The return-home partial has no stamp (B5, `phase3b-design-check.md` line 132): it can pay again on each return. A visible "carried home" figure makes that loop visible and tempting. Close B5 before the figure ships.

## 4. Loss aversion: agree or disagree?

Partly agree, partly disagree.
- Agree: a figure that rises (A) frames leaving as a loss and pushes the player to press on. That works against D-42.
- Disagree with the framing: Jeff also wants risk-taking (D-47). A push to press on is not the problem. The problem is that the push is invisible next to the stakes of the Echoes. The push exists anyway, built into the rules: finishing pays about 60 and leaving pays about 4 (or 0).
- Does C fix it? Not alone. C shows a small positive number and removes the "lost 30" anchor. That helps. But it also reveals how little leaving pays. Parity of stakes fixes it: the same moment shows the people (hurt, shaken), the Thread state and the intel. Then the player weighs Ase against people, not against nothing.
- Arithmetic check: a lost Echo costs at least the next summon price (60 to 145+) plus its skills, and the person. Ase never beats an Echo in a rational comparison (designer section 2.2). The risk is attention: a number the player watches pulls eyes from fear and wounds. Keep numbers off the mid-stage card and put them only in the confirmation.

## 5. Is "Ase has no in-run use" a design problem?

Short answer: the lack of in-run use is not a problem. The lack of in-run MEANING is. A reward paid at the end of a 10 to 15 minute run is normal. MEMORY (unchecked): XCOM pays after the mission; Darkest Dungeon brings loot home to spend at the hub. The player does not need to spend Ase inside the Realm to feel the run matters. They need the run to say something while it happens.

The stage end is where the reward lands. My earlier files already cover it: the party first, the count "home N of M", then the Ase, then a visible step on the goal bar ("now 52 of 85"). That is the payoff moment. What is thin is the middle.

Options to give the in-run moment meaning WITHOUT paying Ase early (Jeff chooses; I rank by game quality):
| Option | What it is | Fit | Notes |
|---|---|---|---|
| 1. Story and stakes on the card (section 2) | People's state, what the fight changed, intel gained, Thread "whole so far" | GDD 7.3, 14.1, 20.10, pillar D-42 | Uses systems that exist. No new mechanic. Recommended. |
| 2. A guidance moment between objectives | After a mid-stage win the player may adjust broad intent (a Directive) before the next objective. This makes the card a real decision about speed against safety. | GDD 7.3 allows broad party intent; D-56 says more Directives are wanted | New design. GDD says the Keeper prepares formation and intent; it does not say it may do so mid-stage (gap). Needs sr-game-designer. Best long-term form of the moment. |
| 3. Ase already in hand has an in-run use | The player brings Ase from the Sanctum and may spend it in the run (a sanctified action, extra force) | GDD 19.2 says Ase should "gate how the player shapes a run, sanctifies an action, or invokes extra force" | Today the only in-run sink is the retreat (10). It is a real economy change, close to Part B (rites). Larger. It uses balance the player already owns, so no early payout. |
Not offered: any early or partial Ase payout. Jeff excluded it, and it would break "paid at the stage end" (D-65) and the honesty rules in the designer's section 4.

## 6. Disagreements with the designer, ranked

| Rank | Disagreement | Reason | Proposed resolution |
|---|---|---|---|
| 1 | "Carried home" (C) is shown as one figure with the people and intel | It is mostly 0 or about 4, with no comparator; it reads as a penalty | Add a non-leaking comparator (D-38 estimate if the next objective is revealed), the "stage waits" line if true, and show the Ase line only above 0 |
| 2 | The honesty rules do not ask whether an overcome objective survives a return | If it does, "carried home" understates and misleads. This decides the whole confirmation | Answer BLOCKED 1 before any figure ships |
| 3 | Flame glow (B) offered as optional | No canon link; no data; duplicates the objective mark | Replace with the Thread state "whole so far" (section 2) |
| 4 | Loss aversion framed as a defect | Jeff wants risk (D-47). The push is structural (60 against 4) | Treat parity of stakes as the fix; if the push is too strong, change the D-14 rule, not the display |
| 5 | Mid-stage card not sized | It exists in about half of realm.02 stages and none of realm.01 | Keep the content small; do not build a system for it |
| 6 | B5 (unstamped repeat partial) is outside the review | A visible figure makes the loop obvious | Close B5 before showing C |
| 7 | Agreed | A is wrong; D-25 stands; no zero rows; stipend not in a tally; "carried", never "earned"; no totals or "of N" (GDD 20.8) | No change |

### What I would tell Jeff in 5 lines

1. A running Ase tally is the wrong tool: it frames the Realm as loot and it would be untrue after a defeat or a return.
2. Give the mid-stage win meaning with people and stakes: how they are, what changed, what was learned, and "the Thread is whole so far".
3. Show "carried home" only at the go-home decision, with the people, the intel, and whether the stage waits for them. Alone it reads as a penalty.
4. Answer one question first: does an overcome objective stay overcome after a return home? And close the repeat-return payout (B5).
5. Ase having no in-run use is fine. If you want more, give Ase you already hold an in-run use, or add a guidance moment between objectives. Do not pay early.

## 7. Sources used

Skills loaded in this session: `game-design` (Clarity, Satisfaction, false-agency and false-immersion checks; "what just happened and why"); `echoes-sankofa-gdd` (canon lookup by line range). No other skill.

GDD (`docs/Echoes vNext Working GDD.md`):
| Lines | Section | Used for |
|---|---|---|
| 109-114, 125-132 | 4 Primary fantasy; 5 Sanctum and Realms | The Keeper trusts what the Echoes became; Realms test what the Sanctum shaped |
| 244-260 | 7.3 Guidance over control | Observe, guide, interpret, consequence; levers named in canon |
| 2063-2093 | 14.1, 14.2 | One recovery track; "not a shard inventory"; no "third currency" |
| 2094-2114 | 14.3 (read earlier) | Deaths lower recovery quality |
| 3454-3515 | 19.2 (read earlier) | Ase as living force; Ase may gate a run |
| 3838-4003 | 20.8 (read earlier) | Hidden objectives; stage locks on entry; reruns keep what was learned |
| 3750-3756 | First-session return | The party returns with Ase, intel and a small reward |
| 4018-4045 | 20.10 | Withdrawal returns intel, requirements, location; reruns are learning |
Other READ: `phase5-running-tally.md` (all); `decisions.md` D-14, D-25, D-42, D-47, D-65 (and D-13, D-22, D-44, D-46, D-49, D-50, D-56 as cited); `phase3b-design-check.md` lines 80 to 135 (settlement, B5); UI `v2-payout-explanation/decisions.md` D-05 (row text).
I checked the designer's GDD citations for §14.1, §14.2, §20.10 and the line 3750 return: they match the text.
Not read: the core-loop section in full, the Resolve card code, the explore screen UI, whether the Thread state is available on the mid-stage snapshot. MEMORY claims (loss aversion, XCOM, Darkest Dungeon) are unverified.

GDD gaps (QUESTIONS for Jeff):
1. After a return home, does an overcome objective stay overcome when the party re-enters the stage?
2. May the Keeper change broad intent between objectives of one stage?
3. Is there a canon link between the Keeper's flame and a party in the Realm (needed only for a flame glow)?
4. Does Jeff want Ase to have an in-run use beyond the retreat (GDD 19.2 allows it)?

## OPEN — questions and assumptions

ASSUMED: The re-based rank never lowers a no-death stage below A, so "Thread whole so far" is true mid-stage | WHY: my round 3 section 6 and the B points (0.40 + 0.40 minimum 0.80 = A) | WRONG IF: the final rank rule differs or the rank can lower the tier without a death
ASSUMED: Realm.01 stages have one objective and so no mid-stage objective card | WHY: Phase 1 section 2 (700 of 700) | WRONG IF: realm.01 content changes
ASSUMED: The mid-stage card can read party state and intel from the existing snapshot | WHY: it already holds fight rows and objective marks | WRONG IF: the snapshot lacks them
ASSUMED: The partial figure is 12% of the (scaled, replay-adjusted) completed weight | WHY: D-14, D-30, D-54, D-63 as the designer reads them | WRONG IF: the scale and replay do not apply to it (designer question 3)
ASSUMED: My MEMORY examples are accurate in outline | WHY: general knowledge | WRONG IF: Jeff wants evidence
BLOCKED 1: Does an overcome objective stay overcome after a return home, and is the 12% partial then deducted from the later payout? | CHECKED: `phase3b-design-check.md` (a completed stage is not re-entered; unresolved stage behaviour not stated), GDD 20.8 | NEED: mechanics-developer (code) or Jeff
BLOCKED 2: Close B5 (repeat return-home partial has no stamp) before any carried-home figure is shown? | CHECKED: `phase3b-design-check.md` line 132 | NEED: Jeff
BLOCKED 3: May the Keeper change broad intent between objectives (option 2)? | CHECKED: GDD 7.3, 20.11 | NEED: Jeff and sr-game-designer
BLOCKED 4: Does Jeff want an in-run Ase use (option 3)? | CHECKED: GDD 19.2 | NEED: Jeff
BLOCKED 5: Wording for the mid-stage lines, the Thread state and the go-home confirmation | CHECKED: UI D-04, D-06, D-07 | NEED: Jeff (copy), UI session (layout)
