# V2-DIRECTIVE-002 phase D: config numbers

Author: `mid-game-designer`, 2026-10-16. Source: `phase-d-design.md` (sections 2, 3, 4, 6, 8, 10), `decisions.md` D-69, D-70, D-71.
File to edit later: `data/balance.json`. This note edits nothing. No player text is proposed.
Every value is PROPOSED DEFAULT. Jeff owns the final values. "Reader pending" means no code reads the key yet.
All paths start at `data.`. Values and line numbers were read from `data/balance.json` on 2026-10-16.
Rule: a key is authored in its own slice only. A key authored early is a dead key.

---

## 0. Summary

| Item | Proposal |
|---|---|
| New keys | 7 (offset, fear lean bound, 2 Judgment floors, 3 affinities) |
| Existing key changed | 1 (`directive_exposure_acceptance_weight`, 2.0 to 17.0; D-73 replaced the first start value 11) |
| Slice 1 | `offset` 0.5, weight 17.0 (D-73; the sweep covered 0, 2, 8, 11, 14, 17, 19) |
| Slice 2 | `fear_lean_bound` 0.12 (D-71) |
| Slice 3 | acceptance `judgment_floor` 0.6 |
| Slice 4 | affinity guard 1.0, hold 0.8, observe 0.3; stop `judgment_floor` 0.6 |
| Budget | Layer A 1.80, layer B 1.67, layer C 1.67. All are at or under 2.0. |
| Fear rule F6 | 0.12 is at least 4 times the needed 0.03. |
| Stop result | Matches the intent: Seek seldom stops, Scout stops more, a seasoned Echo stops for the Directive less. Details in 2c. |
| Main risk | The first range 8 to 14 was too low to change routes. The probe showed this, and D-73 set weight 17. The effect is still small (see D-73 limits). |

---

## 1. New and changed keys

### 1a. Slice 1: base acceptance map and weight

| Key path | Proposed value | Range the probe may try | Slice | File | What it does | Why this value |
|---|---|---|---|---|---|---|
| `combat.movement.exposure_acceptance.offset` | 0.5 | None. Fixed by D-69 Q1. Valid band for a test: above 0.3 and below 0.8. | 1 | `data/balance.json`. New sibling block of `spatial_utility`. Reader pending: `BehaviorArbiter.gd` near `:783`, where `_movement_cfg` is read. | Sets combat acceptance to the Directive `exposure_tolerance` minus this number. | 0.5 gives Scout -0.2 and Seek +0.3. Jeff chose it. It sits between the two tolerances (0.3 and 0.8), so the sign differs per Directive. |
| `combat.movement.spatial_utility.directive_exposure_acceptance_weight` | 17.0 (D-73) | Sweep list (history): 0, 2 (control, shipped), 8, 11, 14, 17, 19. Upper limit: below 20 (see 2d). | 1 | `data/balance.json:1708`. Existing key. Reader exists: `BehaviorArbiter.gd:1435`. | Sets how many score points one unit of acceptance moves an exposed route option. | Jeff chose 17 (D-73), which replaces the D-70 J1 range 8 to 14 and the D-72 start value 11. The probe showed the term is silent below 14. Limit: 17 is safe only for tolerance under 0.853 (0.5 + 6/17); see 2d. |

### 1b. Slice 2: fear lean

| Key path | Proposed value | Range the probe may try | Slice | File | What it does | Why this value |
|---|---|---|---|---|---|---|
| `combat.movement.exposure_acceptance.fear_lean_bound` | 0.12 | Sweep list: 0.06, 0.12, 0.16. Floor: 0.03 at shipped values (total bound of rule F6); 0.05 for any tolerance (`max abs(D)` 0.5). Ceiling: 0.16 (2b). | 2 | `data/balance.json`. Reader pending: `BehaviorArbiter.gd` (shared fear-ramp helper). | Sets the largest drop in acceptance that fear can cause. | Jeff chose 0.12 (D-71 O1), equal to the stage bound `stages.party_stance.bounds.exposure_tolerance`. 0.12 keeps a frightened Seek Echo above zero (2b). |
| `stages.party_stance.state_ramps.fear_start` and `fear_full` | 20 and 70 (unchanged) | Not tuned in phase D | 2 | `data/balance.json:3156` (block), `:3158` (`fear_start`). Existing keys. Combat reads them through one shared helper. | Sets where the fear ramp starts and ends. | Same ramp as the stage. No second fear threshold (design 2b). Not a new key. |

