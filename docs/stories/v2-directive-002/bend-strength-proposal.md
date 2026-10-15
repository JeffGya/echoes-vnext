# V2-DIRECTIVE-002: bend strength proposal

Author: `mid-game-designer`, 2026-10-15. Status: PROPOSAL. Closes the last open line of D-60 ("strengthen the party bends").
No file in `data/`, `core/`, `ui/` or `tests/` was changed. Every number below is PROPOSED DEFAULT.
Jeff approves the numbers after he sees the measurement in section 6.
No player wording is in this file.

Method limits:
- I read `play-findings-report.md` section C, decisions D-04, D-08, D-26, D-27, D-35, D-44, D-46, D-50, D-54, D-55, D-60, `follow-ups.md`, `design.md` sections 3, 3.1, 4, 7, `numbers.md`, `data/balance.json` `data.stages.party_stance`, and the code named in the brief.
- I did NOT run Godot, tests or probes.
- I ran one small Python arithmetic model of the dial formulas (section 5.4). It is a model of the formulas, not a measurement of the game. Its inputs are my assumptions, listed there.
- I used no Notion tool and no skill.

---

## 0. Summary

1. The dials are small, but the dials are not the only cause of 0 of 606. Four other causes exist (section 3.4). Two of them sit in the probe, not in the numbers.
2. The 606 Advances used parties with the SAME fear and morale in every Echo. A leave-one-out test cannot see a state lean when all Echoes share it. A mixed party was never measured.
3. About four Advances in five have a frontier cell as the first target. That target is close. A change of commitment depth does not cut that walk (D-54 S1). So depth cannot name an Echo on those Advances.
4. The first plan does not model pauses (`StageCounterfactualService.gd:4`). So `stop_willingness` and the exposure pause cannot name an Echo with any bound.
5. Scout commitment is locked at 2 steps by D-50. The bound 0.10 keeps Scout inside 0.5 to 0.7. I keep that lock in both options.
6. The best data-only lever is NOT a larger bound. It is the price rounding (`exposure.price_scale`). At scale 4 the cost steps are 0.375 tolerance apart on the first ring. At scale 6 they are 0.25 apart. Scout then has a cost step 0.05 below its baseline.
7. Two options: M (scale 6, tolerance lean coefficients x4, no bound change) and S (M, plus tolerance bound 0.20 and Seek commitment lean coefficients x6). Section 5.
8. Recommendation: run the measurement on the CURRENT numbers with mixed parties first (variant V0). If V0 already names an Echo in 15 to 30 percent of mixed-party Advances, change nothing.

---

## 1. Verified facts that the brief and the follow-ups got slightly wrong

| Item | Source says | Code says | Effect |
|---|---|---|---|
| Price boundary | `follow-ups.md:44`: "exposure 0.67 always costs 3, boundary at tolerance 0.4375" | Correct for ring 1 (distance 1 from the hostile): cost = 1 + round(0.667 x (1 - tol) x 4). Cost 3 holds for tol 0.0625 to 0.4375. | No change. The follow-up is right. |
| Commitment gap | `balance.json` `bounds._comment` and `numbers.md` section 3 say commitment gap 0.35 | Scout 0.6 and Seek 0.85 give gap 0.25 (D-50 raised Scout from 0.5). Half gap is 0.125. The test `_t_party_stance_bounds_under_half_gap` (`StagePartyMovementTests.gd:1737`) reads the real profiles, so it tests 0.125. | Stale comment. Report only. The commitment bound may not reach 0.125. |
| Morale and homogeneous parties | Not stated | Morale 90 on every Echo gives mean lean +0.8 x 0.10 = +0.08. Seek 0.85 + 0.08 = 0.93, depth 6. Removing one Echo leaves 0.93. | The 606 runs pinned Seek at depth 6. Nothing to flip. |

---

## 2. Table 1: each dial, the decision it feeds, the thresholds

Notation: `tol` = exposure_tolerance, `w` = 1 - tol, `s` = stop_willingness, `f` = commitment_fraction, `eff` = effective steps. Rounding is `roundi` (half away from zero).

Exposure of a cell near a known hostile: ring 0 (the hostile cell) 1.0, ring 1 (8 cells) 0.667, ring 2 (16 cells) 0.333 (`StageExposureMap.gd:67`, config `hostile_radius` 2). Ring 0 is rarely on a route. Ring 1 and 2 are what a route meets.

