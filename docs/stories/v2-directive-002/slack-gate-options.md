# Slack gate options (V2-DIRECTIVE-002 B+C, slice S1b)

Author: `sr-game-designer`. Date: 2026-10-12. Status: advice for Jeff. Jeff decides.
No game wording. No new numbers. Every number below is an existing value or a measured count.

## 1. The question

The stage party plans its route again at every step. The slack gate decides if a priced route (a route that goes round a hostile) is allowed.

| Item | Today (code read) |
|---|---|
| Gate | `StageExposureMap.detour_within_slack(priced_len, plain_len, slack_cfg)` is true when `priced_len <= plain_len + envelope(plain_len)`. |
| Envelope | `StagePartyMovementAdapter._slack_envelope`: `max(2, ceil(0.25 * plain_len))`. Config may only narrow it. |
| `plain_len` | Cells of the plain route from the party cell to the target, measured at every step (`StageExploreTurnService.gd`, step loop, S1b block). |
| Gate fails | The loop drops the priced route and walks the plain route. The plain route can cross the hostile cell. |
| Price | Cost of entering a cell is `1 + round(exposure * (1 - tolerance) * price_scale)`. Radius 2, peak 1.0, scale 4. Scout tolerance 0.3. Seek tolerance 0.8. |
| Advance length | Scout 3 steps (`step_budget`). Seek 6 steps. |

Problem in one line: the detour is about equal in length from step to step, but the limit shrinks as the party walks. A detour that fits at step 1 can fail later.

Options asked for:
- **A**: the limit uses the plain length at the start of the Advance. Fixed for that Advance.
- **B**: keep the limit per step (today).
- **C1** (my addition): the limit uses the plain length when the destination was chosen (the leg start). Fixed until the destination changes.
- **C2** (my addition): a price ladder. Try the full price. If the route is too long, try a lower price. The last rung is the plain route.
- **C3** (named in the brief): A, capped by the remaining plain length. Covered in section 8.

## 2. How I measured (read this first)

The brief says do not run Godot. I did not. I re-wrote the route search and the gate in a throw-away Python script (scratchpad, not in the repo). It reads `mockups/review/real-stage-maps.json`.

What the script copies from the code: 8-way moves with the corner rule of `StageTerrain.is_legal_edge`; lowest cost, then line deviation, as tie-break in `MovementPathService.shortest_path`; the price formula; the envelope; step budgets 3 and 6.

What the script does NOT copy (so treat counts as an estimate):
- Final tie-break order between equal routes (`_relative_progress_less`, `_cell_less`).
- Fog. The hostile is known from the first step.
- The target does not change during a walk.
- One hostile only. No stops except contact with the hostile cell, which ends the Advance.
- The party bend (S2b). Tolerance is the Directive value.

A probe in the real engine must confirm the counts before any value is authored. Section 10 describes it.

## 3. Finding that changes the question

**The real hostile positions never trigger the gate.** I took each real combat situation on all four real maps and tried thousands of start and target pairs, both Directives. The priced route was never longer than the envelope. On open ground the detour costs 0 to 3 extra cells and the envelope is 2 or more. The gate cannot fail there.

**The gate only fails in narrow places.** To show it, I moved one hostile onto a real map, onto a corridor cell. That is the worked example (section 4). I call it a placed hostile. The map and the target are real.

**Sample on map 2 (stage 3, realm 2, 59x59), Scout, hostile placed on the plain route at 7, 10 or 13 cells from the start.** 395 journeys, each walked to the target or to contact.

| Result (Scout, option B, today) | Count |
|---|---|
| Journeys | 395 |
| Party reached the hostile cell | 40 (10%) |
| Of those 40: the detour never fitted, so the plain route was taken from step 1 | 38 |
| Of those 40: the detour fitted first, then failed later (a true flip) | 2 |
| Option A gave a different journey than option B | 0 |
| Option C1 gave a different journey than option B | 2 (the two flips) |
| Journeys that ran in a loop | 0 |

Meaning:
1. The flip-flop is real but rare (2 in 395). The common failure is different: the detour was too long from the start (38 in 395). That is a cliff, not a flip.
2. Option A fixes nothing in this sample. A flip happens between two Advances in the example, not inside one. A only freezes the limit inside one Advance.
3. Only C1 fixes the flip, and only 2 journeys.

