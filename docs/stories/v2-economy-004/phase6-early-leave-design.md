# V2-ECONOMY-004 Phase 6: early leave carries by a roll (design)

Author: sr-game-designer. Date: 2026-10-26. Status: OPTIONS for Jeff. Nothing here is decided.
Basis: D-04, D-65, D-72, D-79, D-102, D-103, D-104 in `decisions.md`.
Every number below is a PROPOSED DEFAULT for `mid-game-designer`, except the odds 50/30/20 (Jeff, D-104).
All player text is a PROPOSAL (project voice). Jeff approves each line.

## 0. Facts read from the code (not from comments)

| Fact | Where |
|---|---|
| `carry_plan` pays 12% (`partial_intel_reward_factor`) of the completed-objective amount, times `retention_mul` (Ase only), minus `carried_ase`. Needs at least one revealed situation. | `StageSettlementService.gd:255-284` |
| `retention_mul` is 1.5 for Scout (`intel_retention_bonus`) and 1.0 for Seek. | `balance.json:33-34, 69-70` |
| Return home draws the escape roll from `stage.escape.<stage_id>.<turn_count>`. Same turn = same roll. The carry runs only after the escape succeeds. | `VentureController.gd:324-370` |
| The retreat success roll uses `encounter.retreat.<encounter_id>.<t>`. The retreat passes `retention_mul` 1.0. It runs before round 1, so no fight state exists yet. | `FlowRuntime.gd:1158-1235` |
| The retreat cost (10) is spent before the roll, win or lose. Cost is `data.combat.retreat_ase_cost`. | `RetreatService.gd`, `FlowRuntime.gd:1175-1190` |
| The stage payout subtracts `advance = min(carried_ase, gross)`. Gross includes the stipend. | `EconomyService.gd:245` |
| An uncleared stage pays nothing at settle. The carry is the only Ase from a failed run. | `StageSettlementService.settle` |
| `engage_situation` clears `pending_situation_id`, marks the situation `revealed`, and does not resolve it. `stage.ignore_situation` marks it `passed`. A passed objective returns when the map is fully explored (Tier 4). | `SituationEngagementService.gd`, `VentureController.gd:405-430` |
| A precedent for a one-time persisted roll exists: ANSWERS recruit roll, "computed once at resolution and persisted (no re-roll on Continue)". | `ANSWERS.md` #28 |

Key consequence of D-72 plus D-104: **the carry is an advance, not a prize.** If the player later clears the stage, the total Ase is the same.
A 0% roll costs nothing in total. It only delays the money. The roll matters in three cases only: the player never finishes the stage, the party is defeated, or the player needs Ase now (summons, skills).
The confirmation panel and the Resolve card must say this plainly. If they do not, the player will read a 0% roll as a loss.

## 1. The roll

### Rule that blocks every re-roll (needed by all options)

Each unit of gathered Ase is rolled **once**. The stage record keeps `carry_rolled_ase` (the gathered base already rolled) and `carry_roll_count`.
At a leave, `new_gathered = gathered_now - carry_rolled_ase`. If `new_gathered <= 0`, no roll is drawn and the carry is 0 more.
If `new_gathered > 0`, one roll is drawn. The carry is `share x new_gathered` (rounded once). Then `carry_rolled_ase = gathered_now` and `carry_roll_count += 1`. A 0% result still counts as rolled.
Why: D-72 subtracts what was carried, so without this stamp a later leave could roll 100% on the whole amount again (a ratchet). With the stamp, the total carried over any number of leaves has an expected value of 35% of the gathered amount, and never more than 100%.
Ekwan uses the same single roll and the same share. One roll, two currencies.

### Options for the stream

