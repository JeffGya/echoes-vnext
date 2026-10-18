# V2-DIRECTIVE-002 phase D: design note for slices 5, 6 and 7 (version 2, one reading per system)

Author: `sr-game-designer`, 2026-10-17. Also number author for this note.
Source: D-81 to D-86 in `decisions.md`, Jeff's rule D-87 ("one game; no multiple reinterpretations of the same system"), the state-systems study, `phase-d-design.md`, `phase-d-numbers.md`.
This note edits no code and no data. It proposes no player text. Every number is PROPOSED DEFAULT.

> **Status after phase D (docs pass, 2026-10-18):** the options C1 to C5 and C8 were taken (D-89) and the stage was aligned (D-91). Slices 5 to 7 are built on draft PR 108. The status module is `core/emotion/EmotionStatusLean.gd` (not `core/movement/FeltStateLean.gd`). The test IDs in section 8 are the plan; the real names are in `tests/FeltStateTests.gd` and `tests/MovementArbitrationTests.gd`. Options C6 and C7 stay deferred (follow-ups). Statements that phase D made false are marked in place.
Written in ASD Simplified Technical English (STE).

| Slice | What it does |
|---|---|
| 5 | The emotional state moves the progress and cohesion weights of route scoring |
| 6 | The emotional state moves step capacity |
| 7 | Judgment scales the Echo's own movement style, by the same scale the action layer already uses. The swing budget rises to 2.5 |

## 0. Summary

1. Fear and morale are already combined in one shipped definition: the ten-state emotional status (`EmotionService.get_emotional_status`, `EmotionService.gd:210`). Sanctum, conversations and the combat chip use it. Combat movement does not. It reads fear and morale in **seven different ways** (section 1).
2. Slices 5 and 6 read **only** the emotional status. A table in config turns each of the ten states into one lean from -1 to +1. Composure softens it. Fear and morale combine because the status combines them.
3. Slice 7 reuses `identity_weight_scale`. It adds no new gain key. It loses the exact neutral point (section 4.3).
4. Slices 2, 3 and 4, and older stop, style and action code, read fear in other ways. I list the smallest change for each as an OPTION for Jeff (section 1.4). I rework none of them.
5. Size at full strength: afraid states change 6 to 8 percent of multi-option route decisions from "pressed" down. "Burdened" changes about 6 percent. Radiant changes about 7 percent (section 3.4).
6. Everything fits the swing budget 2.5. The largest value is 2.43 (section 5).
7. No fight probe. Unit tests plus a 30-second `boards` probe addition prove all three slices.

## 1. One reading per system

### 1.1 Every reader today

"Raw" means the number itself. "Linear" means `value / 100`. "Tier" means the four-step morale tier (`EmotionService.get_morale_tier`, thresholds 75, 50, 25). "Status" means the ten-state emotional status. `max(f, b)` means `max(fear, fear_base)`.

| # | Place (file:line) | System | Reads | How | Decision it shapes | Verdict |
|---|---|---|---|---|---|---|
| 1 | `EncounterSnapshotBuilder.gd:83,112`; `FlowEncounterState.gd:289-291`; Sanctum builders (`SanctumSnapshotBuilder.gd:166`, `FlowSanctumState.gd:94`, `FlowEchoPartyState.gd:127`); `VentureResolveSnapshotBuilder.gd:87`; `FlowStageState.gd:97` | Emotional state | morale, **raw fear** (changed by D-91 S1: the larger of fear and base fear, through `EmotionStatusLean`) | Status (ten states) | What the player sees | KEEP. This is the one reading. |
| 2 | `ConversationService.gd:104`, `:593-597`; `SituationEngagementService.gd:282,357,471,535` | Emotional state | morale, fear | Status, then three code bands (`_emotional_fit_band`) | Dialogue fit and engagement before/after | KEEP. Already the shared state. |
| 3 | `MovementStyleService.gd:165-166`, fed by `BehaviorArbiter.gd:776` | Fear | `max(f, b)` | Linear x `fear_weight` | Route shape (careful, forceful ...) | MERGE |
| 4 | `MovementStyleService.gd:168-170`, fed by `BehaviorArbiter.gd:777` | Morale | morale | Tier x `morale_bias` | Route shape | MERGE |
| 5 | `BehaviorArbiter.gd:1699,1762-1766` | Fear | `max(f, b)`, composure | Linear x `fear_active_dampen` | Which plan wins (attack, guard ...) | MERGE (large change; see 1.4) |
| 6 | `BehaviorArbiter.gd:1769-1770` | Morale | morale | Tier x `morale_action_muls` | Which plan wins | MERGE (large change) |
| 7 | `BehaviorArbiter.gd:1834` (`fear_move_bonus`) | Fear | `max(f, b)` | Linear x Calling bonus | Plan score | KEEP (Calling signature, not a second fear reading; it uses the row 5 input) |
| 8 | `ActorStateMachine.gd:234-246` | Fear, Standing | raw fear | Raw against a threshold by Standing band (65, 80, 88, 95) | Refusal (Absolute Fear Rule) | KEEP. A separate system: a hard threshold set by Standing. |
| 9 | `StopShortService.gd:130-137` | Fear | `max(f, b)` | **Own ramp, 20 to 45** | Stop short | CONFLICT with row 11 (two fear ramps) |
| 10 | `StopShortService.gd:140-141` | Morale | morale | Tier x `morale_strength` | Stop short | MERGE |
| 10b | `StopShortService.gd:172-181` | Fear and morale | rows 9 and 10 | `max(fear_s, morale_s)` x affinity | Stop short | KEEP the combine rule. It already combines the two by `max`. |
| 11 | `BehaviorArbiter.gd:698,1402-1427` (slice 2) | Fear | `max(f, b)` | **Own ramp, 20 to 70** x `fear_lean_bound` | Exposure acceptance | CONFLICT with row 9. MERGE. |
| 12 | `MaturityExpressionService.gd:186,202` (slice 3 path) | Fear to Judgment | `max(f, b)` | Linear x `fear_pressure_weight` 0.25 | Judgment value | MERGE. Morale is absent here. |
| 13 | `MaturityExpressionService.gd:187-188,216-233` | Fear to composure | `fear_base`; `fear_current - fear_base` | Linear | Composure value | KEEP. Composure is one value (see 1.3). |
| 14 | `MaturityExpressionService.gd:190,212` | Morale to Presence | morale | Linear | Presence (leaders) | KEEP. Not a movement decision. |
| 15 | `BehaviorArbiter.gd:350,697,1744-1746` | Judgment | Judgment `J` | `1 + J x identity_weight_scale` (0.35) | Action-layer identity bonus | KEEP. This is the one "identity grows with J" scale. |
| 16 | `BehaviorArbiter.gd:1918` | Judgment | `J` | Lerp 1.3 to 0.75 (`directive_interpretation_mul`) | Action-layer Directive bonus | KEEP |
| 17 | `BehaviorArbiter.gd:1413` (slice 3) | Judgment | `J` | `floor + (1 - floor)(1 - J)`, floor 0.6 | Acceptance of exposure | KEEP. Same `J`, one shape per layer by design (F2 in `phase-d-design.md`). |
| 18 | `StopShortService.gd:193-194,221-227` | Judgment | `J` | Identity `0.5 + 0.5 J`; Directive `floor + (1 - floor)(1 - J)` | Stop short | KEEP. Same `J`. |
| 19 | `BehaviorArbiter.gd:1402-1415` and `StopShortService.gd:205-227` | Exposure tolerance `T` | Directive `exposure_tolerance` | Route: `T - offset`. Stop: `1 - T`. | Route and stop | KEEP. One value `T`, two transforms by design (D-69). |
| 20 | `BehaviorArbiter.gd:141-144` (`intent_weights.exposure_acceptance`) | Exposure (action rows) | Directive intent weights | Per-action numbers | Which plan wins | CONFLICT candidate: a second Directive number about exposure. D-69 Q1 decided it serves action choice only. Leave. |
| 21 | `StagePartyStance` (stage only) | Fear, morale, tolerance on the stage | state ramps | Own ramps | Stage traversal | KEEP. D-09: stage bounds never enter combat. |
| 22 | `MovementProfileService.gd:98-142` | Standing | Standing, aptitude | Bands 2, 3, 4 | Step capacity | KEEP. |
| 23 | `BehaviorArbiter` expression band (`band_by_standing`) and `rank_strength` | Standing | Standing | Four bands and a continuous `rank_strength` | Calling multipliers, wound chase, `J`, composure | KEEP. Standing enters Judgment and composure once. |

