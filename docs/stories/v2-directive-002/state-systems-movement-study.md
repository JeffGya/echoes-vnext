# V2-DIRECTIVE-002: study of felt state effects on combat movement

Author: `sr-game-designer`, 2026-10-17. Design study only. It decides nothing.
It edits no code and no data. It proposes no player text. Every number marked PROPOSED DEFAULT goes to `mid-game-designer`.
Written in ASD Simplified Technical English (STE).
Trigger: D-81 (Jeff): "we want fear, judgement, moral and other systems to actually have an effect."
Starts from `exposure-lever-study.md` and the D-80 count.

## 0. Summary

1. Fear, morale, Judgment and Standing already enter route scoring. Their effect on the chosen route is small. The Directive exposure term and the fear lean decide 0 or 1 of about 260 decisions per arm (D-80).
2. The cause is not only the exposure input. Route choices in these fights are **close**. The median gap between the best and second-best route is 1.4 points. 88 percent of gaps are under 3 points. So a state term of 1 to 2 points can flip a choice, if it acts on **every** option and not only on exposed ones.
3. The state terms that act on every option are tiny (style alignment, about 0.45 points on average, 2.1 at most). The terms that decide most choices are cohesion and progress. **No state system scales them.**
4. The options also lie close together in space. In 64 percent of decisions the best and second-best route end 1 cell apart. 20 percent end on the same cell. A flip between them moves the Echo 1 cell. A player sees that only as a repeated habit, not as one event.
5. The state terms that make a **large** spatial difference are absent. In about 4,100 logged route options there is **no** `withdraw`, `regroup` or `reposition` goal. The `retreating` style and the fear and morale tables for it wait for goals that do not exist. Goal generation reads Health only (`CombatPressureService.gd:409`). It does not read fear or morale.
6. Standing already has one felt movement effect: step capacity 2, 3, 4 at Standing 1, 3, 6 (`data.combat.movement.capacity.standing_bands`). Fear and morale do not touch step capacity.
7. Advice: build **state-scaled pull** (progress and cohesion weights lean with fear and morale) and a **fear and morale step budget**. Both are small code, mostly config, proven by unit tests and the 30-second boards probe. Send the goal-level fall-back to V2-COMBAT-004 (D-07 already gives that story the `regroup` and `reposition` goal sources). No new fight probe is needed.

## 1. Inventory

### 1.1 Where each state system enters a combat decision today

"Action" means the choice between plan types (attack, guard, move, idle). "Route" means the choice between route options of one plan. Points are score points. Margin data are in section 1.2.