| Option | Stream | Result |
|---|---|---|
| A (pick) | `CampaignSeed.get_rng_from(realm_seed, "stage.carry.<stage_id>.<run_count>.<carry_roll_count>")`, one `randi_range(0, 99)` mapped on the cumulative weights | Own path-derived stream. No existing draw moves. Same stage state = same result. |
| B | Same, but keyed by the number of objectives overcome instead of `carry_roll_count` | Also stable. The result depends on play order. Two leaves with the same count give the same roll, which is odd. |
| C | Reuse the retreat stream `encounter.retreat.<id>.<t>` and draw a second value | Couples the carry to the retreat success draw. Not usable for return home. Reject. |

Pick A. `run_count` is in the key so a replay does not repeat the first run's results.

### When it is drawn

After the escape succeeds (return home) or after the retreat succeeds (combat), and only when `new_gathered > 0`. A failed escape or a failed retreat draws nothing. The roll result is written to the stage record (`carry_rolls`: share, ase, ekwan) in the same save as the payment.

### Why the player cannot re-roll it

| Attempt | Why it fails |
|---|---|
| Cancel the confirmation panel | No draw happens before "Confirm". The panel shows the outcomes, not a result. |
| Save before, reload after | The key uses only saved state (`stage_id`, `run_count`, `carry_roll_count`). Same state gives the same draw. After the draw, the result is in the saved stage record. |
| Retry on the same turn | A failed escape is the same roll for the same `turn_count` (existing rule). A successful escape ends the attempt. |
| Leave again at once | `new_gathered` is 0. No draw, no new carry. |
| Draw is shifted by playing differently | The player can choose WHEN to leave, not WHAT the next result is. The result list is fixed per stage before any leave. The player cannot see it. This is the same level of control as any seeded roll. |

No new draw is added to an existing stream. Rule: path-derived only, append-only (Lesson 5).

Weights live in `data.rewards.carry_odds` as `[{share, weight}]` (PROPOSED DEFAULT shape: 0.0/50, 0.5/30, 1.0/20). Weights need not sum to 100. The code divides by the sum. A missing key logs an error and carries 0. `partial_intel_reward_factor` (0.12) becomes dead: remove it in the same step.

## 2. Scout `intel_retention_bonus` and directives

Problem: today the bonus multiplies the amount. With a roll, 1.5 times a 100% share is 150% of the gathered amount. That breaks "carry up to what you gathered" and can make the final payout hit the floor of 0.

| Option | Rule | Mean carry (Seek / Scout) | Notes |
|---|---|---|---|
| A (pick) | Scout multiplies the weights of the **non-zero** outcomes by 1.5, then the odds are renormalised. Odds Scout = 40 / 36 / 24 (computed from 50 / 45 / 30). | 35% / 42% | Reuses the key `intel_retention_bonus`. No new data. The amount never exceeds 100%. Easy to explain: "A Scout party brings more home." |
| B | Keep the amount multiplier, cap the share at 100%. Scout: 0 / 75 / 100 with the same odds 50/30/20. | 35% / 42.5% | Gives a 75% outcome the player never sees in the base table. Harder to read. |
| C | Drop the bonus. Scout keeps only the escape bonus (+20). | 35% / 35% | Simplest. The Scout directive loses one of its two stated perks. Check the directive text before choosing C. |

Pick A, then B, then C.
Other directive points:
- Seek (`intel_retention` false, mul 1.0) uses the base odds.
- The retreat passes 1.0 today. Keep that: the in-fight retreat has no directive bonus. (Option: give the Scout bonus to the retreat too. Not recommended now: one more change on a path already moving.)
- Ekwan now shares the shifted odds, because it uses the same roll. Before, Scout did not raise Ekwan. This is a small gain and it is a visible change. Jeff can reject it by rolling Ekwan separately; that costs a second draw and a second result on the card. Not recommended.
- The party stance bend of `escape_bonus` stays on the escape roll only.

## 3. What the confirmation panel can show (revised: Jeff's rule, no percent for the player)

Rule from Jeff: the player never sees a percentage or the odds. The UI never computes. Core builds `carry_home_preview`; the UI draws it.