| Dial | Decision it feeds | Where it is read | Thresholds (where the decision changes) | Baseline Scout / Seek | Bound now | Range now | Distance from baseline to nearest threshold |
|---|---|---|---|---|---|---|---|
| `exposure_tolerance` | Route price: entry cost = 1 + round(exposure x w x 4). A cost step can change the route (skirt or direct). | `StageExposureMap.to_terrain_costs` (line 43), called at `StageExploreTurnService.gd:242` and `StageCounterfactualService.gd:58` | Ring 1 cost 4 for tol <= 0.0625; cost 3 for 0.0625 to 0.4375; cost 2 for 0.4375 to 0.8125; cost 1 above 0.8125. Ring 2 cost 2 for tol <= 0.625, else 1. Ring 0: 5 / 4 / 3 / 2 / 1 at 0.125, 0.375, 0.625, 0.875. | 0.3 / 0.8 | 0.12 | Scout 0.18 to 0.42, Seek 0.68 to 0.92 | Scout ring 1: +0.1375 (to 0.4375), out of reach (max +0.12). Seek ring 1: +0.0125 (to 0.8125), in reach. Seek ring 2 down: -0.175. |
| `exposure_tolerance` + `stop_willingness` | Exposure pause (stop kind `paused_to_read`): pause when exposure x w x s >= 0.25 | `StageStopPolicy.exposure_pause` (line 49) | Ring 1: w x s >= 0.375. Ring 2: w x s >= 0.75. Ring 0: w x s >= 0.25. No pause on step 1 and none before a cell that is the exposure source (`StageExploreTurnService.gd:333`). | Scout w x s = 0.7 x 0.7 = 0.49. Seek 0.2 x 0.3 = 0.06. | tol 0.12, s 0.12 | Scout product 0.336 to 0.672 | Scout ring 1: product must drop by 0.115. Needs both dials at their bound at once. Ring 2: never (max 0.672 < 0.75). Seek: never (max 0.134). |
| `stop_willingness` | Only the exposure pause above. Reveal stops do NOT read it (`StageStopPolicy.classify_reveals` has no `s` argument). | `StageExploreTurnService.gd:254, 336` | No own threshold. A multiplier. | 0.7 / 0.3 | 0.12 | Scout 0.58 to 0.82, Seek 0.18 to 0.42 | Not applicable. |
| `commitment_fraction` | Depth = clamp(round(eff x f), 1, eff). Depth cuts the walk when depth < steps to the stop. | `StagePartyStance.build` (line 169) | Scout eff 3: depth 1 below 0.5, depth 2 for 0.5 to 0.8333, depth 3 from 0.8333. Scout eff 2: depth 1 below 0.75, depth 2 from 0.75. Seek eff 6: depth 4 for 0.5833 to 0.75, depth 5 for 0.75 to 0.9167, depth 6 from 0.9167. Seek eff 5: depth 3 for 0.5 to 0.7, depth 4 for 0.7 to 0.9, depth 5 from 0.9. | 0.6 / 0.85 | 0.10 | Scout 0.5 to 0.7, Seek 0.75 to 0.95 | Scout eff 3: down 0.10 (reaches 0.5 exactly, stays depth 2: 3 x 0.5 = 1.5 rounds to 2), up 0.2333 (out of reach). Scout eff 2: up 0.15 (out of reach). Seek eff 6: up +0.0667, down -0.10 (reaches 0.75 exactly, stays depth 5). Seek eff 5: up +0.05, down -0.15. |
| `escape_bonus` | Return-home roll: success when roll (0 to 100) > 40 - bonus | `VentureController.gd:338`, `escape_base_threshold` 40 | No threshold. Each point is one point of success chance. | 20 / 0 | 6 | Scout 14 to 26, Seek 0 to 6 | Not applicable. Not part of the first plan. |
| `category_weight` bend | Tie-break AFTER the authored weight (`select_objective_target` rank, line 844) | `StagePartyMovementAdapter.gd:840-846`, `StagePartyStance.category_bend` (line 101) | An exact tie of two authored weights inside the slack envelope. Any non-zero bend decides it. | Scout: objective 1.2 = reward 1.2. Seek: intel 0.9 = reward 0.9. | 0.09 | each weight +/- 0.09 | Zero for Seek intel vs reward (any Sight lean). Never for Scout: the leans have no `objective` or `reward` entry, so both bends are 0. |
| Readiness | Steps lost: 1 when party mean fear >= 55 or party mean morale < 40. Fear 35 to 55 loses 0. | `StagePartyStance.readiness_steps_lost` (line 79) | Mean fear 55. Mean morale 40. | 3 / 6 steps | 1 step | eff 2 to 3 / 5 to 6 | Depends on the party. One Echo flips it when abs(x_i - mean) / (n - 1) is at least the gap from the mean to the threshold. |

---

## 3. Why no dial flips today

### 3.1 The leave-one-out arithmetic

The party dial is baseline + sum(lean) / n, clamped to the bound. The naming test removes one Echo and compares.

- With Echo i: mean lean m = S / n.
- Without Echo i: (S - l_i) / (n - 1).
- Difference: **delta = (l_i - m) / (n - 1)**.

Examples. A party of 5 with one outlier and four zero leans: delta = l / 5. A party of 3: delta = l / 3. If every Echo has the same lean, l_i = m and delta = 0 for every dial.

Lean of one Echo = coefficient x bound x strength. Strength = 0.35 + 0.65 x width (`dispositional_floor` 0.35). State leans (fear, morale) are not scaled by strength.

### 3.2 Largest single-Echo lean today