### 1.2 What a player could see as inconsistent

| Pair | What the player could notice |
|---|---|
| Rows 9 and 11 | The same Echo is "afraid enough to stop short" at fear 45 (full strength) but "half afraid" for exposure at fear 45 (ramp 0.5 of 20 to 70). |
| Rows 1 and 3, 5, 9, 11, 12 | The chip says "burdened" at fear 45. Movement code treats fear 45 as a point on five different lines. No code switches on the chip. |
| Row 1 and the rest | The chip used raw fear. The sim uses `max(f, b)`. They differ whenever `fear_base` is above `fear` (from birth, not only after a kill). Fixed by D-91 S1: every status reader uses the larger of the two. |
| Rows 11 and 12 | Fear moves exposure but morale does not. Fear moves Judgment but morale does not. Morale moves the style and the plan score. |
| Slice 11 and slices 5, 6 (if built with their own ramp) | A frightened seasoned Echo would be steadier in pull and reach but equally cautious about exposure (composure does not enter row 11). |

### 1.3 The one reading, per system

| System | The one reading | Where it is computed | Who reads it |
|---|---|---|---|
| Fear and morale together | **The emotional status** from `get_emotional_status(morale, max(fear, fear_base))` and one config table **status to lean** | New pure file `core/emotion/EmotionStatusLean.gd`. It calls `EmotionService`. | Slices 5 and 6 (new). Options for rows 3, 4, 5, 6, 9, 10, 11, 12. |
| Judgment | `J` from `derive_expression`, unchanged | `MaturityExpressionService.derive_expression` | Rows 15 to 18 and slice 7. No row builds a second Judgment. |
| Composure | One value from `derive_expression`, softens every state effect by `1 - 0.4 x composure` | `MaturityExpressionService.derive_expression`; scale key `composure_dampen_scale` | Row 5, slices 5 and 6. Option for row 11. |
| Exposure tolerance | `T`, unchanged | Directive entry | Rows 19 and slice 3, 4. |
| "Identity grows with Judgment" | `1 + J x identity_weight_scale` | `identity_weight_scale` (0.35) | Row 15 and slice 7. No new gain key. |

The fear input of the status is `max(fear, fear_base)`, as the sim already does at rows 3, 5, 9, 11, 12. The chip (row 1) used raw fear; D-91 S1 changed it. OPTION C1 below makes the chip use the same input.

### 1.4 Options for committed work (Jeff decides; I rework none)

Each option is the smallest change that makes the code follow the one reading. `afraid(status)` is `max(0, -lean[status])` from the new table, not softened. `bold(status)` is `max(0, lean[status])`.

| ID | Place | Smallest change | Cost |
|---|---|---|---|
| C1 | Chip input (row 1) | `EncounterSnapshotBuilder.gd:83` and `FlowEncounterState.gd:289-291` use `max(fear, fear_base)` | One line each. The chip differs from the old chip from birth wherever `fear_base` is above `fear`, not only after a kill. Built (D-89 C1, D-91 S1). Snapshot fingerprints did not move (no snapshot fingerprint test changed in phase D). |
| C2 | Slice 2 fear lean (row 11) | `_fear_lean` returns `fear_lean_bound x afraid(status)`. Drop the `fear_start`/`fear_full` read. | Bound 0.12 stays: burdened 0.066, strained 0.108, hollow 0.12. Slice 2 values move. Tests F5 and F6 are re-derived from band steps (the D-83 slope rule becomes "largest step times bound"). Low morale now also lowers exposure acceptance. |
| C3 | Slice 2 and composure (row 11) | Multiply the lean by `1 - composure_dampen_scale x composure` | Closes the gap in 1.2. One line. D-70 J3 and D-82 Q3 already point this way. |
| C4 | Fear lowers Judgment (row 12) | `fear_pressure = afraid(status)` instead of `max(f, b) / 100`. Weight 0.25 stays. | At fear 50: J drops 0.1375 instead of 0.125. Morale now lowers J. All `J` readers (rows 15 to 18, slice 7) shift slightly. **Built (D-89 C4).** Cost seen in code: calm Echoes gain Judgment, because the old pressure was `max(fear, fear_base) / 100` (an Echo with `fear_base` 20 had 0.2) and the pressure is now 0 in the grounded, whole and uncertain statuses. The stage moves too: the stage party lean reads the same Judgment (`StagePartyStance`, `ConversationService` bids). |
| C5 | Stop-short fear and morale (rows 9, 10) | `fear_strength` returns `afraid(status)`. Delete `morale_strength`. Keep `max` and affinity (row 10b). | Removes the 20 to 45 ramp. Stop values move. Config keys `stop_short.fear.floor/full` and `morale_strength` become dead and are removed. |
| C6 | Style (rows 3, 4) | `style_inputs` passes `afraid(status)` and `bold(status)` in place of `fear / 100` and the morale tier. `fear_weight` and `morale_bias` rows stay. | Moves style by under 2 points. All combat fingerprints that move for slices 5 and 6 move also here. |
| C7 | Action layer (rows 5, 6) | Fear factor uses `afraid(status)` in place of `fear / 100`. `morale_action_muls` is re-keyed by status. | Largest change. Moves every combat fingerprint. I advise a separate story. |
| C8 | `_DEFAULTS` swing value | Update with the config (section 5) | One line. |