Answer to "can odds or a range show at all?":
- **Odds: no.** "Half the time" or "3 in 10" is a percentage in other words. Under this rule it must not show, in numbers or in words.
- **A range of amounts: yes.** An amount is not a percentage. The panel may show the gathered figure and say that some, all or none of it can come home.
- **The outcome amounts: allowed**, if shown without odds. But three amounts side by side invite the player to work out the odds. Not recommended.

| Option | Shows | Honest? | Verdict |
|---|---|---|---|
| A (pick) | The gathered figure (from core) and one plain line: you may take all, some or none of it home. One line: the rest is paid when the stage is done. | Yes. It names all three outcomes and hides only the odds. | Pick. |
| B | "Up to 74 Ase" only | Half honest. It hides that "none" is the most likely result. Reject. | |
| C | Three amount rows without odds (0 / 37 / 74) | Honest, and exact. The player can guess the odds from the order. | Second choice. |

Block (PROPOSED shape): `carry_home_preview = { gathered_new, rolled_before, nothing_new: bool, ase_max, ekwan_max }`. No odds field. The UI shows `ase_max` as the gathered figure. Core does all the arithmetic.
Honesty limit: with no odds on screen the player cannot weigh the choice. The line "none" must be present so the player is not misled. Jeff's existing line stays as it is: "Escaping might be more difficult than expected. It might not be possible."

PROPOSAL copy (marked):
- Title: "Leave now?"
- Intro: "You have 74 Ase gathered here."
- Roll line: "You might take all of it home, some of it, or none."
- Under it: "Whatever you leave behind is still yours when the stage is done."
- Existing line (Jeff, unchanged): "Escaping might be more difficult than expected. It might not be possible."
- Nothing new: "Nothing new to carry. You already tried for this."
- Retreat adds: "Pulling back costs 10 Ase. You go back to the stage, not home."
- Retreat when short: keep the existing denial reason.

## 4. Resolve card (return home) and the retreat result (revised)

Rule from Jeff: no percent and no odds on the card. The card says what happened in words. Ase and Ekwan amounts may show as amounts.
ASSUMED reading: "some" is the 50% outcome. The card never says "half" because that is a fraction. It says "some".

Three outcomes plus two guard cases. Label on every row: "Carried home" (the same label as the final payout row). New cause keys (for `mechanics-developer`): `carry_none`, `carry_some`, `carry_all`, `carry_nothing_new`. The existing `nothing_overcome_yet` stays.

| Outcome | Ledger row | PROPOSAL cause text |
|---|---|---|
| Took everything | "Carried home +74 Ase" (plus an Ekwan row if above 0) | "They got everything out. The stage is still waiting." |
| Took some | "Carried home +37 Ase" | "They got some of it out. The rest is yours when the stage is done." |
| Took nothing | "Carried home +0 Ase" (a row, never a missing row) | "They got nothing out this time. It is still yours when the stage is done." |
| Nothing new | one row, delta 0 | "They already tried for this. Nothing new to carry." |
| Nothing overcome | existing row | existing text (copy pass later, D-84) |

Rules for the card:
- The ledger row never contains "%", "half", "odds" or a fraction. `params` may hold the share for tests, but the UI must not print it.
- A "took nothing" result always shows a row with a figure so it does not look like a bug.
- The card says "to the Sanctum" only on a return home. On a retreat the card says the party is back at the stage (see below).
- The cause lines are true if the stage is never finished: they promise "when the stage is done", not a return.
- Retreat display: the retreat now goes back to the stage, so no Sanctum card. Options: (A, pick) a short result card, same ledger, one button "Back to the stage"; (B) an overlay on the stage map. `ui-ux-designer` decides layout after Jeff picks.
  PROPOSAL retreat variants of the cause text: replace "out" lines with the same words; the heading is "Pulled back" and the button is "Back to the stage".