| System | Where it enters | Level | Size in points | Reaches the route choice? |
|---|---|---|---|---|
| Fear | `BehaviorArbiter.gd:1674-1676` (`max(fear, fear_base)`), `:1736-1742` (`fear_factor`, damped by composure; passive actions exempt) | Action | Factor 0.77 to 0.85 on active actions at fear 50 (my calculation from `fear_active_dampen` 0.45). About -12 on a score near 80. | No. Same factor on all route options of one plan. |
| Fear | `BehaviorArbiter.gd:1805-1825` (Calling fear signatures, `fear_move_bonus` 12 per 10 fear for Kra Soro) | Action | Up to about 15 | No |
| Fear | `BehaviorArbiter.gd:776` into `MovementStyleService.gd:165-166` (`fear_weight` x fear/100 x `alignment_weight` 0.06, damped by urgency) | Route | At fear 50: careful +0.66, low_exposure +0.72, forceful -0.42. At fear 100: 1.44 at most. | Yes, but small |
| Fear | `BehaviorArbiter.gd:698`, `:1402-1408`, `:1459` (fear lean on exposure acceptance, bound 0.12) | Route | Up to 2.0 on **exposed** options only | Only 1 to 4 percent of options are exposed (section 1.3) |
| Fear | `StopShortContextService.gd:360-361`, `StopShortService.gd:125` (fear cause, floor 20, full 45, guard affinity 1.0, weight 6.0) | Route (stop-short) | Up to 6.0 on a stop-short route | Not measured. A stop-short route needs no hostile in reach and a benefit. |
| Fear | `MaturityExpressionService.gd:202` (fear lowers Judgment, weight 0.25) | Both, indirect | Moves Judgment by up to 0.25 | Only through the Judgment terms below |
| Morale | `BehaviorArbiter.gd:1746-1749` (`morale_action_muls`: move -20 broken, -3 shaken, +10 inspired; guard +20 broken) | Action | 3 to 20 | No. Same on all route options of one plan. |
| Morale | `BehaviorArbiter.gd:777` into `MovementStyleService.gd:168-170` (`morale_bias`, 5 to 10 raw, x 0.06) | Route | 0.3 to 0.6 | Yes, but small |
| Morale | `StopShortContextService.gd:362` (broken morale cause strength 0.8) | Route (stop-short) | Up to 4.8 | Not measured |
| Judgment (from Standing) | `BehaviorArbiter.gd:1717-1723` (identity scale 1.0 to 1.35), `:1878-1893` (`directive_interpretation_mul` 1.3 to 0.75) | Action | Scales trait and vector bonus and Directive bonus | No. Same on all route options of one plan. |
| Judgment | Slice 3 (D-70 J2 C, in build): scale on the Directive part of exposure acceptance, floor 0.6 | Route | At most 40 percent of 17 x 0.3 = 2.0 points, on exposed options only | Only 1 to 4 percent of options |
| Judgment | `StopShortService` identity cause (`judgment_base` 0.5, rises with Judgment) | Route (stop-short) | Not measured | Not measured |
| Standing | `data.combat.movement.capacity.standing_bands` (2, 3, 4 steps at Standing 1, 3, 6) | Option set | +1 cell per band | **Yes. This is felt.** It changes which cells exist. |
| Standing (band) | `BehaviorArbiter.gd:1767-1790` (Grounded+ Calling multipliers), `:1796-1802` (Forming+ wound chase), `refusal_thresholds_by_band` 65 / 80 / 88 / 95 | Action and refusal | Several points to 15 | No |
| Vectors, traits | `BehaviorArbiter.gd:1691-1702` (action layer); `MovementStyleService.gd:156-160` `vector_bias`, `trait_nudge` (route) | Both | Route: up to about 2 | Yes, small |
| Calling | `BehaviorArbiter.gd:1668-1670` (base table), `:1768-1790` (`calling_mul`); `MovementStyleService.gd` `calling_family_bias` 6.0 raw = 0.36 points | Both | Route: 0.36 | Yes, small |
| Calling (leader) | `BehaviorArbiter.gd:821-825` (`cover_move_bonus`, Whole leader teaches allies to end behind terrain) | Route | Config-led | Yes, if a cover cell exists. Not measured. |
| Bonds | `BehaviorArbiter.gd:852`, `:2040-2063` (`_apply_bond_bias`: friend +12, rival -10) | Action (`protect_ally` only) | 10 to 12 | No |
| Bonds | `BehaviorArbiter.gd:2109-2123` into `MovementStyleService.gd:172-173` (`bond_weight` 8 to 10 x 0.06) | Route | 0.5 to 0.6 | Yes, only for the goal subject. Small. |
| Vow | `BehaviorArbiter.gd:850`, `:2016-2032` (party under 3: fear bias 6.0); style `vow_ward_weight` | Both | 0.5 to 6 | Partly |
| Leadership traits | `BehaviorArbiter.gd:1565-1620` | Action and route | Config-led | Not measured |

Reading:

- Every large state term (3 to 20 points) works at the **action** level. It does not choose between routes.
- Every state term at the **route** level is under about 2 points, except the stop-short causes (up to 6).
- The only state effect that is certain to be felt today is Standing through step capacity.

### 1.2 Margin between the best and second-best route (Echo decisions)

Source: `par/*.out`, 4 arms (Scout calm, Seek calm, Scout fear 50, Seek fear 50), `TURNSUM` lines. 1,037 Echo passes. The margin is defined only for passes with two or more route options (795 passes, 77 percent).

| Count | Passes | Share of the 795 | Share of all 1,037 passes |
|---|---:|---:|---:|
| No route option | 80 | | 7.7 percent |
| One route option (no choice among routes) | 162 | | 15.6 percent |
| Two or more route options | 795 | 100 percent | 76.7 percent |
| Margin under 0.3 | 92 | 11.6 percent | 8.9 percent |
| Margin under 1 | 289 | 36.4 percent | 27.9 percent |
| Margin under 3 | 703 | 88.4 percent | 67.8 percent |
| Margin under 10 | 752 | 94.6 percent | 72.5 percent |
| Margin 10 or more | 43 | 5.4 percent | 4.1 percent |

Quantiles of the margin: 25 percent 0.64, median 1.42, 75 percent 2.10, 90 percent 3.59.
Per arm the shares are within 3 points of these (under 1: 35 to 38 percent; under 3: 87 to 90 percent).

Reading: a term of 1 point can flip about one choice in three. A term of 3 points can flip nearly nine in ten, **if it differs between the options of that decision**.

### 1.3 Which terms can move a route choice today

Same data. Two numbers per term.

- **Spread:** the difference between the highest and lowest value of the term across the options of one decision. A term flips a decision only if its spread is larger than the margin.
- **Removal flips:** the number of decisions where the winner changes if the term is taken out of the score (first-order only: no later turns change).

