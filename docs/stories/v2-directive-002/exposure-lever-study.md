# V2-DIRECTIVE-002 phase D: study of the base exposure cost

Author: `sr-game-designer`, 2026-10-16. Design study only. It decides nothing (D-76: any change is Jeff's decision).
It edits no code and no data. It proposes no player text. Every number marked PROPOSED DEFAULT goes to `mid-game-designer`.
Written in ASD Simplified Technical English.

## 0. Summary

1. The suspected cause is only partly right. The base cost (`exposure_weight` -6.0) does not hide the Directive term. The base cost and the Directive term add on the same exposed option. The two sum to a new slope.
2. The probe data point to a different first cause: **the probe boards rarely offer a real exposure choice.** Exposure is 0.0 on 95 percent of route options. Only 5 to 7 percent of Echo decisions have one exposed and one unexposed route option (section 2).
3. Lowering `|exposure_weight|` does not widen the window in which the Directive or fear flips a decision. It also breaks the attractor rule at -5.1 or lower (section 3a).
4. The probe cannot say how often exposed and unexposed options have similar progress. It logs no progress and no score. Section 2.3 designs the measurement as a RUN REQUEST.
5. Advice: do (c) first (measure, then decide). Do not change `exposure_weight` before the measurement. Details in section 3.

## 1. What exposure is in combat scoring

### 1.1 The input

- `MovementOptionService._exposure(path, origin, edge_costs)` (`core/movement/MovementOptionService.gd:1165`) counts the route edges that lie in hostile control. It divides by `max(1, path.size())`.
- Result: a fraction from 0.0 to 1.0. In a fight the routes are one or two cells long, so the fraction is almost always 0.0 or 1.0.
- Measured on the probe boards (`FIELDS` lines, Scout weight 17 run, 7 fixed fights):

| Value of `exposure` | Options | Share |
|---|---:|---:|
| 0.0 | 1141 | 95.0 percent |
| 0.5 | 4 | 0.3 percent |
| 1.0 | 56 | 4.7 percent |

- Seek run: 1118 / 6 / 60 (same pattern). Older measurement: `v2-combat-003/handoff.md` 22.3 (1 in 481 options was intermediate). The input is still binary.
- `handoff.md` 22.5 already names the real limit: "the real limit is the input, not the weight". Phase D data confirm it.

### 1.2 The spatial score

`BehaviorArbiter._spatial_utility` (`core/actors/behaviors/BehaviorArbiter.gd:1414`). It runs once per route candidate. Its sum is clamped to `+/- cap` (28.0) and added to the candidate score. Stationary candidates (attack in place, stay) do not receive it.

| # | Term | Formula | Shipped weight | Size in a real decision |
|---|---|---|---:|---|
| 1 | urgency | `w x urgency` | 4.0 | 0 to 4.0. Same for every option of one goal. |
| 2 | objective_progress | `w x progress x (1 + gain x urgency)` | 8.0, gain 1.0 | 0 to 16. This is the largest term. One cell of progress is about 1 to 4 points (NOT measured; see 1.3). |
| 3 | cohesion | `w x cohesion` | 4.0 | Measured input: mean 0.55, max 1.0. So 0 to 4, typical 2.2. |
| 4 | exposure | `w x exposure` | -6.0 | 0 on 95 percent of options. -6.0 on 4.7 percent. |
| 5 | congestion | `w x congestion` | -2.0 | Measured input: mean 0.13, max 0.625. So 0 to -1.25, typical -0.26. |
| 6 | commitment | `w x route_cells / origin_distance` | -2.0 | 0 to -2.0. |
| 7 | directive_objective_advance | `w x advance x progress` | 4.0 | 0 to about 4 (Directive weight dependent). |
| 8 | directive_avoid_overcommit | `w x avoid x (1 - commit_ratio)` | 2.0 | Up to about 2. |
| 9 | directive_exposure_acceptance | `w x acceptance x exposure` | 17.0 | Scout -3.4, Seek +5.1 on an exposed option. 0 on an unexposed option. |
| 10 | directive_ally_protection | `w x bias x protects` | 2.0 | Up to 2, only for protect, intercept, escort goals. |
| 11 | directive_threat_interception | `w x bias x intercepts` | 2.0 | Up to 2, only for intercept, cut_off goals. |

- `acceptance = clamp(exposure_tolerance - 0.5 - fear_lean, -1, 1)`. Scout 0.3 gives -0.2. Seek 0.8 gives +0.3. `fear_lean = 0.12 x fear_ramp(fear)`; the ramp goes 0 at fear 20 to 1 at fear 70 (`phase-d-design.md` line 183). An empty Directive (enemies, keeper trial) gives 0.
- Added outside `_spatial_utility`, on the same route candidate: style alignment (`alignment_weight` 0.06 x style score, damped by urgency up to a factor 0.25; `BehaviorArbiter.gd:832`), cover bonus, stop bias.
- Style alignment already prefers `low_exposure` and `careful` route shapes for some virtues, Callings (Anchor, Sight) and for fear. Its size is NOT measured here. Estimate: well below 2 points (the 0.06 weight shrinks the raw sum).

### 1.3 What the probe could not give

The probe logs `exp`, `con`, `coh`, `hostile` per option (`tools/SpatialTermProbe.gd:193`). It does NOT log progress, urgency, per-term parts, the total score, or the chosen option. So:

- The sizes in the table for terms 1, 2, 6 to 8, 10, 11 come from the weights and the legal input ranges, not from measured values.
- Terms 3 and 5 use measured inputs times the shipped weights.
- The arbiter already produces per-term parts (`_spatial_components`, `BehaviorArbiter.gd:817`; read by `DecisionTrace.gd:291`). The probe does not print them. Section 2.3 uses them.

### 1.4 The slope on an exposed option (calculated, not probed)

Extra score of an exposed route against an equal unexposed route = `-6.0 + 17 x acceptance`.

| Case | Acceptance | Exposed cost (points) |
|---|---:|---:|
| Base only (weight 0 arm) | n/a | -6.0 |
| Scout, calm | -0.20 | -9.4 |
| Scout, fear 70 | -0.32 | -11.4 |
| Seek, calm | +0.30 | -0.9 |
| Seek, fear 70 | +0.18 | -2.9 |

- The Directive already moves the exposed cost a lot: Scout minus Seek is 8.5 points. Fear moves it 2.0 points.
- A decision changes against the weight-0 arm only if the other terms leave a gap in a narrow window: Seek, gap 0.9 to 6.0 (width 5.1). Scout, gap 6.0 to 9.4 (width 3.4). Fear 70 adds a window of width 2.0.
- Here the gap G = (score of the exposed option) minus (score of the best unexposed option), with the exposure terms left out.
- One progress step is 1 to 4 points. So each window is about one to two steps wide. A window this small only matters if many decisions have a choice. They do not (section 2).

## 2. Why the Directive and fear terms rarely flip a decision

### 2.1 Evidence from the probe

Counts from the `FIELDS` lines of `scout-w17.txt` and `seek-w17.txt` (7 fixed fights, all rounds; a decision = one actor in one round):

| Count | Scout w17 | Seek w17 |
|---|---:|---:|
| Route options logged | 1201 | 1184 |
| Echo decisions with route options | 229 | 220 |
| Echo decisions where at least one option is exposed | 29 | 31 |
| Echo decisions where ALL options are exposed (no exposure choice among routes) | 20 | 17 |
| **Echo decisions with a real exposure choice (mixed exposed and unexposed options)** | **11** | **16** |
| Share of Echo decisions | 4.8 percent | 7.3 percent |
| Enemy decisions with a mixed choice | 9 | 9 |

- Mixed decisions by fight, Scout: combat 1, purify_shrine 5, recover 1, protect 2, endure 6, pursue 5 (all actors). Seek: combat 3, purify_shrine 6, recover 1, protect 4, endure 6, pursue 5.
- Fear runs (`s2/probe_*_fear_70.txt`, fear 70 on every Echo): 318 decisions, 11 with a mixed choice (3.6 percent), 0 moves changed. The lean (2.0 points) acted on at most 11 decisions and none was in its window.
- Moves changed against weight 0 (D-73): Scout 2 of 384, Seek 16 of 355. Seek has 16 mixed Echo decisions and 16 changed moves. Some changed moves are cascades from an earlier change, so the match is a coincidence at this precision. Scout has 11 mixed Echo decisions and 2 changed moves.
- Reading: the Directive term acts on almost every mixed decision for Seek. It acts on few for Scout. The count of mixed decisions is the limit.

### 2.2 Answer to the question

- Does the probe board offer real exposure choices (two routes, different exposure, similar progress)? **Only in part.**
  - Different exposure: yes, 11 and 16 Echo decisions in 7 fights. That is too few to show a trend.
  - Similar progress: **unknown.** The log has no progress value. Exposed routes are often the direct routes to the objective. They may win or lose by a wide progress margin, with no exposure effect in either case.
- Is the base cost the cause? **Not supported and not refuted.** The base cost sets where the flip window sits. It does not set the width of the window (the width is `17 x |acceptance|`). A lower base cost moves the window; it does not make it wider.
- Main cause by evidence: the number of decisions that have a choice (4.8 and 7.3 percent). Second cause: the window width against the progress step size.

Caveat: the `FIELDS` lines come from a separate `prepare_live_movement_context` call per round, not from the arbiter pass of the same turn. The match by (fight, round, actor) is close but not exact. Positions can differ if an earlier actor moved in the same round.

### 2.3 RUN REQUEST for the main chat (measurement design)

Purpose: count real exposure choices and their margins. Needed before any change to `exposure_weight`.

1. **What to log.** One `DECISION` line per route candidate per Echo turn: fight, round, actor, option id, `exposure`, `objective_progress`, urgency, the 11 `spatial` parts, style alignment, total score, `chosen=0|1`. Add one summary line per turn: the score margin between the best option and the best option with a different exposure value.
2. **Where.** `tools/SpatialTermProbe.gd` (already open in the working tree). Source: the `_spatial_components` and `_score_bias` already stored on each candidate by `BehaviorArbiter.gd:817` and `:838`, or the `DecisionTrace` entries (`DecisionTrace.gd:291`). `mechanics-developer` confirms which is reachable from the probe.
3. **Minimal change.** Print-only. No change to `core/`. No config change. The same 7 fights, Scout and Seek, weight 17 as shipped, two arms only (calm, fear 70).
4. **Questions the log answers.**
   - How many Echo decisions have a mixed choice AND a score margin under 10 points? (This is the number of decisions the Directive can move.)
   - In how many of them does the chosen option change when the exposure terms are removed?
   - What is the real distribution of G (section 1.4)? Is it inside the Seek window 0.9 to 6.0 or the Scout window 6.0 to 9.4?
5. **Runtime.** 14-run sweeps took about 10 minutes each (`sweep_progress.txt`). Two arms of 7 fights each should be a single run per Directive. This is over 2 minutes: the main chat runs it with the `timeout` and `alarm` from root `AGENTS.md`.
6. **Restore.** The probe edits no data file. The run needs no `balance.json` override for the two shipped arms. Check `cmp` on `tools/SpatialTermProbe.gd` against a saved copy if the builder edits it again.

## 3. Options

All numbers are PROPOSED DEFAULT. Fit is judged against: the pillar (growth and emotion must show in movement), D-05 (`exposure_tolerance` is the one exposure input), D-09 (no shared function; reuse Judgment, `directive_interpretation_mul`, Calling `directive_mul`), D-69 (offset; two exposure inputs stay; Judgment scale inside `interpretation_swing_max`), D-70 (fear lean and Judgment scale in phase D; swing stays 2.0), D-71 (fear bound 0.12; own habit through style alignment), D-72, D-73 (weight 17; attractor limit), D-74, D-75 (fear lean for non-empty Directive), D-76 (study first).

### 3a. Lower `|exposure_weight|` for the whole fight

| Item | Content |
|---|---|
| Change | `data.combat.movement.spatial_utility.exposure_weight` from -6.0 to a smaller magnitude. Config only. |
| Effect | Every Echo and enemy takes exposed routes more often. The Scout versus Seek difference stays 8.5 points (it comes from the Directive weight). Fear lean stays 2.0 points. |
| Hard limit | The attractor rule: `directive_exposure_acceptance_weight x max acceptance < |exposure_weight|`. At weight 17 and acceptance 0.3, `|exposure_weight|` must stay above 5.1. D-73 and test `directive_cfg/exposure_acceptance_never_attractor` enforce it. So the base cost may fall from 6.0 only to about 5.2 (a 13 percent change) unless the Directive weight falls too. |
| If both fall together | Example: base -3.0 and Directive weight 8.0: Scout -4.6, Seek -0.6. The window becomes narrower (Seek 0.6 to 3.0). This makes the Directive and fear terms MORE rare, not less. |
| Risk | Makes exposure matter less for everyone. Works against the Scout Carefully identity (GDD "Directives and scouting", line 4285: safer pathing). Enemies and the keeper trial also change (no empty-Directive protection on the base term). |
| Recorded values | Scout fingerprints move: `fingerprint_combat`, `_endure`, `_guide_spirit`, `_protect`, `_purify_shrine`, `_pursue`, `_recover`, and the `fingerprint_determinism_*` set if hashes include moves. `fingerprint_seek` moves if an Echo or enemy choice changes. Size unknown without the measurement. Older sweep (22.3, before phase D): -3 changed 3 keyed turns, -12 changed 11, -24 changed 31. |
| Pillar fit | Poor. It does not tie exposure to the Echo's state. All Echoes get bolder alike. |
| Advice | Do not do this. It cannot do what D-76 wants. |

The opposite direction (raise `|exposure_weight|` and the Directive weight together, for example -9 and 25) widens all windows by the same ratio. It is bounded by `cap` 28 and by the Judgment floor. It keeps the attractor rule. It also makes exposure outweigh progress more often, so Echoes may stall. Not recommended without the section 2.3 data.

### 3b. Scale the base cost by the actor's own state

| Item | Content |
|---|---|
| Change | The base cost becomes `exposure_weight x m`, where `m` is read from the actor. Idea: `m = 1 + fear_gain x fear_ramp - seasoned_gain x judgment_signal`. PROPOSED DEFAULT `fear_gain` 0.2 to 0.3, `seasoned_gain` 0 to 0.2. **This needs code** (a new argument to `_spatial_utility`, a new config block next to `exposure_acceptance`). Phase D already adds `judgment` and `fear` to the spatial call (`phase-d-design.md` line 139), so the seam exists. |
| Effect | A frightened Echo prices exposure higher on every exposed option, with or without a Directive. A seasoned Echo prices it by its own habit, not by the Directive. This is growth and emotion in the movement itself. |
| Size under the swing budget | Layer B own side is 1.0 and the Directive side floor is 0.60. Budget 2.0 gives own side at most 1.2 (1.2 / 0.6 = 2.0, no headroom). Keep `m` at most 1.15 (PROPOSED DEFAULT). That is +0.9 points on -6.0. This is smaller than the present fear lean (2.0 points). **So under the present swing budget, scaling the base cost cannot be a large lever.** A large lever needs Jeff to raise `interpretation_swing_max` (D-70 J4 says it stays 2.0 unless Jeff approves). |
| Double count | Fear now enters exposure in three places: (1) style alignment `fear_weight` (route shape), (2) the fear lean on acceptance, (3) the new multiplier. They stack by design in (1) and (2) (`phase-d-design.md` line 356). A third path is too much. If (b) is chosen, replace the additive fear lean with the multiplier. One fear path, same size, works with or without a Directive. This needs D-71 O1 and D-75 to be amended. |
| Double count with Judgment | The Judgment scale on acceptance (slice 3, layer B) already lowers the Directive part for a seasoned Echo, to 0.6 of its size at Judgment 1. A second Judgment term on the base cost would lower the exposure slope twice. Use ONE Judgment path only. |
| Own habit | D-71 O2 chose style alignment as the seasoned Echo's own exposure habit. Style alignment is about 0.06-weighted and urgency-damped (section 1.2). At Standing 9 the Directive part falls to 0.6 and the own part is small. So **the exposure behaviour of a Standing 9 Echo is mostly the shared base cost, the same for every Echo.** That weakens the pillar at the high end. This is a finding for Jeff (question Q3). |
| Risk | Medium. New code path, new config keys, new tests. It must be Echo-only: enemies keep the plain base cost. |
| Recorded values | None move at Standing 1 and fear 0 if `m = 1` there (design for identity at the neutral point). Moves appear only in fixtures where fear or Judgment is non-neutral. Check which fixtures set fear or Standing. Fingerprints that use fixed fear (the emotion indices) may move. Re-record with `opus` attribution. |
| Pillar fit | Good in direction, small in size. Needs the swing budget raised to be felt. |
| Advice | Hold until section 2.3 shows whether any lever can reach enough decisions. If it does, choose (b) in the "replace the fear lean" form. |

### 3c. A better probe board with real route choices

| Item | Content |
|---|---|
| Change | No game change. Add fixtures to the probe (not to `tests/`): a board with a direct route through hostile control and a flank route outside it. Equal or near-equal progress (within one step). Vary Directive (Scout, Seek), fear (0, 45, 70), Standing (1, 6, 9; after slice 3). |
| Effect | Shows whether the effect exists when the choice exists. It answers whether the real game (with its own boards) would show the effect. Run together with section 2.3 on the 7 real fights. |
| Risk | A fixture board can overstate the effect. Rule from memory `probe-must-mirror-production-construction`: build the fixture through the production path (`prepare_live_movement_context`, real `Directive` entries), not by a hand-made option. |
| Recorded values | None. Probe and docs only. |
| Pillar fit | Direct. It tests whether growth and emotion are visible at all, before any tuning. |
| Advice | Do this first. Two parts: (1) section 2.3 log on the 7 fights, (2) a small set of 3 to 5 fixture boards. Both are print-only. |

### 3d. Do nothing

| Item | Content |
|---|---|
| Change | None. Slices 3 and 4 go on. Phase D ends with the Directive acceptance (17) and the fear lean as built. |
| Effect | Seek changes 16 of 355 moves against weight 0. Scout changes 2 of 384. Fear lean changes 0 of 1207. The terms exist and are correct, but the player rarely sees them in the 7 fights. |
| Risk | The pillar is not met in movement: an Echo's fear and Standing do not show in how it moves, except in stops (slice 4) and in action choice. The risk is stated, not measured on real boards. |
| Recorded values | None. |
| Pillar fit | Weak, unless 3c shows the real game has more choices than the probe. |
| Advice | Acceptable for phase D, ONLY with 3c done and the result recorded. Without 3c, "do nothing" is a guess. |

### 3e. Out of scope for phase D, named for completeness

- **Make the input a gradient** (`handoff.md` 22.5): count controlled edges against movement capacity, not route length. This gives values between 0 and 1 and raises the share of decisions where exposure differs by option. It is a mechanism change in `MovementOptionService._exposure`, outside D-76 ("a larger design change and not in phase D"). It moves almost every recorded value. It is the lever the evidence points to most, because the limit is the input. Needs its own story, after 3c.
- **Add a "stay" option with exposure 0.** `handoff.md` 22.2 shows a zero-step option exists once an actor is in range. This is already the unexposed alternative for many decisions. The section 2.3 log must include it.

## 4. Cost of each option

| Option | Slices | Runs | Recorded-value re-record |
|---|---|---|---|
| 3a lower base | 1: config edit + attractor test check | Probe sweep (3 to 4 base values x 2 Directives = 8 runs, about 10 min each, main chat). Then the sharded suite. | Scout fingerprints (up to 14 suites). Seek `fingerprint_seek`. Needs one `opus` attribution per moved value. Moves not known before the sweep. |
| 3b scale by state | 3: (1) design amendment (D-71, D-75), (2) code + config + tests, (3) re-record | Probe: 1 log run (2.3) + 1 sweep of `fear_gain` and `seasoned_gain` (about 6 runs). Sharded suite. | None at the neutral point (`m = 1`). Possible in emotion-index fixtures. One `opus` attribution if any move. |
| 3c better board | 2: (1) log in `SpatialTermProbe.gd` (2.3), (2) 3 to 5 fixture boards | 2 probe runs (7 fights; fixtures). Main chat runs both. | None. |
| 3d nothing | 0 | 0 | 0 |
| 3e gradient (later) | A story of its own, 3 to 5 slices | Large | Almost all combat fingerprints. |

Sequence advice: 3c first (2 slices, 2 runs, no recorded value). Its result decides whether 3a, 3b, 3d or 3e follows. Slices 3 and 4 of phase D can go on in parallel with the log design, but the log RUN must not run at the same time as another Godot run (shared fixtures in `/tmp/echoes-vnext-tests/`).

## 5. Questions only Jeff can answer

| # | Question | Options | Advice |
|---|---|---|---|
| Q1 | Does phase D wait for the section 2.3 log before the final check? | A: yes, run 3c first (2 slices, 2 runs). B: no, finish slices 3 and 4, do 3c after phase D as a follow-up. C: skip. | A or B. A gives the final check a real number. B is cheaper now but the final check then cannot say whether the pillar shows in movement. Not C. |
| Q2 | If 3c shows too few real choices, what is the fix? | A: change the input (gradient, 3e, own story). B: accept that exposure shows mainly in stops and action choice. C: change the base cost (3a or 3b). | A, if the log supports it. The data point to the input, not the weight. |
| Q3 | At Standing 9 the Directive exposure part falls to 0.6 (slice 3) and the Echo's own habit is only style alignment (about 0.06 weight). Is "the base cost is the same for every Echo" acceptable at high Standing? | A: yes. B: add a Calling or virtue habit on the base cost (reopens D-71 O2, needs swing budget). C: raise the own-side weight of style alignment for route shape only. | B or C, if the log shows the effect is invisible. This is the pillar question. Decide after 3c. |
| Q4 | May `interpretation_swing_max` rise above 2.0 for the spatial layer, if 3b needs it? | A: no (keep D-70 J4). B: yes, up to 2.5, with a new config-integrity test. | A for now. Revisit only after Q2 and Q3. |
| Q5 | One fear path or three into exposure? (style `fear_weight`, fear lean, and 3b multiplier) | A: keep two (as built). B: replace the lean with the multiplier. | A until 3c. B only if 3b is chosen. |
| Q6 | Do enemies keep the plain base cost? | A: yes, Echo-only changes (empty Directive stays 0 per D-75). B: enemies get the same state scaling. | A. The pillar is about Echoes. |

## OPEN — questions and assumptions

ASSUMED: The `FIELDS` lines in the probe files list every route option for each actor and each round. | WHY: `SpatialTermProbe.gd:190-200` loops over all `options` from `prepare_live_movement_context`. | WRONG IF: the arbiter adds or removes candidates after that call (for example stationary candidates), or the probe board differs from the board at turn time.
ASSUMED: Mixed decisions are counted as "at least one exposed and one unexposed route option" in the same (fight, round, actor) key. | WHY: the probe has no progress or score data, so no stricter test is possible. | WRONG IF: one key hides two separate decisions (the same actor acts twice in one round) or two fixtures of the same mode share a key.
ASSUMED: Slice 3 (Judgment scale on acceptance) is not yet landed. Sizes in this study use `acceptance = tolerance - 0.5 - fear_lean`. | WHY: `decisions.md` lists D-69 to D-76 only up to the slice 2 decision; `git status` shows slice work in progress. | WRONG IF: slice 3 is already in the tree. Then the Scout and Seek costs in section 1.4 fall by up to 40 percent at high Judgment.
ASSUMED: Enemies use an empty Directive in combat (acceptance 0), as D-75 states. | WHY: D-75 says so; `handoff.md` 22.6 (older) said the keeper Directive also steered enemies. | WRONG IF: 22.6 was never fixed. Then 9 enemy mixed decisions are also moved by the Directive term, and the counts for Echo decisions are unchanged.
ASSUMED: The size of style alignment is "well below 2 points". | WHY: weight 0.06 times a bias sum, damped by urgency. Not measured. | WRONG IF: the raw bias sum (vector 0.25 to 0.5 x score, calling family 6.0, fear weight) is large. The section 2.3 log would show it.
BLOCKED: How often do an exposed and an unexposed option have similar objective progress? | CHECKED: `scout-w17.txt`, `seek-w17.txt`, `s2/probe_*`, `SpatialTermProbe.gd` (no progress or score field), `handoff.md` 22.2 to 22.5. | NEED: the section 2.3 RUN REQUEST (per-option parts and scores), run by the main chat.
BLOCKED: Which `fingerprint_*` suites hash a move that depends on exposure? | CHECKED: `AGENTS.md` suite list (lines 96-100); no test file read. | NEED: an attribution run (as `phased/attrib.sh`) after any change, by an `opus` agent. The study does not list exact suites.