- Ekwan rows follow the same cause keys (D-72 rule 3).
- Test impact: the card tests must assert that no row text matches a percent sign or the words "half", "odds", "chance".

## 5. Retreat back to the stage: what state is kept

The retreat happens before round 1 (the fight has not started). So there is no fight damage, no turn order and no round counter to keep.

| State | Rule | Why |
|---|---|---|
| Stage record, completed objectives, revealed intel | Kept. `engage_situation` already wrote them. | D-72 rule 1; GDD 20.8 "reruns preserve what the player learned". |
| The engaged situation | Option A (pick): mark it `passed` (same as `stage.ignore_situation`). The party explores elsewhere and meets it again at Tier 4. Option B: leave it open, so the next Advance can walk straight back in. | With B the 10 Ase buys one step of delay. With A the player gets space and the stage stays completable. |
| The encounter context, fight setup | Cleared (as today). A new fight is built when the player re-engages. | Pre-combat only. Nothing to preserve. |
| Party HP | Unchanged (no fight happened). | |
| Emotion | Keep the "withdrawal" modifiers and the vow release check (already run in the retreat path). The Sanctum emotion tick stays on return home only. | The retreat is a fearful act. The cost is real and visible, which fits the pillar. |
| Turn counter (`explore_map.turn_count`) | Option A (pick): no change; a retreat is not a turn. Option B: +1 turn. | A keeps the existing escape-roll key stable. B adds pressure on pace, but it adds a new increment point and a new determinism review. |
| Escape-roll key | Unchanged, so a retreat does not give a fresh escape attempt. | |
| Re-enter the same fight at once | Not with option A (passed). With B yes. | |
| Double count of the carry | No. `carry_rolled_ase` is shared. A retreat then a return home with no new objective draws nothing and carries 0. | Section 1. |

Is the 10 Ase fair now that the retreat does not end the visit?
- Before: 10 Ase bought an exit plus a payout. Now it buys a postponed fight plus (sometimes) a carry roll. The value dropped, the price did not.
- Options: (A, pick) keep 10 for now, because D-04 says Ase must be hard to get, and the free return home is the safe exit (D-79 note). The harm of D-79 is smaller now: a poor player in a bad fight can still use the free return home. (B) Lower the price. (C) Refund on success when `new_gathered` is 0. Both B and C are tuning choices for after a play test. Jeff can reopen follow-up 23.
- Numbers (Seek odds, realm 1, first run): carry EV after 1 combat (G=20) is 7 Ase, less than the price 10. After 2 objectives (G=44) it is 15.4. After 3 (G=74) it is 25.9. On a replay (x0.35) the EV is 2.5 / 5.4 / 9.0, always below the price. So the retreat is not a money move. It is a "not this fight, not yet" move. That matches the intent.

## 6. Balance check

Assumptions: realm scale 1.0, first run, Seek odds. Echo price 60 (summon), retreat 10, stipend up to 10 (cap), `objective_weights` combat 20, recover 24, shrine 30. Stage example: 3 objectives, G = 74, clear payout = 74 + 10 stipend = 84.

| Case | Expected Ase |
|---|---|
| Clear the stage | 84, plus rank and Thread |
| Leave after all 3 objectives, never return | 25.9 (Scout 31.1) |
| Leave after 2 (G=44), never return | 15.4 |
| Leave after 1 (G=20), never return | 7.0 |
| Leave, return, clear | 84 (same as clearing; the carry was an advance) |
| Defeat after a carry | The carry stays. Nothing else is paid. |

Is early leave still worse than finishing? **Yes, in expected Ase, as long as the player can finish.** The advance rule makes leave-and-return equal to finish in total. Leaving for good pays at most 35% of the gathered part (Scout 42%), and gives up the stipend, the Thread and the rank. Finishing is worth less only when the chance to win the rest is below about 18% (35% of an average half-finished stage). A rational player almost always finishes. This is the correct pressure for "keep Echoes alive and let them grow": a careful return home costs time, not a large sum.