Rows 8, 13 to 23 need no change.

## 2. GDD check (rule 4)

I searched the GDD through `docs/canon-index.md` and by `grep`. The ten emotional states are **not** in the GDD. They are defined in code and in `CONVENTIONS.md` (lines 378-417, "Emotional status tiers"). That text forbids separate morale and fear display fields.

| What changes | GDD section and line | What it says | Verdict |
|---|---|---|---|
| Fear and morale shape Echo behaviour | 11.5 "Behavior / refusal / autonomy", lines 1280, 1294-1296 | Each Echo filters intent through "traits, bonds, fear, morale ..."; `fear` shapes "immediate threat response"; `morale` shapes "follow-through, persistence, and recovery". | Supports. Note: the GDD gives fear and morale different roles. One status that combines them is a design choice of Jeff's (this rework). |
| One behaviour authority | 11.5, line 1421 | Directive, guidance, Calling, fear, morale, bonds, Standing ... "resolve through one deterministic behavior authority". | Supports the one-reading rule. |
| Fear reduces readiness | 17.1, lines 2976-2985 | Fear should "reduce readiness" and push toward "retreat". | Supports slices 5 and 6. |
| Morale and readiness | Initiative section, line 3988 | "morale may sharpen, steady, or reinforce readiness". | Supports the bold side. |
| Step capacity from state | 11.5, line 1441 | The layer "should not become a broad hidden stat-bonus tree". | TENSION for slice 6. I read the rule as about Judgment and Presence. D-82 Q6 decided slice 6. |
| Seasoned Echo shows less fear | 11.5, lines 1368-1369 | "More self-command"; "less casually swayable by noise". | Supports composure. "Composure" is code language only. |
| Standing scales own style | 11.5, lines 1365-1368 | "More internally authored"; not "more obedient". | Supports slice 7. |
| Procedural boards, no authored content | GDD "Current generation model"; line 4302 | Procedural and deterministic by seed. | No authored content here. The `boards` probe boards are test fixtures (D-84). |

No option conflicts with a stated GDD rule. The GDD does not change.

## 3. Shared lean from the emotional status (replaces the old `L_eff`)

### 3.1 The status ladder and where it lives

The ten states, worst to best, as ranked in code (`EncounterSnapshotBuilder.gd:697-709`): hollow, fraying, strained, pressed, burdened, hesitant, uncertain, grounded, whole, radiant.

| Question | Answer |
|---|---|
| Are the bands in config or in code? | **In code.** Thresholds are literals in `EmotionService.get_emotional_status` (`:210-233`). The order is a second literal table in `EncounterSnapshotBuilder._emotional_status_rank`. `data.emotion` holds drift and in-combat gains only, not bands. `ConversationService._emotional_fit_band` (`:593-597`) is a third code mapping. Moving them to config is out of scope. It conflicts with ANSWERS #83 (tunables in config). I name it. |
| Who reads the status today? | Rows 1 and 2 of section 1.1: Sanctum snapshots, conversations, engagement, venture and encounter snapshots. Combat movement reads none (it reads the four-step tier, not the status). |
| Does combat hold the inputs? | Yes. The combat actor dict has `fear`, `fear_base` and `morale`. |
| New code constant | `EmotionService.STATUS_LADDER` (worst to best). The lean file and its validator read it. The old rank function can read it in a later clean-up. |

### 3.2 The config table

Path: `data.combat.movement.felt_state.band_lean`. Allowed: each value from -1.0 to +1.0. The validator also requires: all ten keys present; values never fall along the ladder from worst to best (non-decreasing); `grounded` and `whole` exactly 0.

| Status | Condition (code) | Lean PROPOSED DEFAULT | Reading |
|---|---|---:|---|
| hollow | fear 85+ or morale 5 or less | -1.00 | Full afraid |
| fraying | fear 75+ or morale 10 or less | -0.95 | |
| strained | fear 65+ or morale 15 or less | -0.90 | |
| pressed | fear 55+ or morale 20 or less | -0.75 | |
| burdened | fear 45+ or morale 24 or less | -0.55 | |
| hesitant | the fallback (for example morale 25 to 34) | -0.25 | |
| uncertain | morale 35+ and fear under 45 | -0.10 | |
| grounded | morale 40+ and fear 40 or less | 0 | Calm |
| whole | morale 55+ and fear 30 or less | 0 | Calm |
| radiant | morale 70+ and fear 15 or less | +0.70 | Bold |

The afraid values copy the shape of the old fear ramp (fear 45 to 55 is ramp 0.5 to 0.7; fear 65 to 75 is ramp 0.9 to 1.0). The bad side is "worst wins" in code, so low morale and high fear both trigger a band. The good side needs both. So fear and morale combine without any rule of mine.

### 3.3 Formula and neutral point

1. `status = get_emotional_status(int(morale), int(max(fear, fear_base)))`.
2. `L = band_lean[status]`.
3. `L_eff = L x (1 - composure_dampen_scale x clamp(composure, 0, 1))`. At composure 1 the lean keeps 60 percent. This is the same softening the action layer uses (`BehaviorArbiter.gd:1763`; key `data.maturity_expression.composure_dampen_scale.value`, 0.4).