| Dial | Biggest single-Echo lean (coefficient x bound x strength 1.0) | delta for n = 5 | Distance to the nearest useful threshold | Verdict |
|---|---|---|---|---|
| tol, Scout | Edge 1.0 x 0.12 + forceful identity 0.12 + morale 0.25 x 0.12 = 0.27 | 0.054 at most; 0.014 to 0.03 typical | +0.1375 (ring 1, 3 to 2) | CANNOT flip. Needs a lean of 0.69 (2.5 times the maximum, about 10 times typical). |
| tol, Seek | Same, 0.27 | 0.054 at most | +0.0125 (ring 1, 2 to 1) | CAN flip. Needs a lean of 0.0625. Edge at strength 0.52 or more does it. The limit is board shape, not the dial. |
| commitment, Scout | Edge 0.10 + morale 0.10 = 0.20 | 0.04 | Down 0.10 (not reached: the bound stops at exactly 0.5), up 0.2333 | CANNOT flip. By design (D-50). |
| commitment, Seek | Edge 0.10 + morale 0.10 = 0.20 | 0.04 | Up +0.0667 | CANNOT flip from one Echo of 5 on calling alone: the lean needed is 0.333. Morale alone moves it only when Echoes differ in morale. |
| stop_willingness | 0.12 per primary lean | 0.024 | No own threshold | CANNOT name. The first plan has no pause (`StageCounterfactualService.gd:4`). |
| escape_bonus | 6 | 1.2 points | No threshold | CANNOT name. Not part of the plan. |
| category bend | 0.09 x strength | not needed | 0 | CAN flip when a tie exists. K2 proves it. |
| readiness | not a lean | not applicable | party mean | CAN flip today when Echoes differ in fear or morale. |

### 3.3 Dials that CAN flip with a larger bound

| Dial | Larger bound helps? | Why |
|---|---|---|
| tol | Yes, but a bound alone is not enough. | The lean scales with the bound, and the bound must stay under 0.25. At 0.24 the largest single lean is 0.54, delta 0.108 for n = 5. That still misses 0.1375 for a typical Echo. A larger bound also removes the Scout/Seek price contrast (section 5.5). |
| commitment | No. | Scout is locked by D-50. The bound must stay under 0.125. Seek needs lean 0.333 against a bound of 0.10. The limit is the divide by n. |
| stop_willingness | Irrelevant. | The plan cannot see pauses. |
| category | No. | The bend only breaks ties. The bound never enters the rank. |

So a larger bound is not the lever. Two levers remain in `data`:
1. the lean coefficients (a coefficient above 1.0 lets one Echo use more of the bound);
2. `exposure.price_scale` (puts a cost step inside the dial range).

### 3.4 Causes outside the dials

| # | Cause | Evidence | Effect on naming |
|---|---|---|---|
| C1 | The 606 parties were homogeneous in state | `play-findings-report.md` C2: calm morale 90, fear 60, fear 45, Edge x3 at morale 100, Anchor x3 at fear 45 | delta = 0 for fear and morale leans. Readiness (mean) cannot flip when all Echoes are equal. |
| C2 | The first target is a frontier cell on about 4 Advances in 5 | Causes `directive` 286 + `party` 123 + `terrain` 80 = 489 of 606 are frontier or fixed targets; `situation` 75 + `objective` 42 = 117 (19 percent) are pool targets | `plan_first_leg` ends the path at the target (`StageCounterfactualService.gd:76`). A frontier target is 1 to 3 cells away, so a different depth does not change the plan (D-54 S1). Only pool targets farther than the depth can be named through depth. |
| C3 | The plan has no pause and no reveal stop | `StageCounterfactualService.gd:4` | A real pause or reveal stop makes the walk differ from the plan. `confirm_walk` then DROPS the name (D-55). More pauses means fewer names. |
| C4 | The price needs a known hostile and an alternative route | `StageExposureMap.build` takes revealed, unresolved, `combat` situations only | On a board with no revealed hostile near the route the map is empty and tolerance has no effect. |

C1 and C2 mean the first step is to measure current numbers with a mixed party. A raise of the numbers may be small or not needed.

---

## 4. What changes the visible result, and what the player sees

All effects stay bounded because the party dial is clamped to the bound (`StagePartyStance.build` line 153).

| Decision | What the player sees | Dial that moves it |
|---|---|---|
| Effective steps | One step diamond crossed out (D-60 step row) | Readiness (mean fear, mean morale). Not changed by this proposal. |
| Commitment depth (Seek) | One more or one fewer step walked before the Advance ends. The step row crosses out the unused diamond (D-60). | `commitment_fraction` |
| Route near a known hostile | The party skirts the hostile, or walks past it. The stop mark shows a skirted route. | `exposure_tolerance` through the price |
| Pause before an exposed cell | The Advance ends one cell early with the `paused_to_read` mark | `exposure_tolerance` x `stop_willingness`. Not changed by this proposal. |

The largest effect of one profile is one step of depth, one cost step per ring cell, or one lost step. Nothing is larger.

---

## 5. Proposal

### 5.1 Rules I held (guards)

| Guard | Source | How both options meet it |
|---|---|---|
| Category bend only breaks ties; bound under half the smallest gap (0.2, so under 0.10) | D-44, test `party_stance_bounds_under_half_gap` | `category_weight` stays 0.09 and the `leans.category_weight` block is not touched. No change proposed. The tie must exist; I cannot create one without changing authored weights. |
| Scout and Seek stay different | D-08, design section 3 "Directive ordering holds" | Each bound stays under half the gap. Scout max stays below Seek min on tolerance and commitment. See 5.5 for the cost at the extremes. |
| Scout depth 2 under every lean | D-50 | `bounds.commitment_fraction` stays 0.10 in both options. Scout stays 0.5 to 0.7. |
| Readiness lowers only | D-27 | `readiness` block not touched. |
| Tunables live in config | ANSWERS #83 | All changes are in `data/balance.json`. |