### 1c. Slice 3: Judgment scale on acceptance

| Key path | Proposed value | Range the probe may try | Slice | File | What it does | Why this value |
|---|---|---|---|---|---|---|
| `combat.movement.exposure_acceptance.judgment_floor` | 0.6 | Sweep list: 0.55, 0.6. Valid range 0.55 to 1 (D-83 B, test J9). | 3 | `data/balance.json`. Reader pending: `BehaviorArbiter.gd` (`_spatial_utility`). | Sets how much of the Directive acceptance a fully seasoned Echo keeps. | Jeff chose 0.55 to 0.6, start 0.6 (D-70 J4). 1.0 / 0.6 = 1.67, under the 2.0 budget (2a). |

### 1d. Slice 4: Directive stop cause

| Key path | Proposed value | Range the probe may try | Slice | File | What it does | Why this value |
|---|---|---|---|---|---|---|
| `actor.stop_short.directive.affinity.guard` | 1.0 | 0.8 to 1.0 | 4 | `data/balance.json`. Read by `StopShortService._directive_cause` (`:205`), called from the `directive` arm of `cause_strength` (`:117`). Same read pattern as `identity` (`:183`). | Sets how strongly the Directive favours a guard stop. | Guard is the main careful stop. Same value as the fear guard affinity (1.0, `:334`). Code clamps to 0..1. |
| `actor.stop_short.directive.affinity.hold` | 0.8 | 0.7 to 1.0 | 4 | same | Sets how strongly the Directive favours a hold stop. | Large, and below guard. 0.8 equals the anchor identity hold (0.8). So the Directive wins for a young Echo and identity wins later (2c, choice 1). |
| `actor.stop_short.directive.affinity.observe` | 0.3 | 0.2 to 0.4 | 4 | same | Sets how strongly the Directive favours an observe stop. | Small, as D-69 Q3 says. Scout observe is live up to Judgment 0.71 and gone above (2c, choice 3). |
| `combat.movement.directive_judgment.judgment_floor` (shared with acceptance; moved there from `actor.stop_short.directive`) | 0.6 | Sweep list: 0.55, 0.6. Valid range 0.55 to 1 (D-83 B). | 4 | same | Sets how much of the Directive stop strength a fully seasoned Echo keeps. | Same range as the acceptance floor (D-70 J4). A separate key, as the design says (A10). 1.0 / 0.6 = 1.67 (2a). |

Notes for the builder:
1. A missing `directive` block must give strength 0, not an error. Fixtures that override the `stop_short` block (`stop_short_override`) then stay unchanged.
2. `StopShortServiceTests.gd:108-121` reads the real config and pins identity keys only. New keys are additive and do not break it.
3. The three fixtures with their own `spatial_utility` (`MovementArbitrationTests.gd:1099`, `BehaviorArbiterTests.gd:1401`, `MovementStyleServiceTests.gd:520`) carry no `exposure_acceptance` block. The code must decide what a missing block means (see OPEN, A-N3).
4. Registry order breaks ties between causes (`StopShortService.gd:22`). Put the new row after `fear` and `identity` (choice 4).

---

## 2. Hand calculations

### 2a. Swing budget, three layers

Real shipped values (`data/balance.json`):

| Item | Line | Value |
|---|---|---|
| `identity_weight_scale.trait` / `.vector` | 1224-1225 | 0.35 / 0.35 |
| `directive_interpretation_mul.low` / `.high` | 1326-1327 | 0.75 / 1.30 |
| `interpretation_swing_max.value` | 1229 | 2.0 |
| `stop_short.identity.judgment_base` | 338 | 0.5 |

Convention (shipped test): swing = own-side multiplier at J = 1 divided by Directive-side multiplier at J = 1. Affinities are not in it.

| Layer | Own side at J = 1 | Directive side at J = 1 | Swing at floor 0.6 | Swing at floor 0.55 | Limit | Headroom at 0.6 |
|---|---|---|---|---|---|---|
| A. Action (shipped) | 1 + 0.35 = 1.35 | 0.75 | 1.35 / 0.75 = **1.800** | not a floor key | 2.0 | 0.200 |
| B. Acceptance | 1.0 (see below) | 0.6 | 1.0 / 0.6 = **1.667** | 1.0 / 0.55 = 1.818 | 2.0 | 0.333 |
| C. Stop cause | `0.5 + 0.5 x 1 = 1.0` | 0.6 | 1.0 / 0.6 = **1.667** | 1.0 / 0.55 = 1.818 | 2.0 | 0.333 |