## 4. Worked example (one map, one hostile)

Map: `stage.3`, realm 2 (`realm.02:3`), 59x59. Real cells from `real-stage-maps.json`.
- Start cell S = (25, 43). Target T = (42, 27). T is the real `recover` objective of this map.
- Hostile H = (30, 32). Placed on the plain route (the real combat on this map is at (41, 52) and never triggers the gate).
- The hostile is already known (revealed) at the start. Assumption.
- Plain route: 23 cells. It runs north along column 26, then through H, then east to T.
- Scout price at H: cost 4. Ring 1 (Chebyshev distance 1): cost 3. Ring 2: cost 2. Scout tolerance 0.3.
- Seek price at H: cost 2. Ring 1: cost 2. Ring 2: cost 1 (not priced). Seek tolerance 0.8.
- Scout priced route: 29 cells. It goes round by the north: 6 extra cells.
- Seek priced route: the same 23 cells as the plain route. Seek's price is too low to justify 6 extra cells.

Sketch (columns 20 to 45, rows 24 to 45). Key: `#` ground, `=` bridge, `x` and `y` priced ring, `S` start, `T` target, `H` hostile, `B` cell on both routes, `p` plain route only, `r` Scout priced route only.

```
   01234567890123456789012345      col 20..45
24 ........................==
25 .........############...==
26 ........##rrrrrrrrr=####=#
27 ........#r.........r##T###
28 ........#r.........=rB####
29 ........#r.........=p#####
30 ........xr.........p#####.
31 ........ryyyy=====p=######
32 ....##.rxxHppppppp===.....
33 ....###rxp................
34 ....###rxp................
35 ....####rp................
36 ....####B.................
37 .....=#B##................
38 .....=B...................
39 .....=B...................
40 .....=B...................
41 .....=B...................
42 .....=B...................
43 .....S=...................
44 .....==...................
45 .....==...................
```

The two routes share their first 5 cells (up the column 26 corridor). They split at (27, 37). So the first Advance looks the same under every option.

### 4.1 Option B (per step, today), Scout

| Step | Party cell | Plain length | Priced length | Limit = plain + envelope | Fits? | Route used |
|---|---|---|---|---|---|---|
| 1 | (25,43) | 23 | 29 | 23 + 6 = 29 | yes | priced |
| 2 | (26,42) | 22 | 28 | 22 + 6 = 28 | yes | priced |
| 3 | (26,41) | 21 | 27 | 21 + 6 = 27 | yes | priced |
| 4 | (26,40) | 20 | 26 | 20 + 5 = 25 | **no** | plain |
| 5 | (26,39) | 19 | 25 | 19 + 5 = 24 | no | plain |
| 6 | (26,38) | 18 | 24 | 18 + 5 = 23 | no | plain |
| 7 | (27,37) | 17 | 23 | 17 + 5 = 22 | no | plain |

The extra length stays 6. The envelope drops from 6 to 5 when the plain length drops from 21 to 20. The detour is refused for good.

Walk: Advance 1 cells (26,42) (26,41) (26,40). Advance 2: (26,39) (26,38) (27,37). Advance 3: (28,36) (29,35) (29,34). Advance 4: (29,33), then H (30,32) at step 2 of 3. Contact. One step is lost. The party made 11 steps in 4 Advances.

The flip is visible to the player at Advance 3, when the drawn path turns toward the hostile instead of north. At Advance 1 and 2 the drawn path is the same under every option.

### 4.2 Option A (fixed for the Advance), Scout

Rule used: allowance = `envelope(plain length at Advance start)`, compared with the current plain length: `priced_len <= plain_now + allowance`.

| Advance | Start plain | Allowance | Steps and result |
|---|---|---|---|
| 1 | 23 | 6 | Steps 1, 2, 3: priced (limits 29, 28, 27 hold). |
| 2 | 20 | 5 | Steps 4, 5, 6: priced length 26, 25, 24 against limits 25, 24, 23. Refused. Plain. |
| 3 | 17 | 5 | Refused. Plain. |
| 4 | 14 | 4 | Plain route. Contact at H at step 2. |