### 5.2 Where each key is read (checked with grep)

| Key | Reader |
|---|---|
| `data.stages.party_stance.bounds.<dial>` | `core/movement/StagePartyStance.gd:75` (`echo_lean`) and `:142` (`build`) |
| `data.stages.party_stance.leans.<dial>.<input>` | `core/movement/StagePartyStance.gd:52` (`echo_lean`) |
| `data.stages.party_stance.exposure.price_scale` | `core/realms/StageExploreTurnService.gd:242`, `core/realms/StageCounterfactualService.gd:60` |

No code change is needed. All keys exist now.

### 5.3 The two options

| Key (under `data.stages.party_stance`) | Now | **Option M** (moderate) | **Option S** (strong) |
|---|---|---|---|
| `exposure.price_scale` | 4 | **6** | **6** |
| `leans.exposure_tolerance.calling_anchor` | -1.0 | **-4.0** | **-4.0** |
| `leans.exposure_tolerance.calling_edge` | 1.0 | **4.0** | **4.0** |
| `leans.exposure_tolerance.calling_sight` | -0.5 | **-2.0** | **-2.0** |
| `leans.exposure_tolerance.fear` | -1.0 | **-4.0** | **-4.0** |
| `leans.exposure_tolerance.morale` | 0.25 | 0.25 | 0.25 |
| `bounds.exposure_tolerance` | 0.12 | 0.12 | **0.20** |
| `leans.commitment_fraction.calling_edge` | 1.0 | 1.0 | **6.0** |
| `leans.commitment_fraction.calling_anchor` | -0.5 | -0.5 | **-3.0** |
| `leans.commitment_fraction.calling_sight` | -0.5 | -0.5 | **-3.0** |
| `leans.commitment_fraction.morale` | 1.0 | 1.0 | 1.0 |
| `bounds.commitment_fraction` | 0.10 | 0.10 | 0.10 |
| `bounds.stop_willingness`, `escape_bonus`, `category_weight`, `readiness_steps` | 0.12, 6, 0.09, 1 | unchanged | unchanged |
| `leans.stop_willingness`, `escape_bonus`, `category_weight` | as is | unchanged | unchanged |
| `readiness.*`, `exposure.pause_trigger`, `hostile_radius`, `hostile_peak` | as is | unchanged | unchanged |
| `identity.*` | as is | unchanged (its lean scales with the bound, and the bound is unchanged) | unchanged coefficients; the tolerance identity lean grows 1.67 times because the tolerance bound grows from 0.12 to 0.20 |

Why price_scale 6 and not 8: at scale 6 the Seek prices stay identical to today (ring 0: 2, ring 1: 2, ring 2: 1). Only Scout prices rise (ring 0: 4 to 5, ring 1: 3 to 4, ring 2: 2 to 2). Every recorded Seek value that depends on price is unchanged. Scale 8 reaches Scout sooner (+0.044) but moves Seek ring 2 from 1 to 2.

Cost thresholds at scale 6 (tolerance where the cost steps):

| Ring | Steps at tolerance | Scout 0.3 cost | Seek 0.8 cost | Nearest to Scout | Nearest to Seek |
|---|---|---|---|---|---|
| 1 | 0.125, 0.375, 0.625, 0.875 | 4 | 2 | +0.075 (to 0.375) | +0.075 (to 0.875) |
| 2 | 0.25, 0.75 | 2 | 1 | -0.05 (to 0.25) | -0.05 (to 0.75) |

Compare scale 4: Scout nearest +0.1375, Seek +0.0125.

### 5.4 Expected effect (ARITHMETIC MODEL, not a measurement)

Model assumptions (each one can be wrong): party sizes 3 and 5; strength from width in {0.2, 0.4, 0.6, 0.8}; family uniform over anchor, edge, sight, none; "mixed" fear drawn from {5, 10, 15, 25, 40, 60, 75} and morale from {25, 35, 50, 60, 70, 85, 95}; "homogeneous" = fear 10, morale 90 for all (like the 606 runs); "neutral" = no Calling, fear 10, morale 50, identity lean 0. Each cell is 8000 random parties. A cell value is the share of parties where removing at least one Echo changes that component. These shares are NOT shares of Advances: a depth flip counts only on a pool target farther than the depth (about 19 percent of Advances, C2), and a price flip counts only where a known hostile and an alternative route exist (C4).

Shares as steps / depth / price, in percent of parties:

| Party | n | Directive | Current | Option M | Option S |
|---|---|---|---|---|---|
| neutral | 3 and 5 | both | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| homogeneous, with Callings | 5 | Scout | 0 / 0 / 0 | 0 / 0 / 64 | 0 / 0 / 72 |
| homogeneous, with Callings | 5 | Seek | 0 / 34 / 41 | 0 / 34 / 64 | 0 / 35 / 71 |
| homogeneous, with Callings | 3 | Scout | 0 / 0 / 0 | 0 / 0 / 59 | 0 / 0 / 57 |
| homogeneous, with Callings | 3 | Seek | 0 / 44 / 46 | 0 / 45 / 60 | 0 / 45 / 58 |
| mixed | 5 | Scout | 20 / 20 / 0 | 20 / 20 / 34 | 20 / 20 / 49 |
| mixed | 5 | Seek | 20 / 35 / 17 | 20 / 34 / 34 | 21 / 52 / 49 |
| mixed | 3 | Scout | 40 / 40 / 0 | 41 / 41 / 44 | 41 / 41 / 55 |
| mixed | 3 | Seek | 42 / 59 / 30 | 40 / 58 / 43 | 41 / 66 / 55 |