Neutral point: `grounded` and `whole` give `L = 0` for any composure. The default Echo (morale 50, fear 0) is `grounded`.

The old neutral rule ("fear under 20, morale 50 to 75") changes in three ways. These are the only non-zero bands that a calm fixture can reach:

| Fixture state | Status | Lean | Moves? |
|---|---|---:|---|
| Morale 50, fear 0 (default) | grounded | 0 | No |
| Morale 55 to 69, fear 30 or less | whole | 0 | No |
| Morale 70 to 75, fear 15 or less | **radiant** | +0.7 | **Yes.** The old rule called this steady. Fixtures that set morale 70 to 75 move. |
| Morale 35 to 39, or fear 41 to 44 | uncertain | -0.1 | Yes, slightly |
| Morale 25 to 34 | hesitant | -0.25 | Yes |

Composure source: slice 5 uses this activation's `context["composure"]` (`BehaviorArbiter.gd:693`). Slice 6 uses `actor["_composure"]` from the previous activation (section 6).

### 3.4 Are steps a problem? Size of the effect

I looked for a problem with band steps (a cliff at a threshold, hash sensitivity).

| Check | Finding |
|---|---|
| Hash sensitivity | None beyond today. The input is an integer pair and the output is deterministic. |
| Cliff size | Measured as decisions that differ between two adjacent states (young Echo). Whole to radiant: **7.0 percent**. Burdened to hesitant: 2.9 percent. Hesitant to uncertain: 2.0 percent. Every other step: 1.0 percent or less. |
| Is the cliff a harm? | No. The largest step is exactly where the chip changes. A kill adds 25 morale and crosses it. The player sees the state change and the behaviour change together. That is the legibility goal. |
| Blend between bands | Not needed. I show no problem that a blend fixes. |

Size by state. I re-scored the 768 logged route decisions with the same offline method as the study (new score = logged score + (m - 1) x logged weighted term; first-order; the saved parts logs of the four phase-D arms; my script reproduced the study rows 60, 84, 22 and 44 first). **The logs do not hold fear or morale per pass.** The calm arms did not print them. The fear-50 arms set fear 50 on every Echo from round 1 (so burdened or worse, morale unknown). So I cannot give the band of each logged pass. I give the ceiling: "if every Echo were in this state". `P` and `C` use the bounds in 4.1.

| State | `L_eff` young (composure 0.2) | `P` / `C` | Changed (of 768) | Of 1,037 passes | `L_eff` seasoned (0.8) | Changed, seasoned |
|---|---:|---|---|---:|---:|---|
| hollow | -0.92 | 0.68 / 1.37 | 62 (8.1 %) | 6.0 % | -0.68 | 52 (6.8 %) |
| fraying | -0.87 | 0.69 / 1.35 | 59 (7.7 %) | 5.7 % | -0.65 | 51 (6.6 %) |
| strained | -0.83 | 0.71 / 1.33 | 58 (7.6 %) | 5.6 % | -0.61 | 49 (6.4 %) |
| pressed | -0.69 | 0.76 / 1.28 | 53 (6.9 %) | 5.1 % | -0.51 | 45 (5.9 %) |
| burdened | -0.51 | 0.82 / 1.20 | 45 (5.9 %) | 4.3 % | -0.37 | 38 (4.9 %) |
| hesitant | -0.23 | 0.92 / 1.09 | 23 (3.0 %) | 2.2 % | -0.17 | 18 (2.3 %) |
| uncertain | -0.09 | 0.97 / 1.04 | 8 (1.0 %) | 0.8 % | -0.07 | 6 (0.8 %) |
| grounded, whole | 0 | 1 / 1 | 0 | 0 | 0 | 0 |
| radiant | +0.64 | 1.16 / 0.90 | 54 (7.0 %) | 5.2 % | +0.48 | 42 (5.5 %) |

On the two logged fear-50 arms with the burdened lean (young): Scout 10 of 182 decisions (5.5 %), Seek 12 of 193 (6.2 %). With the pressed lean: Scout 11 (6.0 %), Seek 15 (7.8 %).

Reading:

1. "Clear" (6 to 10 percent, D-82 Q4) starts at burdened and pressed for a young Echo, and at pressed for a seasoned one. Below burdened it is subtle.
2. Radiant is clear for a young Echo (7.0 percent) and a little under for a seasoned one.
3. Radiant is common: a kill gives +25 morale (`morale_per_kill`). Bold Echoes will be frequent after a kill. See risk R3 and Q2.
4. These are first-turn ceilings, not frequencies.

## 4. The three slices

### 4.1 Slice 5: state-scaled pull

Touch point: `select_movement_intent` computes `L_eff` once per activation near `BehaviorArbiter.gd:698`. It passes two multipliers to `_spatial_utility` (`:1437`). They multiply `objective_progress_weight` and `cohesion_weight` (`:1493-1494`). Both stay in `parts`, so `DecisionTrace` still reconstructs. About 15 lines in the arbiter. About 50 lines in the new file.

Let `t = abs(L_eff)`.

| Case | Progress `P` | Cohesion `C` |
|---|---|---|
| `L_eff < 0` | `1 - t x (1 - progress_floor)` | `1 + t x (cohesion_max - 1)` |
| `L_eff = 0` | 1.0 | 1.0 |
| `L_eff > 0` | `1 + t x (progress_max - 1)` | `1 - t x (1 - cohesion_min)` |

Rules: Echo only (`faction == "echo"`). The urgency term, commitment, exposure and every Directive term stay unscaled. The cap 28 stays. `enabled = false` returns 1.0 for both.

Stall guard: the mean progress term is 3.68 and the mean cohesion term 2.72 over all logged options. An afraid lean moves a route total by `t x (-0.35 x 3.68 + 0.4 x 2.72)` = `-0.2 t` points on average. So an afraid Echo does not prefer to stand still more. It prefers other cells. The progress floor 0.65 and the unscaled urgency term keep it moving.

### 4.2 Slice 6: step capacity

Touch point: after `derive_profile` in `LiveMovementContextService.prepare_live_movement_context` (`:166`). `derive_profile` does not change (section 6). A pure `MovementProfileService.apply_state_steps(profile, delta, capacity_cfg)`. About 30 lines.