Same 11 cells and the same contact as option B. The Advance boundary falls exactly where the envelope drops (plain 23, then 20). A only helps when a boundary falls between two plain lengths that cross an envelope step (for example Advance start at plain 21: allowance 6 for all three steps instead of 6, 5, 5). Then the party gains at most 2 steps of detour, and the next Advance refuses it anyway.

Do not build A as `priced_len <= plain_at_start + envelope`. That version adds the cells already walked to the limit. The limit grows with every step and long detours pass. This is a bug risk, not an option.

### 4.3 Option C1 (fixed for the leg), Scout

Rule: allowance = `envelope(plain length when the destination was chosen)` = 6 for this leg. It does not shrink while the destination stays the same.

| Advance | Start plain | Result |
|---|---|---|
| 1 to 5 | 23, 20, 17, 15, 14 | Priced route every step. The party goes up column 26, round by the north rim of the room. |
| 6 to 10 | 14, 11, 8, 5, 2 | Priced equals plain after the room (no exposed cell left). Plain steps. |

Walk: 29 cells, 10 Advances. Arrives at T. No contact with H. The remaining plain distance does not always fall. It reads 15, 15, 15, 15, 14, 13, 14, 14, 13 along the north rim (at most +1 for one step). This is the "walks away from the objective" case. It is small here.

### 4.4 Option C2 (price ladder), Scout

Rule: if the full-price route is too long, try a lower price, and the plain route last.

Result in this corridor: same as B. The lower price does not make the 6-cell detour worth it, so the route is the straight one. 11 cells, contact, 4 Advances. The ladder fixes nothing in a corridor. It helps only where a lower price gives a shorter route that still skirts the hostile (a wide room).

### 4.5 Seek, all options

Seek priced route equals the plain route. All options give the same walk: 6 steps, then 5 steps, then contact at H on step 5 of Advance 2 (one step lost). 11 cells, 2 Advances.

## 5. What the player sees (per option)

| Item | A | B | C1 | C2 |
|---|---|---|---|---|
| Route drawn, Scout, Advance 1 | Goes up the corridor (same as all). | Same. | Same. | Same. |
| Route drawn, Scout, Advance 3 | Turns toward the hostile (same as B). | Turns toward the hostile. | Keeps going round by the north. | Turns toward the hostile. |
| Stop | Contact at H (Met something). | Contact at H. | None on the route. Arrives (Arrived). | Contact at H. |
| Why line (cause) | Needs a cause class when the detour is refused. | Same. | Same, only on a refusal. | Same. |

The journey entry must not say the Directive caused the direct road when the gate refused the detour. That is a false reason (design 7d, N7). A refused detour is a terrain cause: "the way round was too long" (design 7d, N1 gives the class). This is true for A, B and C2 whenever a Scout party walks into a hostile. It is my recommendation to record it, whichever option Jeff picks. Without the record, the player sees a cautious Directive walk into a fight with no reason shown.

Safety net, not yet built: design 3a says Scout may pause when "the next cell is highly exposed" (`paused_to_read`). The pause trigger is slice S3. Once S3 lands, a refused detour still ends in a pause before the exposed cell, not in a surprise. Until S3 lands, a refusal ends in contact.

## 6. Scout and Seek contrast (D-08)

| Option | Scout vs Seek on the worked example | Verdict |
|---|---|---|
| A | Scout and Seek walk the same 11 cells and meet the hostile. No contrast. | Contrast lost on this board. |
| B | Same as A. | Contrast lost on this board. |
| C1 | Scout goes round (29 cells, 10 Advances, no fight). Seek goes straight (11 cells, 2 Advances, fight). Strong contrast. | Directive contrast shows. |
| C2 | Same as B in a corridor. | Contrast lost in a corridor. |

Seek's tolerance makes its price low. The gate almost never decides a Seek route. In the sample, Seek's priced route differed from the plain route in 75 of 395 journeys, and A and C1 changed none of them. The gate is mostly a Scout rule. Judge each option by what it does to Scout.

## 7. Failure modes