Exploit check:

| Exploit | Result |
|---|---|
| Leave, re-enter, leave again, to re-roll | Blocked. Each gathered unit rolls once (section 1). Expected total carry stays at 35% of G. |
| Retreat spam to roll | Blocked by the same stamp. Each retreat costs 10 Ase and draws nothing when nothing is new. |
| Bank before a hard fight (leave after each objective, continue, then lose) | Allowed by D-72 rule 1. The carry stays after a defeat, so a lucky 100% hedges a defeat. Maximum hedge: 100% of G; expected 35%. Cost per cycle: the escape roll (about 58% on Seek, 79% on Scout from threshold 40 and 20), failed-escape turns, the Sanctum emotion tick and the walk back in. I judge this acceptable but I have not measured it. Needs a probe (see OPEN). |
| Never finish stages, only farm easy objectives | At most 35% of the gathered part per stage, and objectives pay less on replay (x0.35). Compared with a clear it is a bad rate. |
| Retreat as a free heal | No heal exists in the retreat path. Not an exploit. Ask `mechanics-developer` to confirm (see OPEN). |
| Carry larger than final payout | The advance is `min(carried, gross)`. The final payout cannot go negative. Share never exceeds 100% of G (no 150%), so carry cannot exceed G. |

Tension to tell Jeff plainly: because the carry is an advance, a 0% roll does not take money from the player. The game's difficulty comes from time and risk, not from the roll. If Jeff wants the 0% roll to feel like a real loss, the advance rule would have to change (for example, an unfinished stage pays only the carried part). That is a larger rule change, outside this design.

## 7. GDD contradictions

| GDD item | Result |
|---|---|
| 20.8 "an unresolved stage keeps its locked instance; reruns preserve what the player learned" | No conflict. The retreat to the stage matches it. |
| 20.10 "retreat from the stage map with intel", "no-battle return with useful information" | No conflict. Intel is not rolled; only Ase and Ekwan are. A 0% roll still returns intel. Note: the GDD names the "minimum useful failed run" as intel, objective requirements and locations. It does not name Ase. |
| 20.10 "combat retreat can remain unavailable or much more limited early on" | D-104 turns the retreat into a step back, not an exit. This is a change in meaning. Suggest Jeff adds one line to 20.10: "A successful combat retreat returns the party to the stage map." I did not edit the GDD. |
| "Death, withdrawal, loss: map-level withdrawal remains an early safety valve" | Holds. The free return home still exists. |
| Pillar: Echoes have fear and interiority | Holds if the withdrawal emotion modifiers stay on the retreat (section 5). |
| `ANSWERS.md` recruit roll: "no re-roll" | The carry design follows it. |
| D-25 (no mid-stage preview) and D-65 (running tally) | The confirmation panel shows gathered Ase at the moment of leaving. This is a small mid-stage figure. Jeff should confirm that it does not reverse D-25. D-102 already allowed `carry_home_preview` before the action. |

Doc defects found (not fixed): the comments on `StageSettlementService.carry_plan` and `VentureController.handle_return_home` talk about "12%". They become stale when this builds. The build step must update them and `partial_intel_reward_factor`.

## Recommended build order (for Jeff to scope; not scope here)

1. Config: `data.rewards.carry_odds`; remove `partial_intel_reward_factor`.
2. Core: `carry_rolled_ase`, `carry_roll_count`, `carry_rolls` on the stage record (additive); the roll in `carry_plan`/`carry_home`; the Scout weight shift; retreat returns to the stage (with the `passed` mark).
3. Preview block and cause keys in the snapshots.
4. UI: confirmation panel and Resolve card.
5. One ux-copy pass (D-84) for all lines above.
6. Long run and attribution (RNG and fingerprint effect: new stream only, so existing fingerprints should hold; expect moved values only where the 12% fixed carry was recorded).