1. Echo only (`actor_kind == "echo"`, no `authored_override`).
2. `L_eff` as in 3.3, composure from `actor["_composure"]` (section 6).
3. `delta = -penalty_steps` if `L_eff <= -penalty_at`; `delta = +bonus_steps` if `L_eff >= bonus_at`; else 0.
4. `capacity' = clamp(capacity + delta, floor, cap)` with the floor 2 and cap 6 of the capacity block.
5. If the capacity changed, append `{"source": "state_steps", "capacity": change}` to `source_terms`. Otherwise return the profile as it is.

What this means in play (PROPOSED DEFAULT `penalty_at` 0.50, `bonus_at` 0.45):

| Composure | Loses one step from | Gains one step in |
|---|---|---|
| 0.22 or less | burdened (fear 45+, or morale 24 or less) | radiant |
| 0.23 to 0.83 | pressed (fear 55+, or morale 20 or less) | radiant |
| 0.84 to 0.89 | strained (fear 65+, or morale 15 or less) | radiant |
| above 0.89 | strained | no bonus (the lean is softened below 0.45) |

By Standing (shipped formula; floor 2, cap 6): Standing 1 to 2 has base 2 (3 with agility 12 or more, or a Kra Soro). The penalty cannot act at base 2. The bonus gives 3. Standing 3 to 5: 3 becomes 2 when afraid, 4 when bold. Standing 6 and up: 4 becomes 3 or 5. The penalty never goes below 2, the capacity of every Standing 1 Echo, so it cannot cause a stall that the baseline does not allow.

### 4.3 Slice 7: Standing scales the Echo's own style (one reading)

> **Status after phase D:** slice 7 is built and wired. The multipliers `vector_mul` and `trait_mul` reach `MovementStyleService.style_alignment_score` through `style_inputs` in `BehaviorArbiter` (gate: faction `echo`; the switch is `felt_state.style_growth.enabled`). The first build computed the multipliers and dropped them; the final QA fix (D-91 B1) wired them. Test through the real decision path: `movement_arbiter/style_growth_reaches_movement_style_through_actor_state_machine`.

Reuse the scale the action layer already applies to identity (row 15): `1 + J x identity_weight_scale`. Do not add a new gain key.

| Part of style | Multiplier |
|---|---|
| `vector_bias` and `calling_family_bias` terms | `1 + J x identity_weight_scale.vector` (0.35) |
| `trait_nudge` terms | `1 + J x identity_weight_scale.trait` (0.35) |
| `fear_weight`, `morale_bias`, `bond_weight`, vow terms | 1.0 (state terms stay unscaled) |

Touch point: `MovementStyleService._score_style` (`:143-187`) gets two arguments `vector_mul` and `trait_mul` (default 1.0). The arbiter computes them from `interpretation_width` (`:697`) and `_cfg_get("identity_weight_scale")` and adds them to `style_inputs` (`:769-779`). About 12 lines.

Cost of the one-reading rule: there is no reference point. The old design had `judgment_ref` 0.3, so default fixtures did not move. Now every fixture with Judgment above 0 moves a little. A Standing 1 Echo with J 0.2 gets x1.07. A fixture with no Judgment (default 0.3) gets x1.105. From the study re-score (style x1.2 changed 8 of 768 decisions), x1.07 to x1.1 changes about 2 to 4 decisions (estimate). Standing 9 (J about 0.85): x1.30, 13 of 768 (1.7 percent of decisions; 1.3 percent of passes), an upper bound because the logged style includes state terms.

Config: only `style_growth.enabled`. `false` gives both multipliers exactly 1.0.

## 5. Swing budget with `interpretation_swing_max` 2.5

Convention (`BehaviorArbiter.gd:2001-2015`): own-side multiplier at J = 1 over Directive-side multiplier at J = 1. Values from `data/balance.json`: `identity_weight_scale` 0.35 and 0.35; `directive_interpretation_mul` 0.75 and 1.3; both `judgment_floor` 0.6; `stop_short.identity.judgment_base` 0.5.

| Layer | Decision | Own side | Directive side | Swing | Ceiling | Headroom |
|---|---|---:|---:|---:|---:|---:|
| A. Action (shipped) | Plan type | 1.35 | 0.75 | **1.800** | 2.0 per layer | 0.200 |
| B. Acceptance (slice 3) with own style (slice 7) | Route option, exposure | 1.35 (same scale as A) | 0.60 | **2.250** | 2.5 | 0.250 |
| C. Stop cause (slice 4) | Stop or walk on | 1.00 | 0.60 | **1.667** | 2.0 per layer | 0.333 |
| D. State leans (slice 5) | Route option, pull | `max(cohesion_max 1.4, progress_max 1.25)` = 1.40 | 0.60 | **2.333** | 2.5 | 0.167 |

Layer D is conservative. The lean is not scaled by Judgment, so it has no Directive factor. I pair it with the smallest floor in the decision. Slice 6 is not a layer (it changes the option set, no Directive term reads it).

How they meet in one decision: all four add inside one candidate score. They do not multiply. A ratio of sums is at most the largest ratio of its parts for terms of one sign. So one decision stays at or under 2.333. Pessimistic cross pair: largest own side 1.40 over the smallest Directive factor (0.75 / 1.3 = 0.577) = **2.426**. It fits 2.5 with 0.074 to spare. Measure from J = 0 (not adopted, D-70 J4): A 2.34, B 2.25, D 2.33 fit; C 3.33 does not. I use the shipped J = 1 convention and name this.

Tests (all read `data.maturity_expression.interpretation_swing_max.value`):

| Test | Rule | Value |
|---|---|---|
| `arbiter/interpretation_swing_within_declared_budget` (existing) | action swing at most `layer_max.action` | 1.80 <= 2.0 |
| `movement_arbiter/acceptance_swing_within_declared_budget` (changed) | `(1 + identity_weight_scale.max if style_growth on, else 1) / judgment_floor` at most value | 2.25 <= 2.5 |
| `movement_arbiter/felt_state_swing_within_declared_budget` (new) | `max(cohesion_max, progress_max if lean on) / judgment_floor` at most value | 2.333 <= 2.5 |
| `movement_arbiter/cross_layer_pair_within_declared_budget` (new) | `max(own sides) / (low / high)` at most value | 2.426 <= 2.5 |
| `stop_short/directive_swing_within_declared_budget` (existing) | `1 / floor` at most `layer_max.stop` | 1.667 <= 2.0 |
| `movement_arbiter/swing_layer_ceilings_consistent` (new) | each `layer_max` positive and at most `value` | pass |
| `movement_arbiter/acceptance_own_side_equals_identity_scale` (replaces `acceptance_own_side_has_no_judgment_input`) | Own side equals the action-layer identity scale. No other Judgment input reaches style. | |