Reading the table:
- "Neutral" stays at 0. The target "near 0 for a neutral party" holds in both options.
- "Steps" does not change with M or S. Readiness is untouched. In a mixed party it is already 20 to 42 percent of parties on current numbers. If the real fear spread looks like my assumption, the mixed-party naming rate is already in or near the 15 to 30 percent target. The measurement in section 6 decides this.
- Scout "depth" equals "steps" (Scout depth only changes when `eff` changes, D-50).
- "Price" is the big gain, and only M and S create it for Scout.
- S adds Seek depth flips in mixed parties (35 to 52 percent of 5-Echo parties).

Single Echo, party of 5, the other four neutral (model):

| Directive | Echo | width 0.1 | width 0.5 | width 0.9 |
|---|---|---|---|---|
| Scout | Edge | M no, S price | M price, S price | M price, S price |
| Scout | Anchor | M no, S price | M price, S price | M price, S price |
| Scout | Sight | M no, S no | M no, S price | M price, S price |
| Seek | Edge | M no, S price | now price, M price, S depth + price | same |
| Seek | Anchor | M no, S price | M price, S price | M price, S price |
| Seek | Sight | M no, S no | M no, S price | M price, S price |

"now" appears only where the current numbers already flip (Seek Edge at width 0.5 or more, ring 1, 2 to 1). In every other cell the current numbers give no flip.

### 5.5 Risk table

| Risk | Option M | Option S |
|---|---|---|
| Scout and Seek contrast at the extremes (all-Edge Scout party against all-Anchor Seek party) | Ring 1: Scout 3, Seek 2. Ring 2: Scout 2, Seek 2. Ordering holds. Ring 2 contrast is lost only at the extreme. Today Scout 2 and Seek 1. | Tolerance range Scout 0.10 to 0.50, Seek 0.60 to 1.00. Ring 1: Scout 3, Seek 3. Ring 2: 2 and 2. Ordering holds. Contrast is gone at the extreme pair. A margin of 0.10 remains in tolerance. |
| Scout commits more than Seek | Not possible. Scout depth <= 2, Seek depth >= 5 (eff 6) | Same. Commitment bound unchanged. |
| Per-Echo lean above the bound | Tolerance lean up to 0.12 x 4.0 x 1.0 = 0.48 against a bound 0.12. The party dial is still clamped. | Tolerance 0.20 x 4.0 = 0.80. Commitment 6.0 x 0.10 = 0.60 against a bound 0.10. Still clamped. Test `_t_stance_standing_floor_leans_at_standing_1` (`StagePartyMovementTests.gd:2091`) asserts lean <= bound for the commitment dial. It FAILS in S. In M it passes (commitment coefficients unchanged). |
| Redundant Echoes saturate | Two same-Calling Echoes of 5 reach the clamp. Removing one then changes little. The cause becomes `party`. This is the intended meaning of "bounded". | Same, stronger. |
| Commitment often at depth 6 | None | Seek parties with Edge Echoes reach depth 6 more often (model: Seek depth flips rise from 35 to 52 percent of mixed parties of 5). Seek loses part of its "5 of 6" feel. The bound still caps the dial at 0.95. |
| More terrain causes and detour refusals | Scout costs rise by 1 on ring 0 and 1. The priced route may exceed the slack gate more often (`detour_within_slack`). Cause shows `terrain`, no name. | Same, more. |
| Names dropped by `confirm_walk` (D-55) | Unchanged. | Slightly more if pauses rise. |
| D-50 intent | Kept | Kept (bound unchanged). |
| Gain applied to fear (tolerance) | A frightened Echo (fear 70) moves tolerance by -0.48 for its own lean. In a party of 5 this is -0.096. | -0.16 of the mean. |

I recommend M if Jeff wants a small step with a small blast radius. I recommend S only if the V1 measurement (M) misses the target on Seek pool targets. Jeff owns the choice.

### 5.6 Tests and recorded values that will move

I cannot run tests. This list comes from grep and reading the fixtures. "Check" means: re-run after the change, then attribute with predict-then-observe before any re-record (AGENTS.md mistakes 23 and 27).

Moved by `price_scale 6` and the tolerance coefficients (both options):