Checks:

| Check | Arithmetic | Result |
|---|---|---|
| Layer B own side is 1.0 | `MovementStyleService.gd` has no Judgment read (grep found none). `style_inputs` (`BehaviorArbiter.gd:765-779`) has no Judgment key. | Design assumption A7 holds. |
| Lowest floor that passes | 1.0 / floor <= 2.0 gives floor >= 0.5 | At 0.5 the swing is exactly 2.00. No headroom. So the validator rejects a floor below 0.55 (D-83 B, test J9). |
| Cross pair (not a real pairing) | 1.35 / 0.6 = 2.25. Floor needed for 2.0: 1.35 / 2.0 = 0.675. | Above the D-70 range. The identity 1.35 only multiplies the action layer. Per-layer tests apply (design 3b). Named for Jeff. |
| Combined Directive pull of a seasoned Echo | Layer factors at J = 1: A 0.75 / 1.30 = 0.577; B 0.6; C 0.6. Terms add, they do not multiply. Smallest factor 0.577. | The seasoned Echo keeps at least 0.577 of the young pull in one decision. Ratio at most 1.73. |

### 2b. Fear lean integrity (design section 4, rule F6)

Rule F6 has three parts (D-83 A). Slope: `fear_lean_bound / (fear_full - fear_start) >= (1 - floor) x fear_pressure_weight x max abs(D) / 100`. Pre-start bound: `(1 - floor) x fear_pressure_weight x fear_start / 100 x max abs(D) <= 0.01`. Total bound (kept): `fear_lean_bound >= (1 - floor) x fear_pressure_weight x max abs(D)`.

Shipped values: slope 0.12 / 50 = 0.0024 >= 0.4 x 0.25 x 0.3 / 100 = 0.0003. Pre-start 0.4 x 0.25 x 0.2 x 0.3 = 0.006 <= 0.01. Total 0.03 (table below). The slope rule alone fails only below a bound of 0.015, not at 0.05. The total bound is kept so the test fails below 0.03.
`fear_pressure_weight` = 0.25 (`data/balance.json:1240`). `max|D|` = max(|-0.2|, |+0.3|) = 0.3.

| Case | Arithmetic | Needed | Bound 0.12 passes? |
|---|---|---|---|
| Floor 0.6, shipped Directives | (1 - 0.6) x 0.25 x 0.3 = 0.4 x 0.25 x 0.3 | 0.0300 | Yes. 0.12 / 0.03 = 4.0 times |
| Floor 0.55, shipped Directives | 0.45 x 0.25 x 0.3 | 0.0338 | Yes. 3.6 times |
| Floor 0.6, any tolerance 0 to 1 (`max|D|` = 0.5) | 0.4 x 0.25 x 0.5 | 0.0500 | Yes. 2.4 times |
| Floor 0.5, any tolerance (worst case; NOT allowed since D-83 B, shown as history) | 0.5 x 0.25 x 0.5 | 0.0625 | Yes. 1.9 times |

So the total bound is 0.03 at shipped values. For any tolerance it is 0.05 (the `max abs(D)` = 0.5 case at floor 0.6). The test limit is 0.03 at shipped values, not 0.05. The valid floor starts at 0.55, so the 0.0625 case cannot occur. The probe sweep starts at 0.06.

Seek stays hesitant, not banned (test F7, decision D-71). Lowest Seek acceptance for any J at full fear:

| Floor | `D_scaled` at J = 1 | Minus bound 0.12 | Result | Largest bound that keeps Seek at or above 0 |
|---|---|---|---|---|
| 0.60 | 0.3 x 0.60 = 0.180 | 0.180 - 0.12 | **+0.060** | 0.180 |
| 0.55 | 0.3 x 0.55 = 0.165 | 0.165 - 0.12 | **+0.045** | 0.165 |

F7 asks for acceptance above -0.05. Margin at 0.12: 0.06 + 0.05 = 0.11. The joint ceiling for both floors is 0.165. I propose 0.16 as the top of the probe sweep.