What the raise loosens, and a guard that still bites:

| Layer | Guard at 2.0 | At 2.5 with no other change |
|---|---|---|
| A. Action | Fails above 2.0 (headroom 0.20) | Fails above 2.5 (headroom 0.70). `identity_weight_scale` could rise from 0.35 to 0.875, or `low` fall from 0.75 to 0.54, silently. |
| B. Acceptance and C. Stop (slices 3 and 4) | Floor at least 0.50 | Floor at least 0.40. The old guard no longer binds them. The validator at 0.55 (D-83 B) still does. Their own swing stays 1.67. |

Proposal: per-layer ceilings. `interpretation_swing_max.value` 2.5; new `layer_max.action` 2.0 and `layer_max.stop` 2.0. B and D use 2.5. The old guard stays where the raise is not needed. `BehaviorArbiter._DEFAULTS` (`:173`) must change with the config (option C8). With own side 1.35 on layer B, the lowest acceptance floor is 1.35 / 2.5 = 0.54. The 0.55 validator range stays valid.

## 6. Slice 6 feasibility (read from code)

| Question | Finding | Evidence |
|---|---|---|
| Computed per activation? | **Yes.** | `FlowRuntime.gd:1438` calls `prepare_live_movement_context` for each activation. It calls `derive_profile` at `LiveMovementContextService.gd:166`. The same profile feeds options (`:188`), the arbiter (`FlowRuntime.gd:1440`) and the executor. I read the code, not the comment at `:38`. |
| Saved? | **No.** | `CONVENTIONS.md` lines 780-845: "No `max_movement` is persisted to save". |
| Fixed by the COMBAT-002 contract? | The **formula** is frozen (`max(standing, aptitude)`, floor 2, cap 6). The **range** is a contract: 0 to 6; capacity 1 needs an authored override (`MovementProfile.gd`; `MovementContractValidation.gd:82-88`). | Floor 2 keeps every state change valid. |
| Other users of `derive_profile`? | `PaceService._mean_capacity` (`PaceService.gd:136`) for the par. The guide spirit (authored override). | Both stay unchanged if the state change comes after `derive_profile`. |

Smallest correct change: leave `derive_profile` alone (the par must not depend on transient fear). Add `apply_state_steps` after `:166`. `ProtectCustodyService` removes one step after this point and guards the capacity-1 rule itself. A test covers a frightened carrier at capacity 2.

Timing trap: the profile is built before composure exists. Composure is computed later in `ActorStateMachine` (`:173-190`).

| Option | Change | Result |
|---|---|---|
| O1 (default here) | Read `actor["_composure"]` from the previous activation. The actor dict is kept by reference (`ActorStateMachine.gd:90`). Use `steps.composure_default` if missing. | About 4 lines. One activation old. Deterministic. |
| O2 | Call `derive_expression` inside `prepare_live_movement_context` | Exact. The prepare signature takes the turn context. Many call sites and tests change. |
| O3 | No composure in slice 6 | Breaks D-82 Q3 for this slice. |

## 7. Config block

All PROPOSED DEFAULT. Path `data.combat.movement.felt_state`. A missing block means all three slices off.

```
"felt_state": {
  "band_lean": { "hollow": -1.0, "fraying": -0.95, "strained": -0.9, "pressed": -0.75,
                 "burdened": -0.55, "hesitant": -0.25, "uncertain": -0.1,
                 "grounded": 0.0, "whole": 0.0, "radiant": 0.7 },
  "lean":  { "enabled": true, "progress_floor": 0.65, "progress_max": 1.25,
             "cohesion_max": 1.4, "cohesion_min": 0.85 },
  "steps": { "enabled": true, "penalty_at": 0.5, "bonus_at": 0.45,
             "penalty_steps": 1, "bonus_steps": 1, "composure_default": 0.4 },
  "style_growth": { "enabled": true }
}
```

| Key | Allowed range |
|---|---|
| `band_lean.*` | -1.0 to 1.0; non-decreasing along the ladder; `grounded` and `whole` exactly 0 |
| `lean.progress_floor` | 0.5 to 0.9 |
| `lean.progress_max` | 1.0 to 1.4 |
| `lean.cohesion_max` | 1.0 to 1.45 (swing budget) |
| `lean.cohesion_min` | 0.7 to 1.0 |
| `steps.penalty_at` | 0.3 to 0.9 |
| `steps.bonus_at` | 0.4 to 1.0 |
| `steps.penalty_steps`, `bonus_steps` | 0 or 1 (0 turns that side off) |
| `steps.composure_default` | 0 to 1 |

Removed from the first version: `morale_low_*`, `morale_bold_*`, `style_growth.gain`, `style_growth.judgment_ref`. Also changed: `data.maturity_expression.interpretation_swing_max.value` 2.0 to 2.5, plus `layer_max.action` 2.0 and `layer_max.stop` 2.0 (if Q3 is A).

OFF arm: set `lean.enabled`, `steps.enabled` and `style_growth.enabled` to `false` (or remove the block). Then no score, profile, `source_terms` entry or saved field changes, and `actor["_composure"]` is not read. Gameplay does not read `interpretation_swing_max` or `layer_max` (only tests and `_DEFAULTS`). The OFF arm equals pre-slice behaviour.

## 8. Tests

No fight probe. Names use the existing `suite/name` style. A new suite `felt_state` holds the pure tests.