| Term | Decisions with spread over 0.05 | Median spread | Spread above margin | Removal flips (4 arms, of 795) |
|---|---:|---:|---:|---:|
| objective progress | 729 (92 %) | 1.75 | 515 | 163 (20 %) |
| cohesion | 591 (74 %) | 1.0 | 409 | 284 (36 %) |
| style alignment (all identity and state in it) | 784 (99 %) | 0.74 | 262 | 71 (9 %) |
| commitment | 722 (91 %) | 0.27 | 138 | 35 (4 %) |
| congestion | 591 (74 %) | 0.25 | 107 | 31 (4 %) |
| Directive ally protection | 437 (55 %) | 1.6 | 262 | 1 (0.1 %) |
| Directive interception | 442 (56 %) | 2.0 | 331 | 58 (7 %) |
| **exposure (base + Directive acceptance)** | **26 (3 %)** | **0.0** | **9** | **5 (0.6 %)** |

Reading:

- Cohesion and progress decide most route choices. No state system scales either.
- Style alignment is present in 99 percent of decisions. It decides 9 percent of them. It holds **all** identity and state routes together (vector, trait, Calling, fear, morale, bond, vow). Fear and morale are a small part of it. A fear 50 arm shows the same style flips as a calm arm (Scout 18 against 16, Seek 15 against 22; no trend).
- Exposure is the smallest lever by reach (3 percent of decisions). That agrees with D-80.

### 1.4 How far apart are the options

Distance between the end cells of the best and second-best route (cells, Chebyshev, from the option id).

| Distance | Decisions | Share |
|---|---:|---:|
| 0 (same end cell, different path or shape) | 161 | 20 % |
| 1 | 510 | 64 % |
| 2 | 111 | 14 % |
| 3 or more | 13 | 1.6 % |

When cohesion is raised by 50 percent (a test re-score), 38 of the 46 changed winners move 1 cell and 8 move 2 cells.

Reading: **small terms on the route level give small spatial changes.** They can make a *habit* (always one cell nearer the group). They cannot make an event. A felt state effect needs either a repeated habit the observer can learn, or a large change (step length, goal, stop).

### 1.5 Offline re-score: how many choices would move

I re-scored the logged options with a changed weight. No game run was needed. Method: new score = logged score + (m - 1) x logged term. The winner is the highest new score. First-order only: the later turns are not replayed, the 0.12 gate is not applied, and the stage cap (28) is ignored. Each row assumes the multiplier acts at **full strength on every Echo**. That is the ceiling, not the expected value.

| Change (m = multiplier on the weighted term) | Decisions changed (of 768 with a chosen route and 2+ options) | Share of all 1,037 passes |
|---|---:|---:|
| cohesion x 1.25 | 28 (3.6 %) | 2.7 % |
| cohesion x 1.5 | 46 (6.0 %) | 4.4 % |
| cohesion x 2.0 | 59 (7.7 %) | 5.7 % |
| cohesion x 0.5 | 113 (14.7 %) | 10.9 % |
| progress x 0.75 | 39 (5.1 %) | 3.8 % |
| progress x 0.5 | 75 (9.8 %) | 7.2 % |
| progress x 1.25 | 54 (7.0 %) | 5.2 % |
| progress x 1.5 | 86 (11.2 %) | 8.3 % |
| style alignment x 1.5 (added on top) | 22 (2.9 %) | 2.1 % |
| style alignment x 2.0 | 44 (5.7 %) | 4.2 % |
| afraid: progress x 0.75 and cohesion x 1.5 | 60 (7.8 %) | 5.8 % |
| afraid: progress x 0.6 and cohesion x 2.0 | 92 (12.0 %) | 8.9 % |
| bold: progress x 1.25 and cohesion x 0.8 | 84 (10.9 %) | 8.1 % |
| bold: progress x 1.4 and cohesion x 0.7 | 130 (16.9 %) | 12.5 % |

Compare: exposure terms today decide 5 of 795 (0.6 percent).

### 1.6 What I could not measure

| Gap | Why | What would settle it |
|---|---|---|
| Margin between the best **route** and the best **stationary** option (attack in place, guard, idle) | The `TURNSUM` margin covers route candidates only. 131 of 1,037 passes (12.6 percent) were won by a non-route option. Their scores are not logged. | A print-only addition to the parts log |
| Effect of the stop-short causes (fear, morale, identity) on the 1,037 passes | No `DECISION` line carries the stop bias. No option id contains "stop". | Same log addition |
| Fear alone inside style alignment | Style is logged as one sum. | Same log addition |
| How many options end on a cover cell (`is_cover_destination`) | Not logged. | Same log addition |
| How many options end inside hostile reach | Not logged. Exposure counts controlled **edges on the path**, not the threat at the end cell. | Same log addition |
| The effect of a step-capacity change | Capacity changes the option set. The logs cannot be re-scored for a new set. | A unit test and the boards probe |
| Fights outside the 7 fixed fights | The probe plays 7 fights. 5 Echoes each. Purposes seen: engage, protect, intercept, advance, cut_off, pursue, hold. | Real stage play |

