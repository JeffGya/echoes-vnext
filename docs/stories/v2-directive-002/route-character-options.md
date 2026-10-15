# V2-DIRECTIVE-002 B+C: frontier `route_character` rank key — options for Jeff

Author: `sr-game-designer`. Date: 2026-10-12. Status: advice only. Jeff decides.
No player wording here (marked [Jeff's wording]). Every number is PROPOSED DEFAULT, for `mid-game-designer` to author.
Nothing was built or run in the engine. The map worked example uses a Python copy of the route search (an approximation; see D-48 about its limits).

## 0. The open item in one paragraph

`backend-plan.md` S2c says `select_frontier` gets an optional `route_character` argument. It adds one rank key after heading continuation and before the salted hash. "Scout prefers cells that keep the road home explored. Seek prefers continuing the heading." The plan gives no weights and no config keys, so the key was not built. S2c's bend half is done.

## 1. Facts from the code (checked)

| Fact | Source |
|---|---|
| Today the frontier rank is: (1) BFS distance, (2) heading continuation, (3) chebyshev, (4) salted FNV-1a hash of the cell key, (5) cell key string. | `StagePartyMovementAdapter.select_frontier`, rank array |
| The candidates are ALL unexplored walkable cells. Distance is first. So the party always walks toward the nearest fog cell. | `ActiveStageService.find_explore_target`, Tier 3 |
| A new key placed after key 2 only orders cells that tie on distance AND on heading. | the rank order above |
| Heading is the displacement of the last Advance (`last_traveled_origin` to `party_pos`). It is the same code for both Directives. It is empty on Advance 1. | `ActiveStageService.stage_party_heading` |
| So "Seek prefers continuing the heading" is ALREADY true, for Scout too. Seek needs no new code for it. | same |
| Tier 3 runs only when the weighted pool has no candidate. A revealed, unresolved hostile is a pool candidate (D-49). So at Tier 3 the exposure map is empty in practice. | design 3.1, D-28, D-49 |
| The entry cell can be recomputed from the walkable set and bounds. No new saved field is needed for "distance to start". | `StageTerrain.entry_cell` (used in `TraversalModelTests.gd`); `mechanics-developer` confirms |
| One scalar key cannot be "bent" by a weight. A positive weight times every candidate keeps the same order. A party lean can only change the SIGN (prefer, neutral, avoid) or the mix of two terms. | arithmetic |

## 2. Question 1: is the key needed for the design goals?

### 2.1 What the goals need

Design section 1: the same Directive must walk differently per Echo profile, and Scout must read differently from Seek, on the stage map. The player must see it on the route, the stop or the depth.

### 2.2 What S2b and S2c already deliver without the key

| Lever | Built | Does it act on a frontier-only walk (no revealed situation)? |
|---|---|---|
| Commitment depth (E6) | S2b | YES. This is the main lever there. D-50: Scout steps per Advance 2.78 to 1.88, cells revealed per Advance 11.28 to 7.73, Advances to the objective 11.5 to 16.8. Seek 4.61 to 4.20 steps, 12.2 to 17.8 Advances. Per step, Scout reveals about 4.1 cells and Seek about 2.4. |
| Effective steps and readiness (fear, morale bands) | S2b | YES. Same walk, fewer or more steps. |
| Exposure tolerance and the E2 route price | S2b / S1b | NO. The exposure map is empty at Tier 3 (section 1). Test N6 says the empty map changes nothing. It acts only when a hostile is revealed. |
| Category-weight bend | S2c (done) | NO. It acts in the pool only, and only on ties (D-44). |
| Stops (`paused_to_read`, `spotted_ahead`) | S2b / S3 | NO. A stop needs a new find. D-45: Scout mean 0.12 to 0.19 pauses per Advance, Seek 0.04 to 0.06. Most Advances have no stop. |

Result: on an open-fog stretch, two profiles differ in how FAR the party walks per Advance and how much fog it clears per step. They do not differ in WHICH fog cell they walk toward. The first-key distance rule fixes the target to the nearest fog ring. Inside the ring, the choice is the heading, then the hash.

### 2.3 Is the key worth that gap?

| Check | Answer |
|---|---|
| Needed for "same Directive, different Echo, different behaviour"? | NO. Commitment depth, tolerance, stops and the pool bend already give contrast. D-08 contrast cases S1 to S4, K1 to K4, P1, P2 are built on routes, stops, depth and ties in the pool. None needs a frontier cell choice. |
| Needed for "Scout vs Seek read differently"? | NO for the contrast itself: depth and fog per step already differ (D-50). It would add a second, smaller difference: which fog cell. |
| What the key can change | Only the pick among cells that tie on distance and heading. Worked example (section 3): 10 tied cells at Advance 1 on Vale of Dust stage 0. A snug rule narrows them to 7 and does not finish the choice. |
| Is it legible without a number? | Weakly. A one-cell change in the target is not visible. The party walks 2 to 5 steps toward a ring cell and re-plans after each step. The player sees a slightly different line, not a clear style. |
| Does it survive a player who never reads it? | Yes. It is invisible. |
| Does it produce a decision? | No. It changes a default tie, not a choice the player makes. |

Finding: the key is NOT needed to meet the design goals. It is a small flavour layer. It can be built later without breaking anything, because the argument is optional and trailing.

One related gap the key does not close: design section 8 and `travel_why` hold a `route_character` field. If the key is deferred, that field must come from the E2 exposure price only (a lower-exposure route chosen), or stay empty on a frontier walk. [Jeff's wording] for any text shown for it.

## 3. Question 2: concrete definitions (if built)

### Worked example (one map, one ASCII sketch)

Map: `mockups/review/real-stage-maps.json`, map 1, Vale of Dust stage 0 (`realm.01:0`). Start cell (8,13). Revealed at turn 0: 20 cells. Objective at (12,13), hidden. Python copy of the 8-way route search.

Advance 1, party at start (8,13), no heading. Minimum BFS distance to fog is 4. There are 10 tied fog cells. Sketch (col right, row down; `.` explored, `#` fog ground, `T` the 10 tied cells, `S` party). Only cols 8 to 12 and rows 9 to 15 shown.

```
col:   8 9 10 11 12
row 9  # T T  T  T
row 10 . . .  .  T
row 11 . . .  .  T
row 12 . . .  .  T
row 13 S . .  .  T
row 14 # . .  .  T
row 15 # . #  .  T
```
(The sketch is schematic: the true fog ring is the column at col 12 plus the row at row 9. Cells (9,9) and (10,9) are fog cells above explored ones. (11,9) and (12,9) too.)

Today: the heading is empty, so the salted hash picks one of 10 cells. Same stage, same pick, every run.

Advance 2, party at (10,11) after the first Advance, heading (+2,-2). Minimum distance 4, 7 tied cells, all in column 14. Heading continuation scores (14,9) and (14,10) as 2, (14,11) as 1, others 0. So the heading already cuts 7 cells to 2. Any new key chooses only between (14,9) and (14,10).

### Definition A: "snug edge" (prefer cells with more explored neighbours)

| Item | Rule |
|---|---|
| Meaning | Scout picks the fog cell whose 8 neighbours are most explored. The party clears the fog edge tidily and does not poke into open dark. Seek is the reverse (fewest explored neighbours: reaches out). "Keeps the road home explored" reads as "does not leave unexplored gaps behind". |
| Key position | After heading, before the hash. Integer key: `-sign * explored_neighbour_count`, where `sign` is +1 (Scout), -1 (Seek), 0 (neutral). |
| Map result | Advance 1: neighbour counts are 3 for (9,9), (10,9), (12,11), (12,12), (12,13), (12,14); 2 for (11,9), (12,10), (12,15); 1 for (12,9). Scout narrows 10 to 6 and the hash still decides. Seek goes to (12,9) alone. Advance 2: Scout picks (14,10) (3 vs 2). Seek picks (14,9). |
| What the player sees | Almost nothing. A different cell in a 4-cell-wide fog edge. The Seek line is a little more outward, the Scout line a little tidier. |
| Failure modes | Ties: still ties inside the same count, so the hash stays needed (it stays last). Ping-pong: the first two keys (distance, heading) bound it; the key only breaks ties; no loop is possible because each Advance lifts fog and a cell, once explored, leaves the candidate list. Soft-lock: none, because no candidate is removed. Seek "fewest neighbours" can pick an isolated corner cell: still the nearest ring, so cost is a few steps. |
| Party bend | Only the sign can change, so use 3 states. PROPOSED DEFAULT: Directive sign Scout +1, Seek -1. A party lean can move the sign toward 0 and never past it (so a party can soften, never invert; same rule as section 3 of the design). |
| Determinism | Integer function of the explored set and the walkable set. No RNG. The salted hash stays last. |
| Recorded values | Section 5. |
| Config keys | `stages.party_stance.route_character.mode` (one of `snug`), `stages.party_stance.directive_profile.<id>.frontier_snug_sign` (-1, 0, 1), `stages.party_stance.bounds.frontier_snug_sign` (0 to 1 magnitude of party shift), `stages.party_stance.leans.frontier_snug.<family>`. |

### Definition B: "short road home" (prefer cells closer to the entry cell)

| Item | Rule |
|---|---|
| Meaning | Scout picks the fog cell with the smallest BFS distance from the stage entry cell. It sweeps the ground near the road home first. Seek is neutral on this term (its character is the heading it already has). |
| Key position | After heading, before the hash. Integer key: `+sign * bfs_from_entry(cell)`, sign +1 Scout, 0 Seek. |
| Map result | Advance 1: party is on the entry cell, so all 10 cells have the same entry distance 4. The key changes nothing. Advance 2: all 7 cells have entry distance 6. The key changes nothing. The ring is symmetric around a party near its start. The key only acts after the party has moved off the entry. |
| What the player sees | Nothing on the first Advances. Later, a Scout that clears the near side of a wide room before it walks on. This is the closest match to "the road home" as words. |
| Failure modes | Ping-pong: possible. Heading prefers going on; the key prefers the near side; with a tie in heading, Scout can step back and forth across the entry side between Advances. It is bounded by the distance key, but it can cost extra Advances (D-50 already shows Scout needs 16.8 Advances). Loops: not infinite (each Advance lifts fog). Soft-lock: none. Ties: many cells share an entry distance, so the hash stays needed. |
| Party bend | Anchor lean raises the Scout sign toward +1; Edge lean lowers it to 0. Two states, same limit as A. |
| Determinism | Entry cell recomputed from the stage. No new saved field and no RNG. `mechanics-developer` checks that the entry cell is stable across a save and load. |
| Config keys | `stages.party_stance.directive_profile.<id>.frontier_home_sign`, `stages.party_stance.bounds.frontier_home_sign`, `stages.party_stance.leans.frontier_home.<family>`. |

### Definition C: "low added exposure" (prefer cells with lower exposure value)

| Item | Rule |
|---|---|
| Meaning | Scout prefers fog cells with the lowest value in the exposure map (design 3b). It is the same dial as E2. |
| Key position | After heading, before the hash. Integer key: exposure value of the cell, scaled by `(1 - effective tolerance)`. |
| Map result | None. At Tier 3 the exposure map is empty (section 1). The key is a no-op until the new story "Stage hazards and exposure" fills the map. |
| What the player sees | Nothing today. After that story, a Scout that keeps away from known danger while exploring. |
| Failure modes | Soft-lock risk is real once hazard data exists: if every fog cell has equal high exposure, ties fall to the hash; no cell is removed, so no lock. |
| Determinism | Same as A. |
| Recorded values | None today (the key is a no-op). |
| Config keys | None new. It reads the existing tolerance. |
| Note | This is the only definition that fully follows the "one exposure input" rule (D-05). A and B add a second idea ("snug", "near entry") that is not exposure. |

### Seek's heading preference (all definitions)

Seek's heading preference already exists as key 2. It is the same for both Directives. Options:

| Option | Rule | Cost |
|---|---|---|
| H0 (recommended if anything is built) | Build nothing. Seek continues the heading through key 2. | None. |
| H1 | Scout ignores the heading (its heading term is 0; the route key takes its place), Seek keeps it. The contrast becomes real: Seek goes on, Scout does not. | Changes the existing test `frontier_heading_continuation_keeps_direction` for Scout only. It also makes Scout re-sweep more, with higher Advance counts. Needs a new Directive-aware argument. Not recommended: it changes the working default. |

## 4. Question 3: do not build it in this phase

| Item | Detail |
|---|---|
| What stays | S2c ships with the bend only. `select_frontier` stays as is. S2d and later slices go on. |
| Cost to the design goals | Low. Section 2: depth, steps, fog per step, tolerance, stops and the pool bend carry the contrast. |
| Cost to the plan text | Four places say "Scout prefers cells that keep the road home explored" or "frontier ranking": `design.md` section 3 table (E1 row and E2 row, "Prefers explored ground"), section 10 adapter row; `backend-plan.md` S2c title and Change row. They must be edited so the plan matches what ships. Jeff approved design.md (D-43): the edit needs a recorded decision. |
| Cost to the why | `travel_why.route_character` has no frontier source. It is empty on frontier walks. |
| Cost to the later story | None. The argument is optional and trailing, the hash stays last, and the existing tests keep passing. Definition C becomes live when "Stage hazards and exposure" fills the map. Revisit there, with A or B only if play shows a "samey" frontier. |
| A cheap check before a later story | Measure how many Advances run at Tier 3, and how many of those have a tie after the heading key. If the share is small, the key never matters. A pool-probe-style run (`probes/pool_probe.gd.txt` pattern) would do it. The main chat runs it (RUN REQUEST). |

## 5. Recorded-value risk (for A or B)

| Item | Detail |
|---|---|
| Unit tests that call `select_frontier` | Unchanged. They pass no `route_character`, so the argument is `{}` and the old order holds. Sites: `StagePartyMovementTests.gd` lines 493 to 780, 1044, 1513 to 1524, 2214 to 2225. `frontier_tie_break_salt_unchanged` stays green by design. |
| Live-stage tests | Move when the stance has a non-zero sign. Candidates: `TraversalModelTests.gd` `_t_fog_frontier_sweep`, `_t_p5_chain_frontier_uses_full_budget`; `fog_scout_wider_than_seek`; `snapshot_fingerprint/stage_explore`; any `seam` test that fixes an open-fog route; the five traversal tests already re-recorded for D-50. `mechanics-developer` confirms the list. |
| Size of the move | LARGER than the plan says. `backend-plan.md` S2c says "Small. Only boards with a tie". In open fog a tie is normal: 10 tied cells at Advance 1 and 7 at Advance 2 in the worked example. Every Scout walk with a non-zero sign changes its fog picks. Treat it as a stage-wide re-record, with attribution (`opus`), not a small one. |
| Isolation | Do it in its own slice, after S2c is committed, so the moved values have one cause (LESSONS: no parallel re-records). |

## 6. Recommendation (Jeff decides)

I recommend option 3: do not build the frontier key in this phase.

Reasons:
1. The design goals do not need it. On a frontier-only walk, commitment depth and fog per step already separate Scout from Seek (D-50). Every D-08 contrast case lives in the pool, the exposure route or the stops.
2. The effect is small and almost invisible. In the worked example the key chooses between two cells in a fog edge four cells wide. The player will not see it, and no decision follows from it.
3. The cost is not small. It moves recorded values on every open-fog Scout walk, one slice after another large re-record (D-50).
4. The one definition that matches the design rule "one exposure input" (C) is a no-op until hazard data exists. That is when it should be built.
5. Seek's heading preference already exists.

If Jeff wants a frontier difference now, choose Definition A with the three-state sign: it works from Advance 1 (B does not), needs no saved field, and gives Scout and Seek opposite directions. Build it as its own slice with its own re-record.

If deferred, make these edits (a later task, with a recorded decision): `design.md` section 3 E1/E2 cells and section 10; `backend-plan.md` S2c title and Change row; note the deferral in `follow-ups.md` next to "Stage hazards and exposure".

## OPEN — questions and assumptions
ASSUMED: At Tier 3 the exposure map is empty in practice, because a revealed unresolved hostile is a pool candidate and so Tier 3 is not reached | WHY: D-49 says a revealed hostile can be the nearest pool candidate; design 3b says only unresolved revealed hostiles count; I read `find_explore_target` Tier 3 but did not run it | WRONG IF: a hostile that is revealed, unresolved and NOT a pool candidate can exist (for example an unreachable one), or the pool excludes some hostile kinds
ASSUMED: The worked-example counts (10 ties, 7 ties, neighbour counts) match the engine | WHY: computed with a Python copy of the 8-way search with an approximate corner rule, from `real-stage-maps.json` map 1 | WRONG IF: the engine's two-solid-corners rule or reveal set differs; D-48 already warns the Python copy is not the engine. Re-check with the engine before any value is authored
ASSUMED: The entry cell can be recomputed from the walkable set and bounds (`StageTerrain.entry_cell`) and is the same as the stage start | WHY: `TraversalModelTests.gd` uses it to place the party | WRONG IF: the real start cell is stored elsewhere or differs from `entry_cell`
ASSUMED: Tier 3 share of Advances is large enough to matter somewhat; I did not measure it | WHY: D-50 shows 11.5 to 16.8 Advances to the objective, so open-fog Advances are common | WRONG IF: most Advances are pool or Tier 4 Advances. The cheap measurement in section 4 settles it
BLOCKED: Does Jeff want a frontier cell-choice difference at all, or is the commitment and fog-per-step contrast enough? | CHECKED: design.md sections 1, 3, 7; D-45, D-50; backend-plan S2c; code in `select_frontier` and `find_explore_target` | NEED: Jeff's choice between option 1 (Definition A), option 2 (B or C), option 3 (defer)
BLOCKED: If deferred, who edits `design.md` (approved in D-43) and `backend-plan.md` S2c, and under which decision number? | CHECKED: decisions.md D-43 to D-50 | NEED: Jeff's approval to record a new decision (next free number) and to edit those files