Check against the design table (floor 0.6; the illustrative weight 11 does not enter this line): seasoned and afraid Seek, J 0.675: scale = 0.6 + 0.4 x 0.325 = 0.730; `D_scaled` = 0.3 x 0.73 = 0.219; acceptance = 0.219 - 0.12 = +0.099. Matches the design.

### 2c. Directive stop strength

Formula: `strength = (1 - T) x affinity x scale(J)`, `scale(J) = 0.6 + 0.4 x (1 - J) = 1 - 0.4 J`. Cutoff `min_cause_strength` = 0.15 (`:328`).
Scale values: J 0.2 gives 0.92. J 0.5 gives 0.80. J 0.85 gives 0.66.
Base: Scout 1 - 0.3 = 0.7. Seek 1 - 0.8 = 0.2.

| Directive | Benefit | Base x affinity | J 0.2 (x 0.92) | J 0.5 (x 0.80) | J 0.85 (x 0.66) | Live up to J |
|---|---|---|---|---|---|---|
| Scout | guard | 0.7 x 1.0 = 0.700 | 0.644 | 0.560 | 0.462 | always (1.96) |
| Scout | hold | 0.7 x 0.8 = 0.560 | 0.515 | 0.448 | 0.370 | always (1.83) |
| Scout | observe | 0.7 x 0.3 = 0.210 | 0.193 | 0.168 | **0.139 (below 0.15)** | 0.71 |
| Seek | guard | 0.2 x 1.0 = 0.200 | 0.184 | 0.160 | **0.132 (below)** | 0.63 |
| Seek | hold | 0.2 x 0.8 = 0.160 | **0.147 (below)** | **0.128 (below)** | **0.106 (below)** | 0.16 |
| Seek | observe | 0.2 x 0.3 = 0.060 | **0.055 (below)** | **0.048 (below)** | **0.040 (below)** | never |

"Live up to J" = `(1 - 0.15 / (base x affinity)) / 0.4`. A result above 1 means the cell never dies.
Cells below 0.15: 8 of 18. Scout has 1 (observe at J 0.85). Seek has 7 (guard at J 0.85, hold at all three J, observe at all three J).

Stop bias = `stop_short_weight` 6.0 x strength. Scout guard: 3.86, 3.36, 2.77. Seek guard: 1.10, 0.96, gone. Fear at full strength gives 6.0.

Does it match the intent?

| Intent | Evidence | Result |
|---|---|---|
| Seek seldom stops | Only Seek guard lives, and only up to J 0.63. Largest Seek bias 1.10. Seek hold and observe never reach 0.15 at Standing 1 values. | Yes. The one live Seek cell is weak. Hold at J 0.2 misses by 0.003, so it is fragile (choice 1). |
| Scout stops more often | Scout has 3 live cells at J 0.2 and 0.5, and the guard bias is 3 to 4 times the Seek bias. | Yes. |
| A seasoned Echo stops for the Directive less | Live cells at J 0.2, 0.5, 0.85 are 3, 3, 2 for Scout and 1, 1, 0 for Seek. Scout guard strength falls 0.644 to 0.462 (-28%). Anchor guard identity (0.8 x (0.5 + 0.5 J)) rises 0.48, 0.60, 0.74. | Yes. The owner changes for anchor and sight Echoes. |

Limit to know. Scout guard and hold never die, even at J = 1 (guard 0.42, hold 0.34). An edge Echo (identity 0) keeps a Directive guard stop for ever under Scout. Its growth shows as a weaker stop (bias 3.9 to 2.5), not as a walk-on. Probe step 7 measures this (choice 3).

Crossing point, Scout guard 1.0 against anchor identity guard 0.8: `0.7 (1 - 0.4 J) = 0.4 + 0.4 J` gives J = 0.30 / 0.68 = 0.44. Hold 0.8: `0.56 (1 - 0.4 J) = 0.4 + 0.4 J` gives J = 0.16 / 0.624 = 0.26.

### 2d. Weight arithmetic (acceptance term)

Term = weight x acceptance x exposure. Exposure weight is -6.0 (`:1703`). Exposure is 0 to 1 (0.5 is possible, because `_exposure` divides edges by route length).