| Test or value | File | Why it can move |
|---|---|---|
| `_t_exposure_scout_detours_seek_direct` | `tests/StagePartyMovementTests.gd:1915` | Reads the config scale. Scout prices rise. The priced Scout route must stay inside the slack gate. Seek prices are identical to today, so "Seek must go direct" should hold. |
| `traversal/exposure_two_route_board_scout_vs_seek` | `tests/TraversalModelTests.gd:2332` | Real Advance on a two-route board. Scout bypass must still win. |
| `seam/later_leg_refusal_keeps_first_cause` | `tests/Stage004SeamTests.gd:75` | Board-specific slack numbers (slack 4 from col 0, 3 from col 1). Scout costs rise, so the refusal point can shift. |
| `traversal/counterfactual_p1_named_echo_changes_plan`, `..._s3_fear_names_frightened`, `..._tie_pin_lowest_id`, `..._walk_probe`, `..._walk_differs_names_nobody`, `..._walk_equal_keeps_name`, `..._cap_respected` | `tests/TraversalModelTests.gd:418-440` | Fixtures built on the current prices and tolerance. A larger lean can add a decider (the tie-pin test) or move the decisive Echo. |
| `traversal/advance_state_identical` (`ADV_EXPECTED`, scenarios `gen42_scout`, `gen42_seek`, `gen100_scout`, `gen100_seek`, `corridor_seek`, `rect_seek`) | `tests/TraversalModelTests.gd:2134` | Moves only if a hostile is revealed inside the 6 Advances and the party has a lean. `corridor_seek` holds a `combat` objective. The `gen*` scenarios may reveal one. The default test party may have no Calling, then nothing moves. Check by running; do not assume. |
| `traversal/fog_scout_wider_than_seek`, `traversal/fog_light_bias_seek_engages`, `traversal/p5_tier1_hard_stops_on_arrival` | `tests/TraversalModelTests.gd:1267, 1509, 1999` | Boards with a hostile near the target. They move only through price. |
| `snapshot_fingerprint/stage_explore` | `tests/FlowSnapshotFingerprintTests.gd:335` | Expected UNCHANGED. It hashes the entry snapshot before any Advance. Depth equals budget there (`StageExploreP5Tests.gd:976`). Readiness is untouched. |
| `party_stance_bounds_under_half_gap` | `tests/StagePartyMovementTests.gd:1737` | Passes in M (no bound change). Passes in S (tolerance 0.20 < 0.25; commitment 0.10 < 0.125). |
| `stance_ordering_per_dial`, `stance_party_order_shuffle_identical`, `stance_commitment_never_exceeds_effective_steps` | `tests/StagePartyMovementTests.gd:2052, 2077, 2157` | Should pass. They check clamps and order, not exact values. |

Moved only by Option S:

| Test or value | File | Why |
|---|---|---|
| `_t_stance_standing_floor_leans_at_standing_1` | `tests/StagePartyMovementTests.gd:2091` | Asserts a single-Echo commitment lean <= bound. Edge rank 6 gives 6.0 x 0.10 x 1.0 = 0.6. The assertion encodes a stricter rule than D-04 needs. Change the assertion to "party dial <= bound". That is a `tests/` edit, not mine. |
| `explore_p5/snapshot_commitment_depth_scout_and_seek` | `tests/StageExploreP5Tests.gd:971` | Party Anchor + Edge, rank 3, calm morale 50. Expects Seek depth 5 of 6. Predicted lean on Seek: (6.0 x s - 3.0 x s) x 0.10 / 2 = 0.15 x s. For s >= 0.45 this reaches 0.9167 and the depth becomes 6. Likely FAILS. Scout stays 2 of 3. |
| `traversal/one_stance_per_advance`, `traversal/all_shaken_party_still_moves_or_names_stop` | `tests/TraversalModelTests.gd:2433, 2444` | Should pass. Shaken party still keeps one step (readiness untouched). |

Not moved by either option (checked):
- Contact tests. `ConversationService.party_widths` (`ConversationService.gd:506`) reads `read_party` for width only. It reads no bound, lean or price.
- Escape tests (`seam/escape_*`). `escape_bonus` bounds and leans are unchanged.
- `traversal/k2_sight_vs_edge_tie`, `traversal/pool_o1..o3`, `bend_*`. The category block is unchanged.
- `DirectiveConfigTests.gd:451` compares the config to itself.

### 5.7 What I did not propose, and why

| Not proposed | Why |
|---|---|
| Larger `stop_willingness` bound | The plan has no pause (C3). A larger bound cannot add a name. It can only add pauses, and a pause drops a name. |
| Larger `escape_bonus` bound or any change | Not in the first plan. Changes the odds of the return roll only. |
| Larger `category_weight` bound | The bend ranks after the weight. The bound never enters the rank. A tie is what matters. Seek intel vs reward (0.9 each) is the only shipped tie that a lean can break. |
| Change of the Scout commitment baseline or the Seek baseline | D-50 is Jeff's. If Jeff wants a Seek commitment flip from one Echo, a baseline nearer 0.9167 (for example 0.88) is the cheapest lever. It moves every Seek recorded value. Not in scope here. |
| A change of the party average (divide by n) | This is the root of the dilution: delta = l / 5 in a party of 5. A code change to `StagePartyStance.build` and a change to design section 4 rule 1. It is a `sr-game-designer` decision. I note it because it would work better than any coefficient. |
| `hostile_radius`, `hostile_peak`, `pause_trigger` | Not needed for naming. |

---

## 6. Measurement plan (RUN REQUEST outline for the main chat)

A later step builds the probe. A subagent may not run it (root `AGENTS.md`, "Long runs belong to the main conversation"). This is the outline the builder fills in.

### 6.1 Probe