## OPEN — questions and assumptions

ASSUMED: The carry roll applies only to the gathered amount not rolled before (`carry_rolled_ase` stamp). | WHY: without it, D-72's "minus carried" rule lets repeated leaves ratchet up to 100%. | WRONG IF: Jeff wants a repeat leave to re-roll the same Ase (then the roll needs a price, or a cap, or the ratchet is accepted).
ASSUMED: One roll covers Ase and Ekwan with the same share. | WHY: D-72 rule 3 says Ekwan follows Ase; one card line. | WRONG IF: Jeff wants Ekwan rolled apart.
ASSUMED: Scout raises the Ekwan odds too, through the shared roll (option A, section 2). | WHY: no way to shift the odds for Ase only with one roll. | WRONG IF: Jeff wants Scout to keep helping Ase only.
ASSUMED: The retreat keeps `retention_mul` 1.0 (no directive bonus). | WHY: it is 1.0 today. | WRONG IF: Jeff wants the Scout perk on the retreat.
ASSUMED: Re-engaging a retreated situation rebuilds the same fight (same seed), not a new one. | WHY: encounter setup is seeded by the situation; I did not read `EncounterSetupService`. | WRONG IF: a new fight is generated on each engage (then retreat would re-roll the enemy, which is an exploit).
ASSUMED: The retreat path has no heal and no rest. | WHY: I found none in the code I read. | WRONG IF: a heal or morale recovery happens on return to the stage map.
ASSUMED: `run_count` is readable at the leave and `stage_id` repeats across replays. | WHY: the escape key uses `stage_id` and `turn_count` only. | WRONG IF: the stage record is rebuilt on replay with fresh carry fields (then `run_count` in the key is optional, and the reset must be tested).
BLOCKED: Does the existing retreat success roll (`encounter.retreat.<id>.<t>`) give the same result after a save and reload? | CHECKED: `FlowRuntime.gd:1182-1187`; the key uses tick `t`; I did not trace whether `t` is saved. | NEED: `mechanics-developer` to confirm. If `t` changes after a reload, the retreat success is re-rollable by save and reload (an existing issue, not new).
BLOCKED: Which retreat result display does Jeff want: Resolve card with "Back to the stage" (pick) or a map overlay? | CHECKED: D-104 states only "returns to the stage map". | NEED: Jeff's pick, then `ui-ux-designer`.
BLOCKED: Is a retreat a turn (turn counter +1)? | CHECKED: `turn_count` increments only in `advance_turn`. | NEED: Jeff's pick; I recommend no.
BLOCKED: Measured size of the bank-before-a-hard-fight hedge. | CHECKED: arithmetic only, from `balance.json`. | NEED: a probe of leave cycles on a real stage (RUN REQUEST by the builder; the main chat runs it).
BLOCKED: Does the Scout directive text promise a number (the "intel retention" con/pro lines)? | CHECKED: `balance.json:20-40` shows the keys and the cons list, not a retention line. | NEED: `mid-game-designer` to check the directive card text before option A or C.
BLOCKED: Do the displayed odds (whole tenths) and the drawn odds (exact weights) match for Scout 40/36/24? | CHECKED: arithmetic only. | NEED: Jeff or `mid-game-designer` to choose Scout weights that give whole tenths (for example a bonus that yields 40/40/20), or accept rounded display.

ASSUMED: "Some" in Jeff's rule means the 50% outcome. The card says "some", never "half". | WHY: Jeff named three outcomes: nothing, some, everything. | WRONG IF: Jeff means a different share, or wants the odds table to change.
ASSUMED: The rule "no percentage for the player" also bars odds in words ("half the time") on the confirmation panel, not only on the Resolve card. | WHY: the coordinator message says the percentage is not for the player to see. | WRONG IF: Jeff allows odds in words on the panel (then the first draft of section 3, three rows with odds in tenths, comes back as an option).