| ID | Test | Intent |
|---|---|---|
| T3-1 | `felt_state/band_table_valid` | All ten keys; range; non-decreasing along `EmotionService.STATUS_LADDER`; `grounded` and `whole` exactly 0 |
| T3-2 | `felt_state/lean_follows_the_shared_status` | For a grid of (morale, fear), the lean equals `band_lean[get_emotional_status(...)]`. Proves one definition. |
| T3-3 | `felt_state/fear_and_low_morale_combine_by_the_status` | Fear 50 with morale 50 and fear 0 with morale 20 give the status the code gives; fear 50 with morale 20 gives the worse of the two (pressed) |
| T3-4 | `felt_state/composure_softens_all_leans` | Composure 1 gives 0.6 of the composure-0 lean, using `composure_dampen_scale` from config. Afraid and bold. |
| T3-5 | `felt_state/neutral_states_give_zero` | Grounded and whole give `P == C == 1.0` exactly. The non-zero calm cases of 3.3 are listed and tested. |
| T5-1 | `felt_state/afraid_contrast` and `bold_contrast` | Pressed against grounded: `P < 1`, `C > 1`. Radiant: `P > 1`, `C < 1`. Inside bounds. |
| T5-2 | `felt_state/bounds_hold_at_extremes` | Hollow and radiant stay inside the config bounds |
| T5-3 | `movement_arbiter/afraid_echo_ends_nearer_allies_than_calm` | Two-option fixture. Calm takes forward. Pressed takes near. |
| T5-4 | `movement_arbiter/radiant_echo_ends_further_forward` | Mirror |
| T5-5 | `movement_arbiter/seasoned_afraid_leans_less_than_young` | Composure 0.8 against 0.2 |
| T5-6 | `movement_arbiter/afraid_echo_still_advances_on_clear_board` | Hollow, composure 0, clear board: the end cell is nearer the objective than the origin |
| T5-7 | `movement_arbiter/enemy_has_no_felt_state_lean` | Enemy at hollow scores equal to the same enemy at grounded |
| T5-8 | `movement_arbiter/state_lean_off_matches_block_absent` | Scores bit-equal |
| T5-9 | `decision_trace/score_reconstructs_with_state_lean` | `parts` sum to the score |
| T6-1 | `movement_profile/state_steps_thresholds_match_table` | The four composure rows of 4.2 |
| T6-2 | `movement_profile/state_steps_never_below_floor_or_above_cap` | Standing 1 plain Echo hollow keeps 2; capacity 6 radiant keeps 6 |
| T6-3 | `movement_profile/state_steps_bonus_acts_at_standing_1` | 2 becomes 3 in radiant (composure 0.2) |
| T6-4 | `movement_profile/state_steps_off_profile_identical` | Deep equal to `derive_profile`, with `source_terms` |
| T6-5 | `movement_profile/state_steps_echo_only` | Enemy, structure, authored override unchanged |
| T6-6 | `movement_profile/derive_profile_ignores_state` | The par stays stable |
| T6-7 | `protect_custody/frightened_carrier_keeps_valid_profile` | Capacity 2 carrier passes `validate` |
| T6-8 | `live_movement/profile_follows_state_each_activation` | Real `prepare_live_movement_context`. Same Echo, state changes between two activations. Options and executor wall follow. |
| T6-9 | `live_movement/composure_comes_from_previous_activation` | Documents the lag and the default |
| T7-1 | `movement_style/identity_scale_matches_action_layer` | The style multiplier equals `1 + J x identity_weight_scale` for each group |
| T7-2 | `movement_style/state_terms_untouched_by_judgment` | Fear, morale, bond and vow parts equal at multiplier 1.0 and 1.35 |
| T7-3 | `movement_arbiter/seasoned_echo_shows_more_own_style` | Standing 9 against Standing 1 |
| T7-4 | `movement_arbiter/style_growth_off_exact` | Bit-equal |
| TS | The seven swing tests of section 5 | Read the same key |
| TW-1 | `actor_state_machine/felt_state_reaches_route_choice` | Real `advance_turn`. Same board. Pressed against grounded. The end cell differs. Mirrors `fear_lean_reaches_arbiter_through_turn_context`. |
| TW-2 | `actor_state_machine/composure_reaches_lean_from_derive_expression` | Composure from `derive_expression`, not injected |
| TW-3 | `felt_state/all_switches_off_equals_pre_slice` | Existing pinned fixtures pass with the three flags `false` |

Boards probe addition (`tools/ExposureChoiceBoards.gd`, `-- tests spatialprobe boards`, 30 seconds, prints only; boards are test fixtures, D-84):

| Row | Prints |
|---|---|
| F-1 | One Echo with two allies; a forward cell and a near-ally cell. For the states grounded, burdened, pressed, hollow, radiant and Standing 1 and 9: the chosen cell and the smallest progress advantage (in cells, as `FLIP_TABLE` does) at which the forward cell wins |
| F-2 | Capacity and option count for Standing 1, 3, 6, 9 against the same states (pure calls) |
| F-3 | Style score of one route shape for production J at Standing 1, 6, 9 |
| F-4 | Afraid Echo with lean, steps and stop-short all on: cells moved |

## 9. What an observer sees

> The slice 7 row below is true since the final QA fix (D-91 B1). Before that fix the multipliers were not used. Stage party readiness (and so effective steps) now also follows the status (D-91 stage align): the stage also moves with the same state.

| State | What the Echo does |
|---|---|
| Grounded or whole (the default) | As before |
| Uncertain, hesitant | Almost nothing. Sometimes ends one cell nearer the group. |
| Burdened | Stays near allies and closes less ground. A young Echo (composure up to 0.22) walks one step less (from Standing 3 up). |
| Pressed | The same, stronger. All but the most composed Echoes walk one step less. |
| Strained, fraying, hollow | The strongest pull to the group. Everyone walks one step less. (Refusal can still start by Standing, row 8.) |
| Seasoned, same state | Shows the same signs, weaker and later. Keeps full steps in burdened. |
| Radiant | Pushes ahead and drifts from the group. Walks one step more unless very composed (above 0.89). |
| Standing 1 | Never loses steps (floor 2). Can gain one. |
| Standing 9, calm | No state effect. Its own manner shows more (x1.30 on identity style). Quiet. (Slice 7 is wired since the final QA fix, D-91 B1.) |

The chip and the behaviour change at the same moment. No number needs to show.

## 10. Risks and recorded values

| # | Risk | Guard |
|---|---|---|
| R1 | Composure is one activation old in slice 6 (O1) | T6-9. O2 if Jeff wants exact. |
| R2 | Frightened parties win later; the par bonus shrinks. The par ignores state. | T6-6 keeps the par stable. Play check. |
| R3 | Radiant is common after a kill (+25 morale). Bold Echoes drift from the group often. Not measured: the logs have no morale. | Boards F-1. Switch off or `bonus_steps` 0. Q2. |
| R4 | Lean, steps and stop-short together make an afraid Echo very passive | Floor 2. T5-6. F-4. |
| R5 | Sizes come from 7 fixed fights, first turn | Named. V2-STAGE-010 watch note (D-85). |
| R6 | A bad `felt_state` block discards the board (legacy fallback fails the suite) | T3-1 and the validator, as for `exposure_acceptance`. |
| R7 | Slice 7 is quiet and loses the exact neutral point (4.3) | Q4. |
| R8 | The chip uses raw fear, the sim `max(fear, fear_base)` | Option C1. (closed by D-91 S1) |
| R9 | Slices 2, 3 (J path) and stop-short keep their own fear lines unless Jeff takes C2, C4, C5 | Section 1.4, Q5. |
| R10 | Tension with GDD 11.5 line 1441 for slice 6 | Q1. |
| R11 | Spatial cap 28 clips a bold chase (logged maximum 27.6) | Bounded. |