- A new read-only SceneTree script, built like `docs/stories/v2-directive-002/probes/pause_probe.gd.txt`. It lives in a scratch folder, not in `core/`, `ui/`, `tests/` or `data/`.
- Real `FlowRuntime`, real `stage.advance_turn` dispatch, real saves built through the production path (onboarding, party toggle, select realm), so the probe mirrors production construction.
- Config variants are applied IN MEMORY after boot, as `StageCameraSelectTests.gd:1279` does (`config_service._balance["data"]["stages"]["party_stance"]...`). The probe edits no repo file.
- The probe reads each Advance's `travel_why` (`cause`, `named_echo_name`, `echo_reason_class`, `stop_kind`), `last_traveled_path`, `effective_steps`, `commitment_depth`.
- For the "proposed but dropped" count the probe calls `StageCounterfactualService.name_deciders` once on the pre-Advance state (read-only), then compares with the stored `why` after the Advance. It does not change production code.
- For the ranking check the probe calls `select_objective_target` with the real bend and with `{}` on the same pool, and counts picks that differ where the authored weights differ. Target: 0.

### 6.2 Variants

| Id | Content | Why |
|---|---|---|
| V0 | Current numbers | Baseline on mixed parties. Never measured. |
| V3 | `price_scale` 6 only, coefficients as now | Attribution: price alone. |
| V1 | Option M | The moderate option. |
| V2 | Option S | The strong option. |

Run V0 first. If V0 already meets the target in the mixed rows, stop. Jeff decides to accept.

### 6.3 Party sets (each Echo a real factory Echo with real bonds)

| Id | Content |
|---|---|
| P0 neutral | 5 Echoes, no Calling, morale 50, fear 5 |
| P1 homogeneous | 5 Echoes with the three families, morale 90, fear 10 (repeats the 606 runs) |
| P2 mixed calm | 5 Echoes, all three families, Standing 1 to 6, fear 0 to 30, morale 40 to 80 |
| P3 mixed stressed | Same, fear 20 to 70, morale 25 to 70 |
| P4 typical-5 | 1 Edge, 1 Anchor, 1 Sight, 2 without Calling, mixed fear and morale, Standing 1 to 4 |
| P5 Jeff-3 | The 3 Echoes of Jeff's save, then the same with one Calling per Echo |

Run P2 to P4 also at size 3.

### 6.4 Boards

Realm `realm.01`, stages 0 to 2, seeds 101 and 202 (as `pause_probe`), both Directives, at most 40 Advances per stage.

### 6.5 Command shape

```
rm -rf <probe save dir>      # the probe uses a per-process dir under /private/tmp/claude-501/
/usr/bin/perl -e 'alarm shift; exec @ARGV' <ALARM> /opt/homebrew/bin/godot --headless --path <checkout> \
    -s <probe.gd> -- <out_file> <variant> <party_set> <seeds_csv> <realms_csv> <directives_csv> <max_stages> <max_advances>
```

- `<checkout>` is the worktree path.
- The argument list follows the header of `pause_probe.gd.txt`. That header does not record the exact Godot flags. The builder confirms them with one short slice.
- One slice = one variant x one party set. Run slices one at a time. Do not run two Godot processes together.
- Expected duration: one slice is about 2 x 3 x 2 x 40 = 480 Advances. At 0.17 to 0.23 s per Advance (`follow-ups.md:91`, after package E) that is under 3 minutes plus boot. A full pass of 4 variants x 6 party sets = 24 slices, about 1 to 1.5 hours.
- Timeout and alarm: PROPOSED DEFAULT. Use at least the example in `tools/AGENTS.md` for a 12-minute probe (`timeout: 1200000`, alarm 1500) per slice. The builder sets the final values from one timed slice. A high value costs nothing.
- Files edited by the run: none. Verify: `git status --short` is empty, and the probe save dir is removed.

### 6.6 What the probe prints (one row per variant x party set x Directive x party size)

| Column | Meaning |
|---|---|
| Advances | Count |
| Named % | Advances with `cause = echo`, per Directive and per party set |
| Cause counts | `echo`, `directive`, `party`, `terrain`, `situation`, `objective` |
| Reason classes | `calling`, `temperament`, `fear`, `morale`, `steadied` |
| Decisive Echo | Count per Calling family and per Standing. Shows if the lowest-id tie pins one Echo (D-47 J3). |
| Proposed but dropped | Names that `name_deciders` gave and `confirm_walk` removed |
| Steps per Advance | Mean walked steps, mean `effective_steps`, mean `commitment_depth` |
| Depth cuts | Share of Advances where the stop is `commitment_spent` |
| Stop kinds | Share of `arrived_at`, `capacity_spent`, `commitment_spent`, `interrupted`, `spotted_ahead`, `paused_to_read`, `no_route` |
| Exposure | Share of Advances with a non-empty exposure map; share where the priced route differs from the plain route; share with `detour_refused` |
| Pool | Share of Advances with a pool first target; share with an exact weight tie |
| Ranking check | Count of picks changed by the bend where authored weights differ. Must be 0. |
| Time | Mean and 95th percentile ms per Advance |

### 6.7 Targets