| Weight | Scout young calm (acc -0.184) | Seek young calm (acc +0.276) | Seek at J = 0, no fear (acc +0.30) | Gap Seek minus Scout at 1.0 exposure |
|---|---|---|---|---|
| 2 (control) | -6 - 0.37 = -6.37 | -6 + 0.55 = -5.45 | -5.40 | 0.92 |
| 8 | -7.47 | -3.79 | -3.60 | 3.68 |
| 11 | -8.02 | -2.96 | -2.70 | 5.06 |
| 14 | -8.58 | -2.14 | -1.80 | 6.44 |
| 17 (shipped, D-73) | -9.13 | -1.31 | -0.90 | 7.82 |

The columns above include the Judgment scale (acceptance -0.184 and +0.276). Slice 1 alone, before Judgment is in, gives Scout -0.2 and Seek +0.3.

Attractor limit: weight x 0.3 < 6.0 gives weight < 20. At 17 the product is 5.1, so the slope stays at -0.9. Safe for the shipped Directives (D-73).
A future Directive with tolerance 1.0 has acceptance +0.5. Then weight < 12. The shipped weight 17 is safe only for tolerance under 0.853 (0.5 + 6/17). History: 11 was safe for every tolerance from 0 to 1; 14 for tolerance under 0.929. Test C12 reads the shipped Directives. It must not read a synthetic Directive with tolerance 0.853 or more (D-73). The test `directive_cfg/exposure_acceptance_never_attractor` catches a new Directive that breaks the limit.

Concern. Combat-003 found this term first decides turns at a score move of 3 to 4 points (weight 15 to 20 x acceptance 0.2). The single-Directive score move here is weight x |acceptance|: Scout 17 x 0.184 = 3.1; seasoned Scout 17 x 0.132 = 2.2. This is at the low edge of 3 to 4 for a young Scout and below it for a seasoned one. The Scout-to-Seek gap (7.82) is above it. So the contrast between Directives may show, but a Scout route change alone may be rare. The D-73 probe found 2 changed Scout moves of 384 at weight 17.

---

## 3. Expected change per slice

The fingerprint suites run Scout (the default Directive on a fresh save, `FlowSnapshotFingerprintTests.gd:250`). Recorded constants that can move: the `fingerprint_*` suites in `AGENTS.md` (`fingerprint_combat`, `fingerprint_determinism_*`, and the per-mode fingerprints), and the baseline suites that hash combat (`CombatBaselineTests`, `CombatMaturityBaselineTests`; the builder confirms which hold hashes). I read only `FlowFingerprintTests.gd` for this note.

"Largest score move" is the bound for the attribution agent. A moved value that needs a larger score move than the bound has another cause. The slice stops (design rule 3).

| Slice | Cause | Largest score move on one candidate (weight 17, D-73) | Calculation | Can Scout hashes move? | Probe the main chat runs |
|---|---|---|---|---|---|
| 1 | Map and weight | Scout: 3.4 (more costly). Seek: 4.7 (less costly). | Scout 17 x 0.2 x 1.0 = 3.4 (old term 0). Seek 17 x 0.3 - 2.0 x 0.2 = 5.1 - 0.4 = 4.7. | Yes. Any Scout route choice between options with different exposure and a score margin under 3.4. | Step 6: sweep 0, 2, 8, 11, 14, 17, 19, count changed route choices (done; D-73). Then the fingerprint re-record. |
| 2 | Fear lean | 2.04 (more costly, any Directive) | 17 x 0.12 x ramp 1.0. At fear 45 the ramp is 0.5, so 1.02. | Only if a fixture holds an Echo with `max(fear, fear_base)` above 20. Birth `fear_base` is clamped 0 to 20 (`:235`), so a calm start gives zero. "No move" is a valid result. | Step 9: fear 0, 20, 45, 70, lean on and off. Then the re-record, run to prove "no move". |
| 3 | Judgment scale | Scout: 1.36 (less costly). Seek: 2.04 (less bold). | Scout 17 x 0.2 x (1 - 0.6) = 1.36 at J = 1. Seek 17 x 0.3 x 0.4 = 2.04. At J 0.2 to 0.5 the Scout move is 0.27 to 0.68. | Yes, but small. A route choice needs a margin under 0.3 to 1.4. Most fixtures with J above 0 are touched. A fixture without `judgment` reads 0.3 by default (design J8). | Steps 3 and 10: real J per Standing, scale on and off for Standing 1, 6, 9. Then the re-record. |
| 4 | Directive stop cause | Scout: 4.2 at J = 0 (guard). Seek: 1.2. | Scout 6.0 x 0.7 x 1.0 x 1.0 = 4.2. At J 0.2: 3.86. Seek 6.0 x 0.2 = 1.2. | Yes. The biggest move. It needs a stop plan (guard, hold or observe) that passes the vetoes and is not an excluded purpose. Fixtures with stop-short off do not move. | Step 1 first (stop if 0 route changes), then steps 2, 4, 5, 7. Then the re-record. |