One more caution. The fear 50 arms set fear on every Echo from round 1. A round-1 comparison of the chosen option, calm against fear 50, shows 1 of 29 combat-type decisions changed for Scout and 0 of 29 for Seek (guide-spirit fixture: 1 of 5 and 3 of 5). With the existing terms, fear 50 changes about 5 of 68 round-1 decisions (7 percent), nearly all in one fixture. This is a weak sign that fear is felt a little in one fixture and not elsewhere.

## 2. The gap

"Flips" below means removal flips in section 1.3 where a measure exists.

| System | Visible today? | Share of decisions it flips | Cause |
|---|---|---|---|
| Fear (route) | No | Lean: 0 of 1,207 (D-77). Style part: not separable, below 9 percent. | Input too rare for the lean (exposed options 3 percent). Term too small for style fear (about 0.7 points at fear 50). |
| Fear (action) | Probably yes | Not measured | Term large (about -12), but it is the same on every route option, so it cannot change a route. |
| Morale (route) | No | Not separable, below 9 percent | Term too small (0.3 to 0.6 points) |
| Morale (action) | Probably yes | Not measured | Large (3 to 20), action level only |
| Judgment (route) | No | 0 today. Slice 3 will reach 1 to 4 percent of options at most. | Input too rare (exposure only) |
| Standing | **Yes** | Every pass (capacity) | Changes the option set |
| Vectors, traits, Calling (route) | Weak | 9 percent together with the rest of style | Term small (about 0.4 to 2 points) |
| Bonds (route) | No | Not separable | Term absent for most options (only the goal subject), small (0.6) |
| Vow (route) | Not measured | Not measured | Not measured |
| Retreat or regroup behaviour | **No, cannot happen** | 0 | **Term absent.** No fall-back goal exists unless Health collapses. |

Three causes, in order of importance:

1. **Term absent (goal level).** Nothing in state creates a different *intention* (fall back, regroup, hold the line). Without a different goal the options are all "engage, one cell here or there".
2. **Term absent (on the deciding terms).** Cohesion and progress carry the route choice and nothing scales them.
3. **Input too rare.** Exposure applies to 3 percent of options. A weight cannot fix that (D-73, D-80).

## 3. Options

Groups: (a) make an existing term act on more decisions, (b) add a state term where none exists, (c) change content, not code.

Common rules for every option (PROPOSED DEFAULT, for Jeff):