| Mode | A | B | C1 | C2 |
|---|---|---|---|---|
| Exploit: player sets Scout to dodge every hostile | No. Same as B. | No. | Mild. A detour stays for the whole leg, so Scout dodges more reliably in corridors. The cap is still `envelope(leg plain)`, so no wall. | No. |
| Soft-lock | None. The plain route is always the last choice. | None. | None. Detour length is bounded by the envelope of the leg length. | None. |
| Long loops | None seen. | None seen (0 in 395). | None seen. The bound is fixed, so the party cannot go round and round. | None. |
| Walks away from the objective | No. | No (it flips back to straight). | Small. Plain distance rises by 1 for about 1 step on a rim. | No. |
| Walks into the hostile although Scout | Yes (38 + 2 of 395). | Yes (same 40). | 38 of 395. Only true flips are fixed. | Yes (same 40). |
| Limit grows with progress (bug) | Yes, if built on `plain_at_start + envelope`. | No. | No. | No. |
| Limit wider than the option contract | The Advance limit can exceed `envelope(plain_now)`. | No. | Yes, by up to a few cells late in a leg. The contract (`MovementOption.gd:146`) is for combat options. Stage uses its own gate. The stage test `exposure_never_a_wall` must be re-stated. | No. |
| Stale state | None. | None. | The leg value must reset when the destination changes, on retarget, on reload, and on a new stage. A stale value would hold a detour too long or too short. | None. |

## 8. Step count, stop frequency and recorded values

### 8.1 Advance step count

| Option | Effect |
|---|---|
| A | None measured. Same Advances as B. |
| B | Baseline. Worked example: 4 Advances to contact (11 steps). |
| C1 | A detour adds its extra cells. Worked example: 29 cells and 10 Advances to the target, against 23 cells and 8 Advances for the plain route to a target with no hostile. That is 6 extra cells, 2 more Scout Advances (3 steps each). Across the sample: extra cells per journey that reached the target are 243/355 = 0.68 (B) and 255/357 = 0.71 (C1). The mean cost is small. |
| C2 | None measured. |

### 8.2 Stop frequency (D-45 probe numbers)

D-45 measured pauses per Advance on shipped boards, authored baselines, no party bends, every situation ignored: Scout mean 0.12 to 0.19, Seek mean 0.04 to 0.06. A pause ends the Advance (D-46). Steps cut by pause: Scout about 0.17 per Advance.

The D-45 probe did not include contact with a hostile, because the probe ignored every situation. So D-45 does not measure the effect of this gate. Contact stops are a different count ("Met something"). I have no shipped-board count for them.

What I can say:
- A contact ends the Advance and loses the unspent steps, like a pause. Fewer contacts means fewer lost steps.
- B and A leave about 10% of hostile-on-route journeys (sample, Scout) ending in contact. C1 leaves 38 of the 40 cases.
- No option changes the pause probe numbers directly. The pause trigger `paused_to_read` for an exposed next cell (S3) may add pauses in the refused-detour cases. That count belongs in the post-backend re-measure (backend plan R10).

### 8.3 Risk to recorded values

| Option | Risk |
|---|---|
| A | Low. S1b reported no moved value. The sample shows 0 differences from B. The test `exposure_never_a_wall` ("priced route never longer than the envelope") must change its words and its check to the Advance rule. |
| B | None. It is built and no recorded value moved (S1b status). |
| C1 | Medium. It adds one saved number per leg (the plain length at leg start). That is a save-schema change. The journey entry and the stop already need an `opus` save-schema pass (design 8a). Both changes can share that pass. Old save: a missing value means "use the current plain length", which is option B. Route cells move only on boards where a flip happens. |
| C2 | Low to medium. It changes every route that today falls back to the plain route, so more cells move on boards with a refused detour. It adds a ladder to config. A ladder needs numbers (rungs). That conflicts with "no new numbers" in this note. |

### 8.4 Option C3 (A capped by the remaining plain length)

The envelope is `max(2, ceil(0.25 * n))`. It is only larger than the remaining plain length when that length is 1 or 2. So the cap bites only in the last two cells of a leg. It is a safe guard, not a fix. It changes no journey in the sample. I do not list it as a separate option for the decision.

## 9. Recommendation