Order and rules are in design section 10. No two slices land together. Each re-record is saved, checked with `cmp`, and attributed by an `opus` agent.

---

## 4. Existing comments and notes that become false

I do not edit these. The builder or I edit them in the slice named. Row 6 already holds the Seek 0.20 note and row 15 already holds the combat-003 pointer; both are marked in the Status text.

| # | Where | Text now | Why it is false after phase D | When |
|---|---|---|---|---|
| 1 | `data/balance.json:1696`, trap (1) in `_comment_spatial_utility` | "directive_exposure_acceptance_weight is DELIBERATELY INERT ... on the default directive.scout_carefully the term is 0.0 at ANY weight. Raising this number alone can change nothing." | Scout acceptance is -0.2. The weight is live. | Slice 1 **Status: FIXED in slice 1.** |
| 2 | same line, same trap | "the term is weight x directive.intent_weights.exposure_acceptance x exposure" | The term is `weight x acceptance x exposure`. Acceptance comes from `exposure_tolerance` minus the offset (then fear lean, then Judgment scale). The old key now serves action choice only (D-69 Q2). | Slice 1, again at 2 and 3 **Status: FIXED in slice 1. FIXED in slice 3 (the builder fixed the config comment).** |
| 3 | same line, trap (2) | "exposure is binary in a fight ... a flat penalty on a boolean, not a slope" | Probably still true. The design says "slope". Exposure may be 0, 0.5 or 1. I did not verify. Mark it "check", not "false". | Slice 1 (check) **Status: FIXED in slice 1 (the new comment says exposure is a fraction).** |
| 4 | `data/balance.json:1696` end | "All values PROPOSED DEFAULT" and the sweep pointer to combat-003 section 22 | Not false. The weight is a new, probe-measured value. Add a pointer to the phase D probe. | Slice 1 **Status: FIXED in slice 1 (the comment cites D-73).** |
| 5 | `data/balance.json:30-31` and `:65-66`, `_comment_exposure_tolerance` | "Read by StagePartyStance; bent by data.stages.party_stance (D-05)." | Combat now reads it too (acceptance, stop cause). Combat does not use the stage bend. D-05 is amended (D-69 Q2). | Slice 1 and 4 **Status: FIXED in slice 4 (both `_comment_exposure_tolerance` strings name the stop cause).** |
| 6 | `data/balance.json:47`, Seek `intent_weights.exposure_acceptance` 0.20 (no comment now) | No comment. | Not false. Add a note: this key serves action choice only. `_directive_bonus` still reads it. | Slice 1 **Status: NOT FIXED. The builder fixes it later, because a running test reads `data/balance.json`. It is the Seek `intent_weights.exposure_acceptance` 0.20 note: the key now serves action choice only.** |
| 7 | `data/balance.json:325`, `stop_short._comment` | "Starting values; the designer sets every number ... Fear and low morale favour guard only." | The block has a third cause (Directive) with its own sub-block. The sentence about guard only is true for fear and morale. Add the third cause. | Slice 4 **Status: FIXED in slice 4 (`stop_short._comment` names the Directive cause).** |
| 8 | `data/balance.json:1223`, `identity_weight_scale._comment` | "the two halves of ONE budgeted axis" and "Paired with directive_interpretation_mul" | Three layers use the same budget. Layers B and C have their own floors. | Slice 3 and 4 **Status: FIXED in slice 4 (the comment names the shared `data.combat.movement.directive_judgment` block).** |
| 9 | `data/balance.json:1228`, `interpretation_swing_max._comment` | "The declared budget on the identity:directive ratio" and one config-integrity test in `BehaviorArbiterTests.gd` | Three tests now read this value (layers A, B, C). The two new tests live in other files. | Slice 3 and 4 **Status: FIXED in slice 4 (the comment names the shared `data.combat.movement.directive_judgment` block).** |
| 10 | `data/balance.json:1325`, `directive_interpretation_mul._comment` | Describes the action layer as the only Directive-Judgment curve. | Two more curves exist (acceptance, stop cause). They use a separate linear form, by design (F1 over F2). | Slice 3 and 4 **Status: FIXED in slice 4 (the comment names the shared `data.combat.movement.directive_judgment` block).** |
| 11 | `data/balance.json:3157`, `state_ramps._comment` | "fear is the Echo's current fear on the actor view." | Combat reads `max(fear, fear_base)` (assumption A8). Combat also shares the two ramp keys. | Slice 2 |
| 12 | `data/balance.json:3109`, `bounds._comment` and `:3122`, `leans._comment` | Stage-only wording about the fear lean on `exposure_tolerance`. | Not false. Add a pointer: combat has its own bound (`fear_lean_bound`). | Slice 2 |
| 13 | `design.md:31`, `design.md:320`, D-09 and test C14 | "stage config never enters combat" | Narrowed: only `state_ramps.fear_start` and `fear_full` are shared (assumption A9). Docs, not config. | Slice 2 |
| 14 | `core/directives/DirectiveService.gd:93` | Code fallback registry holds `exposure_acceptance` 0.20. | Not false. Same note as row 6. Code, not config. | Report only |
| 15 | `docs/stories/v2-combat-003/handoff.md` section 22 | Records the weight as inert and the first decisive weight as 15 to 20. | Old measurement. It stays true as history. Add a pointer from the new probe. | Slice 1 **Status: FIXED now: pointer note added in `handoff.md` section 22.4.** |
| 16 | `docs/stories/v2-directive-002/decisions.md`, D-05 | "Combat phase D can feed the same key into `directive_exposure_acceptance`." | Amended by D-69 Q2: `exposure_tolerance` drives movement; `intent_weights.exposure_acceptance` stays for action choice, so two exposure inputs remain. | **Status: FIXED now** (line appended under D-05). |