| Target | Pass rule |
|---|---|
| Mixed party names an Echo | 15 to 30 percent of Advances (P2, P3, P4, size 5) |
| Neutral party | Under 2 percent (P0) |
| Authored ranking | Ranking check = 0 |
| Directive contrast | Mean steps per Advance Seek > Scout. Mean tolerance Seek > Scout for every party set. |
| Pauses | `paused_to_read` share rises by at most 5 points against V0 |
| Dropped names | At most 15 percent of proposed names (D-56 accepted 13 percent) |
| Speed | Mean Advance under 500 ms with 5 Echoes (D-55 target) |
| No pin | No single Echo gets more than 50 percent of the names in a tied party |

### 6.8 Decision rule for Jeff

1. Read V0. If P2 to P4 are inside 15 to 30 percent, the numbers need no change. Jeff decides whether the rate is enough.
2. If V0 is below 15 percent, read V3, then V1. Pick M if V1 meets the targets.
3. Read V2 only if V1 misses on Seek pool targets. S needs a `tests/` edit (section 5.6) and Jeff's confirmation that the extreme-party contrast loss (section 5.5) is acceptable.
4. Re-record tests only after attribution. The builder predicts each moved value from the numbers, observes it, then re-records.

---

## 7. Stale facts found (report only)

| Where | What |
|---|---|
| `data/balance.json` `party_stance.bounds._comment` | Says commitment gap 0.35. The gap is 0.25 since D-50. |
| `docs/stories/v2-directive-002/numbers.md` section 3 | Same stale gap (0.35, range 0.40 to 0.60 / 0.75 to 0.95). Real range: Scout 0.5 to 0.7. |
| `docs/stories/v2-directive-002/follow-ups.md:44` | Says "Test P1 was built on Seek". Correct. Its text "Scout naming can name only fear or morale" is true for the price. It is also true for readiness (steps). |
| `docs/stories/v2-directive-002/numbers.md` section 3, `pause_cap_per_advance` | Still unused (D-46). Not a defect. |

---

## OPEN — questions and assumptions

ASSUMED: The real fear and morale spread of a typical party is like the mixed sets in 6.3 (fear 0 to 75, morale 25 to 95), not like the 606-run parties | WHY: Jeff's own save has morale 46 to 72, so Echoes already differ; the 606 parties were set to one value per run | WRONG IF: real parties stay within a narrow band (for example all morale 50 to 60, fear under 20). Then V0 will show about 0 percent and the readiness flips vanish. The price and depth levers then carry all the naming.

ASSUMED: The arithmetic model of section 5.4 shows direction and order of size only | WHY: It uses my guessed width, family and state spread; it ignores bond edges removed with an Echo (the real removal also lowers the others' width); it counts a depth flip and a price flip as always material | WRONG IF: the real width values differ much from {0.2 to 0.8}, or most pool targets lie within the depth, or hostiles are rarely revealed near a route. The measurement replaces the model.

ASSUMED: Jeff wants D-50 kept (Scout depth 2 under every lean) | WHY: D-50 states it as the reason for 0.6 | WRONG IF: Jeff accepts Scout depth 1 for a very careful party. Then the commitment bound could rise to 0.12 and Scout could flip down. I did not propose it.

ASSUMED: A lean coefficient above 1.0 is allowed by the design (one Echo may use more than the bound; the party dial is still clamped to the bound) | WHY: `numbers.md` section 5 calls 1.0 "primary" and 0.5 "secondary" but does not forbid more; the clamp is in `StagePartyStance.build` | WRONG IF: Jeff reads "bound" as "the most any ONE Echo can bend". Then the dilution (divide by n) is the only lever and needs `sr-game-designer` (section 5.7).

ASSUMED: Equal price at the extreme pair (Scout all-Edge vs Seek all-Anchor) is acceptable | WHY: D-08 asks for contrast between Standings, and the brief asks that Scout dial ranges do not overlap Seek's; ordering holds | WRONG IF: Jeff wants Scout to pay strictly more than Seek on every ring for every party. Then tolerance gains must stay with the bound at or under 0.13 (ring 1) and Option S is out.

ASSUMED: `price_scale` is in scope for this proposal | WHY: it sits in `data.stages.party_stance.exposure` and the brief asks for the dials that feed decisions; it is the lever that works best | WRONG IF: Jeff wants only bounds and lean strengths. Without `price_scale`, Scout cannot flip a price with any allowed bound (section 3.3).

BLOCKED: Exact Godot flags for a SceneTree probe script | CHECKED: `probes/pause_probe.gd.txt` header (gives args after `--` only), `AGENTS.md`, `tools/AGENTS.md`, `handover.md`, `play-findings-report.md` section 0 | NEED: the builder of the probe confirms the flags with one short slice.

BLOCKED: Real width (`interpretation_width`) per Standing | CHECKED: `StagePartyStance.read_echo`, `MaturityExpressionService` call; I did not run it | NEED: the probe prints the width and strength per Standing in its first slice, so the model inputs can be checked.

BLOCKED: Whether the default test party (`_make_runtime`) has Callings, so which recorded values in `ADV_EXPECTED` move | CHECKED: `TraversalModelTests.gd:2183`, `:2418`; I did not run tests | NEED: a filtered run (`tests traversal`) after the change, with attribution. `qa-verifier` or the main chat.

Recommendation for the main chat: dispatch the probe builder (`sonnet`) for V0 first. Use `opus` only for the attribution of moved recorded values after a change. No parallel fan-out: the probe and the tests share Godot and `/tmp/echoes-vnext-tests/`.