Keep option B for slice S1b: it is built, it moves no recorded value, and the true flip is rare (2 in 395 sampled journeys, 0 on any real hostile position). Do not build option A. It fixes none of the sampled cases and it adds a bug risk (a limit that grows with progress), because the flip falls between two Advances and A freezes the limit inside one Advance only. The better fix is C1 (the limit fixed for the leg). It is the only option that makes Scout go round the hostile and keeps the Scout and Seek contrast of D-08. But it needs one saved number, so build it with the journey-entry save change (design 8a), under the same `opus` save-schema pass, not in S1b. The larger risk is not the flip. It is the cliff: in 38 of the 40 bad journeys the detour never fitted and Scout walked into the hostile from the first step. Neither A nor C1 changes that. Jeff should decide a separate question: when the detour is refused, does Scout stop before the exposed cell (the S3 pause) and does the journey entry give a terrain cause. I recommend yes to both. Until S3 lands, add the terrain cause to the journey entry so the player never reads a false reason. Re-measure the counts in the real engine before any value is authored.

## 10. Probe to confirm the counts (for the main chat to run)

A `game-feel-developer` or `mechanics-developer` builds this probe. The main chat runs it. It must run in the real engine, not in my Python copy.

1. For each of the four real maps, load the stage as `mockups/review/real-stage-maps.json` was made.
2. For each real combat position and for 10 placed positions on plain routes (7, 10, 13 cells from the start), run full walks to the target under B, A and C1, for both Directives.
3. Count per option: reached the hostile, detour never fitted, true flip, extra cells, Advances.
4. Compare with this note: 395 journeys, 40, 38, 2, 0.68 and 0.71.
5. Restore any edited file. State the restore step in the script.

## 11. Not covered here

- The party bend of tolerance (S2b). A bend of up to 0.12 changes the price and so the count of refused detours. Re-measure after S2b.
- Several hostiles at once, hazards and bridge exposure (story "Stage hazards and exposure", D-31). Narrow crossings with exposure would raise the refusal count a lot.
- The player wording of the cause. Jeff owns it.
- The exact leg-value field name and place in the save. `mechanics-developer` decides.

## OPEN — questions and assumptions

ASSUMED: The numbers in sections 3, 4 and 8 come from a Python copy of the route search and the gate, not from the engine. | WHY: The brief forbids running Godot. The code gives exact cost rules and the envelope. | WRONG IF: The engine tie-break between equal-cost routes differs from my copy, or fog, retargeting or stops change the walks. Counts may move. Run the probe in section 10.

ASSUMED: The hostile is known from the first step, there is one hostile, and the target does not change. | WHY: This isolates the gate. | WRONG IF: A real board reveals the hostile late or retargets mid-leg. Then the flip count can be higher or lower.

ASSUMED: Option A means "allowance from the Advance-start plain length, compared with the current plain length". | WHY: The other reading (priced length against start plain length plus envelope) lets the limit grow with each step. | WRONG IF: Jeff meant the looser reading. It would let longer detours pass.

ASSUMED: The worked-example hostile at (30,32) is a placed hostile on a real map. | WHY: The real hostile positions on all four maps never fail the gate, so no real position shows a flip. | WRONG IF: Jeff wants only real positions. Then there is no example, and that is itself the finding.

BLOCKED: The brief names a "replan flip-flop" finding in `backend-plan.md` (slice S1b status and findings). | CHECKED: `docs/stories/v2-directive-002/backend-plan.md` (S1b section at line 145, findings table, grep for "replan", "re-plan", "flip"), `decisions.md`, `design.md`, `numbers.md`. No such finding is written. The S1b status line says only "BUILT 2026-10-12, not committed, not verified". | NEED: The main chat or `mechanics-developer` points to the finding text, or confirms that the finding was only said in chat. I reconstructed the problem from the code.

BLOCKED: Where does option C1 keep the leg-start plain length, and can it join the journey-entry save change? | CHECKED: `design.md` 8a, `StageExploreTurnService.gd` (`last_traveled_origin` is saved; no leg-start value exists). | NEED: `mechanics-developer` states the place and the reset rules (retarget, reload, new stage). Then an `opus` save-schema pass.

BLOCKED: Should a refused detour be recorded in the journey entry as a terrain cause, and should Scout pause before the exposed cell (S3)? | CHECKED: `design.md` 3a, 5 (section 7d N1, N7). | NEED: Jeff's decision.