---

## 5. Choices for Jeff

Pillar: Echoes grow, and their behaviour changes over time. The choices below say how much growth the player can see in movement and stops.

### Choice 1. Hold affinity: 0.8 or 1.0

| Option | Effect |
|---|---|
| A. 0.8 (proposed) | A hold stop beats an anchor identity hold for a young Echo only up to J 0.26. Seek hold is live only below J 0.16, so it is nearly dead and fragile (0.147 at J 0.2). |
| B. 1.0 | Hold equals guard. The crossing is at J 0.44, a mid-career Echo. Seek hold is live up to J 0.63, so Seek stops more. |
| C. 0.9 | Crossing near J 0.35. Seek hold live up to J 0.40. |

Advice: A. It keeps hold below guard and keeps Seek quiet (D-70 J5). The Directive owns the stop only for a very young Echo, so growth shows early. Pick B if you want the owner swap to happen at Standing 5 to 6 instead of Standing 2 to 3. Probe step 4 shows the real J per Standing first.

### Choice 2. What if weight 14 still changes few routes (history: Jeff chose weight 17, D-73)

| Option | Effect |
|---|---|
| A. Accept (advice) | Movement contrast shows mainly between Directives (Scout to Seek gap of 6.4 points). The stop cause carries the within-Directive contrast. |
| B. Raise the cap to 17 (chosen, D-73) | Seek at J = 0 has slope 6 - 17 x 0.3 = -0.9. Still a cost, with 0.9 margin. A tolerance-1.0 Directive would break (17 x 0.5 = 8.5 above 6). |
| C. Change `exposure_weight` (-6.0) | Moves every Echo and every Directive. Out of scope for phase D. Advise against. |

Advice: A. The probe step 6 counts changed routes. Decide B only if the count is near 0 at 14. B is Jeff's decision (D-70 set 8 to 14). Result: Jeff chose B on 2026-10-16 (D-73).

### Choice 3. Edge Echo growth, Directive floor and observe affinity

Edge Echoes have zero identity stops. Under Scout they keep a Directive guard stop at every Standing (strength 0.46 at J 0.85, never gone). Their growth shows as a weaker stop.

| Option | Effect |
|---|---|
| A. Floor 0.6, observe 0.3 (proposed) | Scout observe disappears above J 0.71. Guard and hold stay. Smallest risk to the budget (1.67). |
| B. Floor 0.55 | Scale at J 0.85 is 0.618 (not 0.66). Guard 0.433. A 6% weaker stop. Swing 1.82. Still inside 2.0. |
| C. Observe 0.25 | Scout observe disappears above J 0.36. A Standing 6 Scout Echo no longer observes for the Directive. More visible change. |