Recorded values that may move:

| Value | Moves? |
|---|---|
| Default calm fixtures (morale 50, fear 0, grounded) for slices 5 and 6 | No |
| Fixtures with morale 70 to 75 and fear 15 or less; fixtures in uncertain or hesitant | Yes (3.3) |
| Any fixture with Judgment above 0 (slice 7, x1.07 to x1.1 on identity style) | Yes, slightly |
| `FlowFingerprintTests` (Scout), `FlowFingerprintSeekTests` (Seek), `FlowSnapshotFingerprintTests` | Likely. Real fights reach burdened and radiant. The lean is Directive-blind, so Scout and Seek move together. |
| `MovementArbitrationTests.gd:1484` (swing equals `1 / floor`) and `acceptance_own_side_has_no_judgment_input` | Change by design |
| Par values | No (`derive_profile` unchanged) |
| Slices 1 to 4 values | No, unless Jeff takes C2 to C5 |

D-86: one recorded-value run for slices 5 to 7. The OFF arm separates them from earlier work.

## 11. Questions only Jeff can answer

| # | Question | Options | Advice |
|---|---|---|---|
| Q1 | Slice 6 gives a radiant Echo one extra step. No GDD line supports a morale step bonus (section 2). Keep it? | A: keep penalty and bonus. B: penalty only (GDD 17.1). | A. It shows emotion in movement. It does not depend on Standing. Choose B for strict GDD fit. |
| Q2 | Fear and morale now combine by the status (this answers "does low morale join fear": yes). Radiant (morale 70+, fear 15 or less) is the only bold state and is common after a kill. Radiant lean 0.7 means a visible change at every kill. Accept? | A: lean 0.7. B: lean 0.5 (subtler; about 4 percent of decisions for a young Echo). C: no bold lean (afraid side only). | A. The player sees the chip turn radiant and the Echo push. B if play shows too much drift. |
| Q3 | Guard after the budget rises to 2.5? | A: per-layer ceilings (`layer_max.action`, `.stop` 2.0). B: one ceiling 2.5. | A. B loosens the action layer from 0.20 to 0.70 headroom. |
| Q4 | Slice 7 is quiet (about 1.3 percent of passes at Standing 9) and, with one reading, has no neutral point. Accept? | A: accept. B: keep a reference point (a new `judgment_ref` key and a new gain; a second reading of "identity grows with J"). | A. B breaks D-87. |
| Q5 | Committed code reads fear in other ways (section 1). Which options do you take? | A: none now; document the differences. B: C2, C3, C4, C5 and C1, inside the one recorded-value run. C: all of C1 to C7 in a later story. | B. It removes the two fear ramps (rows 9 and 11) and puts morale into exposure and Judgment, inside the single run D-86 already gives. C6 and C7 move every combat fingerprint, so they wait (C). |

## 12. Deferrals

| Item | Goes to |
|---|---|
| Fall-back goal | V2-COMBAT-004 (D-07, D-82 Q8) |
| Player signal for a lean (glyph) and any player text | `ui-ux-designer`, `game-feel-developer`, Jeff |
| Moving the status thresholds from code to config | Not in this story (ANSWERS #83) |
| Enemy leans, stage traversal | Not planned, not touched |
| C6, C7 (style, action layer) | A later story, if Jeff takes Q5 option C |
| Final values | `mid-game-designer`, after Jeff approves |

## OPEN — questions and assumptions

ASSUMED: The fear input of the shared status is `max(fear, fear_base)`, as the sim does at rows 3, 5, 9, 11 and 12. | WHY: EMOTION-003 floors fear on purpose, and four sim readers already use it. | WRONG IF: Jeff wants the chip's raw fear (then slices 5 and 6 use raw fear, and C1 is not needed).
ASSUMED: The afraid lean values copy the old ramp shape (burdened 0.55 to hollow 1.0). | WHY: It keeps slice 5 and 6 sizes close to the first design. | WRONG IF: Jeff wants a weaker or stronger start at burdened. Only the table changes.
ASSUMED: Slice 7 reuses `identity_weight_scale` for both style groups and loses the neutral point. | WHY: D-87 forbids a second reading. | WRONG IF: Jeff prefers a neutral point (Q4 B).
ASSUMED: Composure of the previous activation is good enough for slice 6 (O1). | WHY: Smallest change; the actor dict persists by reference (`ActorStateMachine.gd:90`). | WRONG IF: Jeff wants exact composure (O2), or a fixture builds a fresh actor for each activation.
ASSUMED: The offline re-score on the 4 saved arms is a fair size guide. The logs hold no per-pass fear or morale, so sizes are ceilings per state. | WHY: The method reproduced the study rows. | WRONG IF: Real fights sit mostly in uncertain or radiant states. Then the real share differs from the table.
ASSUMED: A ratio of sums is at most the largest ratio of its parts, so one decision stays under 2.333; the pessimistic pair is 2.426. | WHY: Standard for terms of one sign. | WRONG IF: A term changes sign inside one decision.
BLOCKED: Which `fingerprint_*` suites move. | CHECKED: Suite names in `tests/`; study 1.6. No fixture read for morale or fear. | NEED: The single D-86 run, or a grep of fingerprint fixtures for fear, morale and Judgment.
BLOCKED: How often combat Echoes are radiant, burdened or worse in real play. | CHECKED: `par/*.out` (no morale, no per-pass fear); `data.emotion` gains (kill +25 morale, hit +2 fear). | NEED: A print-only log of the status per pass, or the single D-86 run with status printed.
BLOCKED: Q1 to Q5 (design numbers and UX). | CHECKED: `decisions.md` D-81 to D-86, GDD 11.5, 17, `CONVENTIONS.md` 378-417. | NEED: Jeff's choice for each.