- **Identity at the neutral point.** Every new lean is exactly 0 at steady morale (50 to 74) and at fear below `fear_start` (20). Then Standing 1 calm fixtures do not move. Recorded values move only where state is not neutral.
- **Echo only.** Enemies and the keeper trial keep plain weights (as D-75, Q6 of the earlier study).
- **Combat owns its numbers.** The stage bounds never enter combat (D-09, test C14). New keys sit in `data.combat.movement`, in a block beside `exposure_acceptance`. No Directive id appears in `core/` (ANSWERS #81). No tunable is hard-coded (ANSWERS #83).
- **Composure softens fear.** The seasoned Echo keeps its nerve better. Reuse the shipped `composure` value (`BehaviorArbiter.gd:336`, `composure_dampen_scale` 0.4). The fear part of a lean is multiplied by `1 - 0.4 x composure`. This is how growth shows in a frightened Echo (see question Q3).
- **Swing budget.** `interpretation_swing_max` (2.0) measures the identity-to-Directive ratio. A state lean that is not scaled by Judgment and not a Directive term does not enter it. A lean scaled by Judgment does (option B4).

### (a) Make an existing term act on more decisions

#### A1. State-scaled pull (progress and cohesion)

| Item | Content |
|---|---|
| Change | `cohesion_weight` and `objective_progress_weight` are multiplied per Echo by a lean. Afraid: cohesion up, progress down. Bold (inspired morale): progress up, cohesion down a little. New config block, for example `data.combat.movement.state_lean`: bounds per term (PROPOSED DEFAULT: progress 0.6 to 1.4; cohesion 0.8 to 1.5), the fear ramp reuses `stages.party_stance.state_ramps` `fear_start` and `fear_full` (as the fear lean does), morale uses the tier from `EmotionService.get_morale_tier`. Code: about 15 lines in `_spatial_utility` plus two arguments from the movement loop (`BehaviorArbiter.gd:809-816`). |
| Touches | All route options of non-neutral Echoes. Ceiling from section 1.5: 5.8 percent of passes for the afraid pair, 8.1 percent for the bold pair at the PROPOSED DEFAULT ends. 9 to 12.5 percent at the stronger ends. |
| Observer sees | A frightened Echo ends its move nearer to its allies and closes less ground on the enemy. An inspired Echo pushes further and drifts from the group. Over several rounds this reads as a habit: "she stays with the others", "he runs ahead". |
| Risk | (1) Progress is the anti-stall term. A progress multiplier below 0.6 can make a frightened Echo stand still. Keep the floor and keep the objective urgency term unscaled. (2) Double count with fear in style (`fear_weight` on `cohesive` 8): small (0.5 points at fear 100); keep both, or drop the style row. (3) Swing budget: no, if not scaled by Judgment. (4) D-09: no stage key read. (5) Hashes: move only where fear or morale is non-neutral. Which fixtures set fear or morale is not known (see section 1.6). (6) With Scout and Seek fingerprints: the lean is Directive-blind, so both move together in non-neutral fixtures. |
| Pillar fit | Good. Emotion shows in movement, growth shows through composure. Observer effect is a habit, not an event. |

#### A2. Raise style alignment weight

| Item | Content |
|---|---|
| Change | `data.actor.movement_style_weights.alignment_weight` from 0.06 to about 0.1. Config only. |
| Touches | 99 percent of decisions. Re-score: x2.0 changes 5.7 percent of the multi-option decisions (4.2 percent of passes). |
| Observer sees | More identity contrast (vector, trait, Calling) and a little more fear and morale. Mostly identity, not state. |
| Risk | The value was lowered from 0.1 to 0.06 by decision #33 because style outranked a chase. All combat fingerprints move. Identity, not state, grows most. |
| Pillar fit | Medium for identity, weak for state. |
| Advice | Do not do this for this goal. |

#### A3. Cover preference from fear

| Item | Content |
|---|---|
| Change | Reuse `BoardAssessmentService.is_cover_destination` (`BehaviorArbiter.gd:821`). Today only a Whole leader's `cover_move_bonus` uses it. Add a **self** cover bonus scaled by the fear ramp: `cover_self_bonus x fear_ramp x (1 - 0.4 x composure)`. New config key `cover_self_bonus` (PROPOSED DEFAULT 1.5 to 3.0). Code: about 8 lines. |
| Touches | Options that end behind terrain. **Not measured.** Needs non-walkable cells between the end cell and the nearest hostile (the board has no sight system). |
| Observer sees | A frightened Echo ends its move behind an obstacle. Clear, easy to read, if cover exists. |
| Risk | May reach very few decisions, as exposure did. Measure the count before building (one print-only addition to the parts log). Overlaps the Whole leader's `cover_move_bonus` (stack them or take the larger; decide when built). |
| Pillar fit | Good in the picture, unknown in reach. |

#### A4. Exposure as a gradient (threat at the end cell)

| Item | Content |
|---|---|
| Change | `MovementOptionService._exposure` (`:1165`) counts controlled edges on the path. Replace or add an input: hostile reach on the **end cell**, or distance to the nearest hostile against its reach. Values between 0 and 1. Code in `core/movement`. This is the "make the input a gradient" item of `exposure-lever-study.md` 3e. |
| Touches | Likely most options: end cells near enemies differ in threat. **Not measured.** |
| Observer sees | The existing Directive term and fear lean (already correct and tested) then act on most decisions: Scout stays off the front line, Seek steps up, a frightened Echo hangs back. This is the most direct way to make the built terms matter. |
| Risk | High. It changes an option field every combat fingerprint reads. The attractor limit (weight x acceptance < base cost) must be re-proved for a gradient. The earlier study put it in its own story. |
| Pillar fit | Best fit with the work already done. Highest cost. |

### (b) Add a state term where none exists

#### B1. Step budget by fear and morale

| Item | Content |
|---|---|
| Change | Fear and morale change the **step capacity** of the Echo. Inspired morale: +1 step (PROPOSED DEFAULT). Shaken or high fear: -1 step, never below the contract floor 2. Fear part softened by composure. New config in the capacity block (`data.combat.movement.capacity`), for example `state_steps`. Code in `MovementProfileService` (the capacity owner). `mechanics-developer` must confirm that capacity is a legal input for the movement contract and for `MovementExecutor`. |
| Touches | Every pass of every non-neutral Echo. It changes the option set, not a score, so it cannot be re-scored offline. |
| Observer sees | The Echo's step length. A shaken Echo takes shorter steps and hangs back. An inspired Echo covers more ground. Easy to see and to learn, because the same cell count shows every round. It matches GDD 17.1: fear should "reduce readiness". |
| Risk | (1) **At Standing 1 the capacity is already 2, which is the floor.** A step penalty cannot act there. Only the bonus acts at Standing 1. This is a hard Standing 1 limit. (2) A shaken Echo with 2 steps may not reach an objective range in time (stall). Keep the penalty only for non-objective goals, or only for shaken and fear above 45 (decide with `mechanics-developer`). (3) The capacity cap (6) and aptitude terms stay. (4) Hashes: move only for non-neutral Echoes. |
| Pillar fit | Good. Standing and state both appear in how far an Echo walks. |

#### B2. Bonds shape cohesion

| Item | Content |
|---|---|
| Change | Cohesion today counts allies near the end cell (mean 0.55). Weight each ally by the bond: friends count more, rivals count against. Bonds are already in the arbiter context (`BehaviorArbiter.gd:760`, thresholds `bond_thresholds`). Code in the cohesion input (`MovementOptionService`, core) or as a bond-weighted second term in `_spatial_utility`. |
| Touches | Cohesion decides 36 percent of route choices. With bonds present the weighting changes which ally the Echo stays near. Share not measured. |
| Observer sees | An Echo stays near its friend. A rival keeps a gap. This is social behaviour in combat, which the GDD names (11.5 "Bonds / social graph"; Presence works through proximity and relationship). |
| Risk | Medium. A new input per option. Needs a fixture with real bonds (a fixture with empty bonds hides the term, see LESSONS). The `friend_protect_weight_bonus` (12) already pulls toward a friend at the action level; check overlap. |
| Pillar fit | High for the "relationships" part of the pillar. Not a fear, morale or Standing effect. |

#### B3. A fall-back goal from fear and morale

| Item | Content |
|---|---|
| Change | `CombatPressureService` emits a `regroup` or `withdraw` goal when Health collapses (`:409`, `collapse_health`). Add a second gate: fear above a ramp, or broken morale, emits a `regroup` goal toward the party. The arbiter then scores it against `engage` with the state terms that already exist (`retreating` style: fear_weight 30; morale; stop-short). |
| Touches | Pass count depends on the gate. The goal is multi-cell, not 1 cell. Today 0 of about 4,100 options carry such a goal. |
| Observer sees | A frightened Echo leaves the front and walks back to the group. This is the largest and clearest change. It uses tables that already exist and are silent today. |
| Risk | (1) **D-07 gives the `regroup` and `reposition` goal sources to V2-COMBAT-004.** Build it there, not here. (2) The Absolute Fear Rule already turns extreme fear into refusal (nascent threshold 65). The regroup goal fills the range from `fear_start` (20) up to the threshold. (3) It must not fight the Health `withdraw` goal (one goal per bucket survives; see `CombatPressureService.gd:157-171`). (4) Many hashes move. |
| Pillar fit | Best fit for "emotion must show in how they move". Wrong story for it. |

#### B4. Standing grows the Echo's own manner

| Item | Content |
|---|---|
| Change | Scale style alignment by Judgment: `alignment_weight x (1 + g x J)`. A seasoned Echo moves more as itself. This gives the "own habit" that D-71 O2 chose. |
| Touches | 99 percent of decisions, small each. Re-score: x1.5 changes 2.9 percent of decisions; x2.0 changes 5.7 percent. |
| Observer sees | At Standing 9 the Echo's style (careful, forceful, cohesive...) is clearer than at Standing 1. Slow, quiet growth. |
| Risk | **The swing budget binds.** `phase-d-design.md` 3a: layer B own side would become `(1 + g)`, and the Directive side floor is 0.6. The ratio `(1 + g) / 0.6` must stay at or under 2.0, so `g` is at most 0.2 (a x1.2 at J = 1). That is too small to feel (under 1.5 percent of decisions). A larger `g` needs the floor raised to 0.75 or `interpretation_swing_max` raised above 2.0 (Jeff, D-70 J4). |
| Pillar fit | Right idea. The current budget makes it too weak. See question Q5. |

### (c) Change content, not code

#### C1. Set-piece arenas with real route choices

| Item | Content |
|---|---|
| Change | New encounter and arena templates with a direct route through hostile control and a flank route outside it, or a chokepoint with cover. Authored by `mid-game-designer` with the level content owner. No code. |
| Touches | The decisions inside these arenas. Designer-controlled. The boards probe showed the exposure effect is visible when the choice exists: Seek takes the exposed route at 0.4 to 1.6 cells of extra progress, Scout at 2.8 to over 6 cells or never (D-80). |
| Observer sees | In those arenas Scout and Seek choose different lines, and a frightened Echo takes the safe one. The behaviours already built become visible at chosen moments. |
| Risk | New templates do not move old fingerprints. Existing arenas stay as they are. The risk is that choices stay rare in the *other* fights. |
| Pillar fit | Good. Cheap. The only option that needs no scoring change. |

#### C2. Add cover and flank terrain to existing arenas

Same as C1 but edits existing fixtures. Moves recorded values in every changed arena. Needed only if A3 is chosen. Advice: C1 first.

## 4. Advice

### 4.1 Recommended package

| # | Item | Why | Cost |
|---|---|---|---|
| 1 | Slice 3 as decided (D-81) | Already decided. Judgment scale on exposure. | In build |
| 2 | **A1 state-scaled pull**, with composure softening | Acts on the terms that decide most choices. Ceiling about 6 to 8 percent of all passes, 9 to 12 percent at the strong end. Config plus about 15 lines. | Small |
| 3 | **B1 step budget** | The only option with a large, learnable, per-round visible result. Needs a feasibility check first. | Small to medium |
| 4 | **C1 set-piece arenas** | Makes the built exposure terms visible at chosen moments. No code. Can run in parallel with 2 and 3. | Content |
| 5 | **B3 fall-back goal**, as a requirement for V2-COMBAT-004 | The strongest emotion-to-movement effect. D-07 puts it there. | Hand-off |
| 6 | B2 bonds in cohesion, after 2 | Social behaviour. Needs a bonded fixture. | Medium |
| Later | A3 cover (after one count), A4 gradient (own story) | Reach unknown or cost high | |
| Not now | A2 (raise style), B4 (budget binds) | Weak for state / too small within budget | |

### 4.2 Slice order (earliest visible effect first)

1. **Slice 3** (running).
2. **Slice 5: A1.** Config block, bounded lean, composure softening, neutral-point identity. Tests: lean is 0 at steady morale and fear under 20; afraid cohesion weight > calm; bold progress weight > calm; floor holds; composure reduces the afraid lean; enemy has no lean; `directive_cfg` bound test. Boards probe (30 s): add one afraid and one bold board and check the end cell moves toward the group or the objective.
3. **Slice 6: B1.** `mechanics-developer` feasibility first (question to ask: may capacity vary per round without breaking the movement contract?). Same test shape.
4. **In parallel with 2 and 3:** C1, by `mid-game-designer`.
5. **Hand-off:** B3 requirement note to V2-COMBAT-004.
6. B2 as a later slice.

Each slice follows D-79: unit tests, one recorded-value run, one named cause per slice, then an `opus` attribution.

### 4.3 Run estimate

| Item | Runs |
|---|---|
| A1 and B1 proof | Unit tests (seconds) and the boards probe (30 s). No fight probe. |
| Section 1.5 numbers | Already computed offline from the logs. No new run. |
| Recorded values | One serial suite run per slice (existing practice). Which fingerprints move is unknown. They move only for fixtures with non-neutral fear or morale. |
| Optional single measurement | Only if A3 or A4 is chosen: a print-only addition to the parts log (cover-end-cell flag, hostile reach at the end cell, stop bias, stationary best score). One 4-arm parallel run (about 7 minutes, as D-80). The main chat runs it. Skip it if Jeff does not choose A3 or A4. |

### 4.4 Design pressure check for the package (A1 + B1)

| Question | Answer |
|---|---|
| Legible without an ID or a number? | Yes. The observer sees step length and distance to allies. No number is needed. A later glyph or telegraph is a `ui-ux-designer` and `game-feel-developer` question (deferred). |
| Survives a player who never reads it? | Yes. It acts in play, not in a menu. |
| Decision or delay? | A decision for the Keeper: whom to put in the front, when to rest a shaken Echo (morale recovers by rest), where a shaken Echo is safe. The Keeper does not control it directly. |
| Fear and emotion? | It is built on them. It does not bypass them. |
| Standing 1 | Calm fixtures do not move. A frightened Standing 1 Echo leans fully (low composure). Step penalty cannot act (floor 2). Bonus can. |
| Standing 6 | Capacity 4. Composure about 0.5 to 0.6 gives about 20 to 25 percent less fear lean. Judgment reads the Directive less literally (slice 3). |
| Standing 9 | Composure high gives up to 40 percent less fear lean. Refusal threshold 95. The veteran keeps its line under fear that sends a young Echo back. This is the visible growth. |
| Failure mode: player ignores it | Frightened Echoes drift to the group and hang back. The Keeper sees weak pushes and can rest or steady them. |
| Failure mode: exploit | A Keeper who keeps morale high gets bold Echoes that outrun the group. The cohesion floor 0.8 and progress cap 1.4 limit it. A bold Echo ahead of the group is also more exposed. |
| Failure mode: stall | Progress floor 0.6 and the unscaled urgency term keep movement going. Check with a unit test: a fully afraid Echo still makes progress toward an objective in a clear board. |

## 5. Questions only Jeff can answer

| # | Question | Options | Advice |
|---|---|---|---|
| Q1 | What should a frightened Echo visibly do first? | A: stay near its allies and push less (A1). B: take shorter steps (B1). C: fall back to the group (B3, in COMBAT-004). D: take cover (A3). | A and B now, C in COMBAT-004. |
| Q2 | Should high morale make an Echo bolder, or does only fear shape movement? | A: fear only. B: fear and morale (bold Echoes advance and drift from the group). | B, with the bounds in section 4.4. Morale already has a large action effect; this makes it show in the route. |
| Q3 | Should a seasoned Echo resist fear (composure softens the lean by up to 40 percent)? | A: yes. B: no, the lean is equal for all (D-70 J3 style). C: yes for the new leans, no for the exposure lean. | A. It makes growth visible in a frightened Echo. B keeps a simpler rule. |
| Q4 | How strong should the felt effect be? This sets the lean bounds (mid-game-designer authors them). | A: subtle (about 3 to 5 percent of passes). B: clear (about 6 to 10 percent). C: strong (about 12 percent or more). | B. A is hard to see. C risks stall and out-of-group runs. |
| Q5 | May the swing budget `interpretation_swing_max` (2.0) rise, so Standing can scale the Echo's own style (B4)? | A: no, keep 2.0. B: yes, up to 2.5 with a new config test. C: raise the Directive floor instead (0.75). | A for now. Revisit after slices 5 and 6. |
| Q6 | May combat step capacity change with fear and morale (B1)? It touches the COMBAT-002 capacity contract. | A: yes, after a feasibility check. B: no, capacity stays Standing and aptitude only. | A, after `mechanics-developer` confirms. |
| Q7 | Do you want authored set-piece arenas with route choices (C1) next to the system work? | A: yes, in parallel. B: later. C: no. | A. It is the only way the built exposure terms reach the player soon. |
| Q8 | Does the fall-back goal (B3) go to V2-COMBAT-004 as a requirement? | A: yes (D-07). B: build a small version here. | A. Same goal source, same story. |

## 6. Deferrals

| Item | Goes to |
|---|---|
| `regroup`, `reposition` and fall-back goal sources | V2-COMBAT-004 (D-07) |
| How the player sees a lean (glyph, telegraph, a stop ring) | `ui-ux-designer`, `game-feel-developer`, after the lean exists. No player text here. |
| Exposure as a gradient (A4) | Its own story, only if Jeff wants it after slice 5 |
| Cover count and bonus (A3) | After the optional single measurement |
| Enemy state leans | Not planned. The pillar is about Echoes. |
| Bond-weighted cohesion (B2) | A later slice, needs a bonded fixture |
| Values of every bound and weight | `mid-game-designer` |
| Which fingerprint suites move | An `opus` attribution run after each slice |

## OPEN — questions and assumptions

ASSUMED: The `TURNSUM` margin and the `DECISION` terms in `par/*.out` come from the same arbiter pass as the chosen option. | WHY: D-80 states the parts log is taken from the arbiter pass (the `ExposureCaptureArbiter` hook). | WRONG IF: the hook records a different candidate set from the one the arbiter scores. The margin tables in 1.2 to 1.5 would then be off.
ASSUMED: "Removal flips" and the re-score in 1.5 are first-order only. | WHY: the logs hold one pass per Echo turn; later turns cannot be replayed offline. | WRONG IF: a real fight cascades. Real changes may be larger (a changed cell alters later options) or smaller. Section 1.5 numbers are a ceiling for the first turn.
ASSUMED: The four arms (calm and fear 50, Scout and Seek) are a fair sample of Echo decisions. | WHY: they cover the 7 fixed fights, 5 Echoes each, 1,037 passes. | WRONG IF: real stages differ from the 7 fixtures in goal mix. Purposes seen were engage, protect, intercept, advance, cut_off, pursue and hold only.
ASSUMED: The numbers in 1.1 for the fear factor ("0.77 to 0.85 at fear 50", "about -12") come from `fear_active_dampen` 0.45 and composure scale 0.4, not from a log. | WHY: the logs do not split the action layer. | WRONG IF: composure values in play are outside 0 to 1, or the typical action score is far from 80.
ASSUMED: Slice 3 (Judgment scale on acceptance) is in build and not yet in the tree. | WHY: D-81 says "built now"; `balance.json` has no `judgment_floor` key. | WRONG IF: slice 3 landed. The Judgment row in 1.1 then reads "in tree".
ASSUMED: Step capacity can vary per round for one Echo without a contract change. | WHY: `MovementProfileService` computes it per activation (not checked in code). | WRONG IF: capacity is saved, cached, or fixed by the movement contract. Then B1 needs a design change (Q6).
BLOCKED: How often a stop-short route wins, and how large the fear and morale stop bias is in the 7 fights. | CHECKED: `par/*.out` (no stop field), `StopShortService.gd`, `balance.json` `data.actor.stop_short`. | NEED: a print-only log addition (stop bias per option). Optional, section 4.3.
BLOCKED: How many options end on a cover cell or inside hostile reach. | CHECKED: `par/*.out`, `BoardAssessmentService.is_cover_destination`, `MovementOptionService._exposure`. | NEED: the same optional log addition. Decides A3 and A4.
BLOCKED: Which `fingerprint_*` suites set non-neutral fear or morale, and so would move under A1 or B1. | CHECKED: `AGENTS.md` suite list only; no test file read. | NEED: a grep of fixtures for fear and morale values by `mechanics-developer`, or an attribution run after the slice.
BLOCKED: Whether capacity may vary by state under the COMBAT-002 contract (Q6). | CHECKED: `balance.json` capacity block (floor 2, cap 6, Standing bands). Code and contract not read. | NEED: `mechanics-developer` feasibility answer.