Advice: A now. Probe step 7 shows if edge growth is visible. If it is not visible, move to B first (it needs no approval, since D-70 allows 0.55). Do not go under 0.55 without Jeff (budget 2.0).

### Choice 4. Tie order: where the Directive row sits in the registry

| Option | Effect |
|---|---|
| A. After fear and identity (advice) | On a tie the Echo's own cause wins. The Directive never beats an own cause by order alone. Fits "own causes take over". |
| B. First | On a tie the Directive wins. A seasoned Echo would still obey on ties. Against the pillar. |

Advice: A. A tie is rare (strict greater-than). It costs nothing.

---

## OPEN — questions and assumptions

ASSUMED: A-N1. The probe sweep lists were 2, 8, 11, 14 for the weight (the first design list; the real sweep covered 0, 2, 8, 11, 14, 17, 19 and D-73 set 17), 0.06, 0.12, 0.16 for fear lean, and 0.55, 0.6 for both floors. | WHY: They match design section 8 and D-70/D-71. The fear ceiling 0.16 comes from 2b (0.165 at floor 0.55). | WRONG IF: Jeff wants a wider fear sweep. Above 0.165 a frightened seasoned Seek Echo can go negative (the O1 option B that D-71 rejected).

ASSUMED: A-N2. Affinities guard 1.0, hold 0.8, observe 0.3 are the design's illustrative values (design 2c table), now adopted as the proposal. | WHY: They give the intended contrast (2c). I found no better anchor. | WRONG IF: Jeff takes choice 1 (hold 1.0 or 0.9) or choice 3 (observe 0.25). Then the tables in 2c change.

ASSUMED: A-N3. A missing `exposure_acceptance` block (old fixtures, and the three test configs at `MovementArbitrationTests.gd:1099`, `BehaviorArbiterTests.gd:1401`, `MovementStyleServiceTests.gd:520`) means "keep the shipped formula" or "acceptance 0". I did not decide which. | WHY: This is a code shape, not a number. | WRONG IF: `mechanics-developer` finds the fixtures need the block. That is a test edit, so it goes to the builder with a report.

ASSUMED: A-N4. The shipped Seek `intent_weights.exposure_acceptance` 0.20 and the old Scout value 0 are replaced for movement by the map (Scout -0.2, Seek +0.3). Seek acceptance therefore also moves (0.2 to 0.3), even though the fingerprint suites run Scout. | WHY: D-69 Q1 and design 2a. | WRONG IF: Jeff wants Seek unchanged. Then the map is not the same formula for both Directives.

ASSUMED: A-N5. Design key names are used as written. `exposure_acceptance.offset`, `.judgment_floor`, `.fear_lean_bound`, `stop_short.directive.affinity.{guard,hold,observe}`, `stop_short.directive.judgment_floor`. | WHY: Section 6 of the design is clear. | WRONG IF: none known. One thing is unclear: `judgment_floor` is the name of two keys in two blocks. That is deliberate (A10). It may confuse a grep. Say so if you want `acceptance_judgment_floor` and `stop_judgment_floor`. I did not invent new names.

ASSUMED: A-N6. The shipped movement loader accepts a new dictionary sibling of `spatial_utility` under `combat.movement`. | WHY: `capacity`, `hazards`, `pressure` and `slack` are already sibling dictionaries, and `ConfigService.gd:494` reads a subtree by path. I did not find a closed key list for `movement`. | WRONG IF: A validator rejects unknown siblings. Same as design A3.

ASSUMED: A-N7. The exposure value is a fraction (0, 0.5, 1) and the design word "slope" is loose. | WHY: The `_comment` at `:1696` says exposure divides edges by route length, but also says "binary". I did not trace `_exposure`. | WRONG IF: `_exposure` is strictly 0 or 1. Then no number changes. Only row 3 of section 4 needs a wording fix.

BLOCKED: none. The numbers can start at slice 1 now. The final weight needs probe step 6. The final fear bound needs probe step 9. The final floors need probe steps 3 and 10. The final affinities need probe steps 1, 4 and 7.

BLOCKED (carried, not new): Q6, player text for the Directive stop cause | CHECKED: D-69, D-40 item 4 | NEED: Jeff's wording after the code exists.
