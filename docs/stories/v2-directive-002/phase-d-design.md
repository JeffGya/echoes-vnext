# V2-DIRECTIVE-002 phase D — design note: combat expression and stop-short Directive cause

Status: DESIGN ONLY. No code, data or test changed. Author: sr-game-designer. First version 2026-10-16. Extended 2026-10-16 for D-70 (J2 = fear lean and Judgment scale, both inside phase D).

> **Status after phase D (docs pass, 2026-10-18):** phase D is built and committed on draft PR 108. Passages about the fear ramp (`fear_start`, `fear_full`, `state_ramps`), the slope and pre-start rules, and the shared ramp helper are **superseded by D-89 (C2, C3, C4, C5) and D-91**. Fear and morale now enter movement only through the emotional status (`core/emotion/EmotionStatusLean.gd`, table `data.combat.movement.felt_state.band_lean`). The Judgment floor key is `data.combat.movement.directive_judgment.judgment_floor` (D-88). The swing budget is 2.5 with `layer_max` 2.0 for the action and stop layers (D-82 Q5, D-89 Q3). Marked passages stay as history.

Inputs: D-05, D-08, D-09, D-10, D-14, D-69, D-70 (`decisions.md`), `design.md` lines 31, 100, 320, 349, ANSWERS #81 to #83, Working GDD sections 11.5, 10.6, 17.1, 22.4.
Every number here is `PROPOSED DEFAULT`. `mid-game-designer` authors the final values.
Player-facing text is Jeff's wording (D-69 Q6). This note proposes none.
Internal names in this note (`cause_id`, config keys) never reach the player.

---

## 0. What phase D builds (one paragraph)

Phase D has four parts. Each part is one named cause of change (section 10).

1. Combat exposure acceptance comes from the Directive's `exposure_tolerance` minus an offset (D-69 Q1).
2. Fear lean: fear lowers acceptance. A frightened Echo shies from exposure (D-70 J2 B).
3. Judgment scale: Judgment scales the Directive part of acceptance down. A seasoned Echo leans on its own exposure habit (D-70 J2 C).
4. The Directive is a third stop-short cause beside fear and identity. Judgment lowers it (D-69 Q3, Q4, Q5).

The acceptance weight rises to 17 (D-73). D-73 replaces the D-70 J1 range (8 to 14). The probe sweep covered 0, 2, 8, 11, 14, 17, 19.
Fear lowers Judgment, and we accept that (D-70 J3).
The Judgment floors are 0.6 and `interpretation_swing_max` stays 2.0 (D-70 J4). (superseded by D-82 Q5 and D-89 Q3: `interpretation_swing_max.value` is 2.5; `layer_max.action` and `layer_max.stop` are 2.0.)
Seek rarely has a Directive stop (D-70 J5).

---

## 1. Pillar check — does each decision show an Echo growing?

Pillar (Jeff, 2026-10-16): the core of the game is to watch Echoes grow over time and watch their behaviour change with it.

### 1a. What Standing, Judgment and fear mean in the Working GDD

| GDD source | Quote | Meaning for phase D |
|---|---|---|
| 11.5 "Storyweight, Step, Standing" | "`Standing` = the major maturity threshold" | Standing is maturity, not power. |
| 11.5 "Hidden maturity-expression layer" | "low-Standing Echoes should feel more externally authored" | A young Echo follows the Directive closely. |
| same | "high-Standing Echoes should feel more internally authored" | A seasoned Echo acts from its own nature. |
| same | "higher Standing should not mean more obedient, more tactically optimal, or more generally compliant" | Every Directive term falls with Judgment. None rises. |
| same | "it should mean more self-command, more interpretation, more opinion, and more consequence when identity is crossed" | Own causes (identity, fear) stay or rise. Only Directive terms fall. |
| same | "higher-Standing Echoes should be less casually swayable by noise, but more sharply affected by true contradiction" | Fear is not scaled by Judgment. A true fear still moves a seasoned Echo. |
| 11.5 "Behavior / refusal / autonomy" | "most autonomy friction should modify planned action rather than replace it" | Directive terms get weaker. They do not switch off or turn into a refusal. |
| 11.5 same, Realm direction | "most contradiction should first appear as reinterpretation, hesitation, substitution, or altered emphasis" | Fear lean is hesitation. The Judgment scale is reinterpretation. Both are "altered emphasis". |
| 11.5 same, in-combat guidance | "higher Standing means more coherent judgment and self-assertion, never increased obedience" | Same rule. One behaviour authority: one Judgment value (J3). |
| 17.1 Fear | Fear is an Echo state that bends choices. | Fear lean reads the Echo's current fear. It is a state lean, not a disposition. |
| 10.6 | "Story recovery must alter: Echo growth …" | Growth must be visible in play, not only in a number. |
| 22.4 | "Echoes are not obedient units" | A first-session test of the pillar. |
| `design.md:31` (stage rule) | Fear: "Exposure tolerance down (primary)", NOT scaled by Judgment | Fear lean copies this rule in combat. |

Note on D-69 Q4 option B: "higher Standing obeys less" fits the GDD quotes above.
It does not mean "more disobedient". The Echo's own causes take over (section 1c).

### 1b. Pillar table — each decision

| Decision | How it shows growth | Gap |
|---|---|---|
| Q1 acceptance = tolerance minus offset | Contrast between Directives (Scout and Seek). | CLOSED by D-70. Without the next two rows, movement exposure would not mature. |
| J2 B fear lean | The same Echo changes between a calm fight and a frightened fight. This is state, not growth. It makes fear visible in movement. | None. |
| J2 C Judgment scale on acceptance | The same Echo, same Directive, moves differently at Standing 1, 6 and 9. This is the growth signal in movement exposure. | Bounded by the swing budget (section 3, layer B). |
| Q2 old `exposure_acceptance` stays for action choice | `_directive_bonus` already scales by Judgment. Growth already shows there. | None new. |
| Q3 stop cause = (1 - tolerance) x affinity | Contrast between Directives and between benefits. | None. |
| Q4 Judgment scales the Directive stop cause down | Young Echo stops because the Keeper asked. Seasoned Echo stops because of who it is, or walks on. | Bounded by the swing budget (layer C). |
| Q5 route formula unchanged | No new growth effect. Keeps the change small and measurable. | None. |

### 1c. The curves — young follows, seasoned reinterprets

All Directive terms move in one direction with Judgment (J, 0 to 1). Own terms move in the other direction or stay flat.

| Term | Judgment scale | At J = 0 | At J = 1 | Direction |
|---|---|---|---|---|
| Action Directive pull (shipped) | `lerp(1.3, 0.75, J)` | 1.30 | 0.75 | falls |
| Action identity bonus (shipped) | `1 + 0.35 x J` | 1.0 | 1.35 | rises |
| Acceptance, Directive part (new) | `floor_a + (1 - floor_a) x (1 - J)` | 1.0 | `floor_a` | falls |
| Acceptance, fear lean (new) | none | 0 | 0 | flat in J. Rises with fear only. |
| Acceptance, own habit (shipped as style alignment) | none | flat | flat | flat. It is not scaled by J today (section 3, assumption A7). |
| Stop cause, Directive (new) | `floor_s + (1 - floor_s) x (1 - J)` | 1.0 | `floor_s` | falls |
| Stop cause, identity (shipped) | `judgment_base + (1 - judgment_base) x J`, base 0.5 (`StopShortService.gd:191-192`) | 0.5 | 1.0 | rises |
| Stop cause, fear (shipped) | none | 1.0 | 1.0 | flat. Fear lowers J through `fear_pressure_weight` (0.25). |

`best_cause` takes the strongest stop cause per benefit. It does not add them (`StopShortService.gd`, `best_cause`).
So the Directive and identity stop curves cross. The Echo's stop changes owner as it grows.

Worked example for stops (PROPOSED DEFAULT: `floor_s` 0.6, guard affinity 1.0, anchor family guard affinity 0.8).
The J values per Standing are ILLUSTRATIVE. The probe measures the real ones (section 8).

| Echo | J | Directive scale | Scout Directive guard strength | Identity guard strength (anchor) | Winner |
|---|---|---|---|---|---|
| Standing 1 | 0.2 | 0.92 | 0.644 | 0.48 | Directive |
| Standing 6 | 0.5 | 0.80 | 0.560 | 0.60 | Identity |
| Standing 9 | 0.85 | 0.66 | 0.462 | 0.74 | Identity |

The curves cross near J = 0.44 for this pair.

What the player sees over time (in actions, not numbers):

| Standing | What the player sees |
|---|---|
| 1 | Under Scout Carefully, the Echo keeps clear of exposed cells and pauses to guard or watch before danger. All Echoes look alike, except that Calling and fear give some contrast (D-08). Under Seek Signs, the Echo takes exposed cells and almost never pauses for the Directive. |
| 6 | The Scout Echo still keeps to cover, but less strictly. Anchor-minded Echoes still pause, now because of who they are. Edge-minded Echoes pause less and push on. The same Directive gives different behaviour per person. A Seek Echo is a little more careful than at Standing 1. |
| 9 | The Directive is a hint, not a leash. A seasoned Echo uses its own habit for exposure. It pauses when its own nature or real fear says so. It may walk on under Scout. A Scout order and a Seek order look closer together than at Standing 1, but never the same (floors). |

The player learns "this Echo has become someone" by comparing one Echo across fights. This is the growth signal. It needs no number on screen.
Fear shows as a second, separate signal. The same Echo, in the same Standing, keeps further from exposure when it is frightened.

---

## 2. Formulas

### 2a. Combat acceptance (Q1, J2 B, J2 C) — the exact combined formula

Inputs, resolved once per Echo per turn (they do not change between candidates):

| Symbol | Meaning | Source |
|---|---|---|
| `T` | `exposure_tolerance` of the active Directive. Scout 0.3, Seek 0.8 (shipped). | The one Directive accessor from phase A. |
| `offset` | 0.5 (PROPOSED DEFAULT) | Config, sibling block (section 6). |
| `J` | Judgment, clamped 0..1 | The value `BehaviorArbiter` already reads from `context.judgment` (`BehaviorArbiter.gd:695-696`, the same value as `interpretation_width`). No second Judgment value. |
| `floor_a` | 0.6 (PROPOSED DEFAULT, range 0.55 to 0.6, D-70 J4) | Config. |
| `fear` | `max(fear, fear_base)` of the actor | The same expression that `style_inputs.fear` uses (`BehaviorArbiter.gd:774`) and that `derive_expression` uses for `fear_pressure` (`MaturityExpressionService.gd:186`). |
| `ramp(fear)` | `clamp((fear - fear_start) / (fear_full - fear_start), 0, 1)` | Same shape as `StagePartyStance.echo_lean` (`fear_lean`). `fear_start` 20 and `fear_full` 70 from `data.stages.party_stance.state_ramps` (see 2b). **Superseded by D-89 (C2, C3) and D-91:** there is no ramp. The fear lean is `fear_lean_bound` x the afraid part of the status lean (`felt_state.band_lean`), softened by composure. No `fear_start` or `fear_full` is read. |
| `fear_bound` | 0.12 (PROPOSED DEFAULT) | Combat-owned config key. Start equals the stage bound `bounds.exposure_tolerance` 0.12. |
| `weight` | `directive_exposure_acceptance_weight`, 17 (D-73; the D-70 J1 range 8 to 14 is replaced) | EXISTS in `spatial_utility`. |

Order of operations:

```
1. D        = clamp(T - offset, -1, 1)                      (Scout -0.2, Seek +0.3). The code clamps D before the scale.
2. D_scaled = D x (floor_a + (1 - floor_a) x (1 - J))       Judgment scale. Sign kept. Magnitude falls.
3. F        = fear_bound x ramp(fear)                       Fear lean. NOT scaled by J.   (superseded by D-89 C2, C3: F = fear_lean_bound x afraid(status lean) x (1 - composure_dampen_scale x composure); no ramp)
4. acceptance = clamp(D_scaled - F, -1, 1)
5. term     = weight x acceptance x exposure                the existing term "directive_exposure_acceptance"
```

| Rule | Detail |
|---|---|
| Order matters | Judgment scales only the Directive part (step 2). Fear lean is added after the scale (step 3). So fear is never multiplied by J. This copies `design.md:31`. |
| Clamps | `D` is clamped to -1..1 before the Judgment scale (the code does this). `J` is clamped 0..1. `ramp` is clamped 0..1. Final `acceptance` is clamped -1..1. With the defaults the largest magnitude is 0.3 + 0.12 = 0.42, so the final clamp is a guard only. |
| Missing `T` | `D = 0`. The Judgment scale then has nothing to scale. Fear lean still applies (it is the Echo's own state). No Directive id literal anywhere (ANSWERS #81). |
| Two exposure inputs remain | `_directive_bonus` still reads `intent_weights.exposure_acceptance` for action choice (melee 0.4, guard -0.3, idle -0.2 rows). This is D-69 Q2. D-05 is amended. |
| Where it is used | `_spatial_utility`, term `directive_exposure_acceptance`. It replaces `weights.get("exposure_acceptance")` in this term only. `_spatial_utility` gets two new arguments: `judgment` and `fear`. Or the arbiter resolves acceptance once per turn in a pure static helper and passes the value. Both are the same design. `mechanics-developer` picks one. The trace must show the three parts (`D_scaled`, `F`, `acceptance`) so a designer can read them. |
| Closed schema | The block `spatial_utility` is a closed schema (`_SPATIAL_UTILITY_FIELDS` and two validators; fixtures in `MovementArbitrationTests.gd:1099`, `BehaviorArbiterTests.gd:1401`, `MovementStyleServiceTests.gd:520`). New keys live in a SIBLING block, so no schema change and no fixture change. |

The own habit. "A seasoned Echo uses its own exposure habit" needs no new term.
The habit already exists: movement style alignment (`_style_alignment`, which reads Calling family, virtue vectors, fear and morale; `style_inputs` has no Judgment key).
When the Judgment scale shrinks `D`, the habit decides more of the final choice. See question O2.

What each Echo gets (ILLUSTRATIVE J values; real values come from probe step 3; the slopes use weight 11, an illustrative value from the first version; the shipped weight is 17 (D-73)):

| Echo | J | Scale | Scout `D_scaled` | Scout `F` | Scout acceptance | Scout slope on exposure | Seek `D_scaled` | Seek `F` | Seek acceptance | Seek slope on exposure |
|---|---|---|---|---|---|---|---|---|---|---|
| Young, calm (fear 0) | 0.20 | 0.92 | -0.184 | 0 | -0.184 | -8.02 | +0.276 | 0 | +0.276 | -2.96 |
| Seasoned, calm (fear 0) | 0.85 | 0.66 | -0.132 | 0 | -0.132 | -7.45 | +0.198 | 0 | +0.198 | -3.82 |
| Young, afraid (fear 70, J drops by 0.175 to 0.025) | 0.025 | 0.99 | -0.198 | 0.12 | -0.318 | -9.50 | +0.297 | 0.12 | +0.177 | -4.05 |
| Seasoned, afraid (fear 70, J drops to 0.675) | 0.675 | 0.73 | -0.146 | 0.12 | -0.266 | -8.93 | +0.219 | 0.12 | +0.099 | -4.91 |

Slope on exposure = `-6.0 + weight x acceptance` (`exposure_weight` is -6.0). A more negative slope means the Echo keeps further from exposed cells.

Reading, by the pillar:

| Observation | Meaning |
|---|---|
| Down each Scout column pair (young to seasoned) | Scout loosens (-8.02 to -7.45). Seek tightens (-2.96 to -3.82). The two orders move toward each other as the Echo grows. This is "a hint, not a leash". |
| Calm to afraid, same Standing | Both Directives get shyer (more negative slope). Fear shows in movement. |
| Seasoned and afraid, Seek | Slope -4.91. A frightened veteran under Seek is clearly more careful than a calm young one (-2.96). This is "fear stops a seasoned Echo". It is hesitation, not refusal: the slope stays negative, so exposure is still a cost, not a ban. |
| Gap between Scout and Seek | Young 0.46, seasoned 0.33 (acceptance units). Never zero. |

Effect size of the weight (unchanged from the first version). The term is `weight x acceptance x exposure`. It competes with `exposure_weight` (-6.0) x exposure.

| Weight | Scout slope (calm young) | Seek slope (calm young) | Reading |
|---|---|---|---|
| 2.0 (shipped) | -6.4 | -5.4 | Almost no contrast. combat-003 measured that this term first decides turns at weight 15 to 20 (`v2-combat-003/handoff.md:1690-1730`, with acceptance 0.2). |
| 8 | -7.5 | -3.8 | Visible contrast likely. |
| 11 | -8.0 | -3.0 | |
| 14 | -8.6 | -2.1 | |
| 17 (shipped, D-73) | -9.1 | -1.3 | Seek still pays for exposure (slope below 0). The probe showed the term changes decisions from weight 14 up. |
| 20 | -9.7 | -0.5 | Seek nearly treats exposure as free. Too far. |

Rule to protect: `weight x max(acceptance) < |exposure_weight|`. The largest possible acceptance is `max(T) - offset` at J = 0 and no fear (+0.3), so 17 x 0.3 = 5.1 < 6.0 at the shipped weight 17 (D-73). Above the rule, exposure becomes an attractor for Seek (combat-003 section 22.4: "a sign switch on exposure").
At weight 17 the rule fails for any Directive with `exposure_tolerance` of 0.853 or more (0.5 + 6/17). The test `directive_cfg/exposure_acceptance_never_attractor` catches a new Directive that does this (D-73).
Phase D adds a config-integrity test for this rule (section 6).

### 2b. Where the fear ramp comes from (the same shape, one source) (superseded by D-89 C2 and D-91)

`StagePartyStance.echo_lean` computes `fear_lean = clamp((fear - fear_start) / (fear_full - fear_start), 0, 1)`, with `fear_start` 20 and `fear_full` 70 in `data.stages.party_stance.state_ramps`. It multiplies by coefficient `-1.0` (`leans.exposure_tolerance.fear`) and by the bound 0.12 (`bounds.exposure_tolerance`).

| Piece | Stage | Combat (this design) |
|---|---|---|
| Ramp start and end | `state_ramps.fear_start`, `fear_full` | The SAME two values. No new fear threshold. |
| Shape | linear 0..1 | The same. |
| Sign and size | coefficient -1.0 x bound 0.12 | `fear_bound` 0.12, sign negative by rule. Combat-owned key. |
| Judgment scale | none (state lean) | none |
| Fear value | `actor.fear` | `max(fear, fear_base)`, as the arbiter already reads fear (ASSUMED A8). |

Ramp reuse rule. One pure helper owns the ramp, so stage and combat cannot drift. It reads the two ramp values from `data.stages.party_stance.state_ramps`. **Superseded by D-89 C2 and D-91:** the ramp helper and `state_ramps` are gone. Stage and combat both read the emotional status through `EmotionStatusLean` and the band table `data.combat.movement.felt_state.band_lean`. The stage block is not read by combat at all.
This touches test C14 (no stage key in combat). C14 narrows to: combat code never reads `interpretation_width`, `leans`, `lean_strength`, `directive_profile` or `bounds` from the stage block. Only `state_ramps.fear_start` and `fear_full` are shared. D-09 keeps its intent: the stage Judgment bound never enters combat. ASSUMED A9.

### 2c. Directive stop cause (Q3, Q4)

```
base      = 1 - exposure_tolerance                 (Scout 0.7, Seek 0.2)
affinity  = directive.affinity[benefit]            (guard, hold large; observe small)
scale(J)  = floor_s + (1 - floor_s) x (1 - J)      (J = ctx.judgment, clamped 0..1)
strength  = clamp(base x affinity x scale(J), 0, 1)
```

The cause then goes through the normal rules: `strength >= min_cause_strength` (0.15) or it does not exist.
Bias = `stop_short_weight` (6.0) x strength. The route scoring formula does not change (Q5).

| Rule | Detail |
|---|---|
| One-way | `scale(J)` is 1.0 at J = 0 and falls to `floor_s` at J = 1. It never exceeds 1.0. |
| Floor | `floor_s` 0.6 (D-70 J4; range 0.55 to 0.6). Own key, separate from `floor_a`. |
| Cause id | A new registry row in `CAUSE_ROWS` (D-10). Internal id "directive". The `cause_strength` arm is a `match` on the id of the CAUSE, not on a Directive id. No Directive id literal in `core/` (ANSWERS #81). |
| Context | One new ctx field: the active Directive's `exposure_tolerance`. `judgment` already exists in ctx (`StopShortContextService.gd:374`; default 0.3 if the context lacks it, a fixture trap). |
| Source / code | `cause_source` and `cause_code` get new internal values. They feed the trace only. Text is Jeff's (Q6). |
| Missing tolerance | No Directive cause (strength 0). |
| New Directive key | None (ANSWERS #81, D-69 Q3). Affinity lives in `data.actor.stop_short`, not in the Directive entry. |
| Disabled stops | `stop_short.enabled = false` switches the cause off with the rest. |

Scale form options considered:

| Form | Formula | Verdict |
|---|---|---|
| F1 linear mirror of identity | `floor + (1 - floor) x (1 - J)` | CHOSEN, for both the stop layer and the acceptance layer. One shape, two keys. A designer reads one curve. |
| F2 reuse the action-layer curve | `lerp(high, low, J) / high` from `directive_interpretation_mul` (floor 0.577) | Rejected. It couples layers silently. A retune of the action layer would move stops and acceptance. |
| F3 step by Standing band | band table | Rejected. `band_by_standing` saturates at Standing 6 to 9. D-08 and the PROG-012 phase 6 fix removed band tables for this reason. |

Illustrative strengths (`floor_s` 0.6; guard 1.0, hold 0.8, observe 0.3 affinity; all PROPOSED DEFAULT):

| Directive | Benefit | J 0.2 | J 0.5 | J 0.85 |
|---|---|---|---|---|
| Scout | guard | 0.644 | 0.560 | 0.462 |
| Scout | hold | 0.515 | 0.448 | 0.370 |
| Scout | observe | 0.193 | 0.168 | 0.139 (below 0.15: gone) |
| Seek | guard | 0.184 | 0.160 | 0.132 (gone) |
| Seek | hold | 0.147 (gone) | 0.128 (gone) | 0.106 (gone) |
| Seek | observe | 0.055 (gone) | gone | gone |

Reading: Seek rarely stops for the Directive, and not at all for a seasoned Echo (D-70 J5, accepted). Scout stops for the Directive at every Standing. Observe is a weak Directive reason. This is the intended contrast.

---

## 3. Swing budget — three Directive-Judgment layers

The shipped test `arbiter/interpretation_swing_within_declared_budget` checks one ratio:
`compute_interpretation_swing = (1 + max(identity_weight_scale.trait, .vector)) / directive_interpretation_mul.low`
(`BehaviorArbiter.gd:1935-1950`). It reads `interpretation_swing_max.value`.
Convention: the own-side multiplier at J = 1 divided by the Directive-side multiplier at J = 1. Affinities are ignored.

Values from `data/balance.json`:

| Item | Value |
|---|---|
| `identity_weight_scale` trait / vector | 0.35 / 0.35 |
| `directive_interpretation_mul` low / high | 0.75 / 1.3 |
| `interpretation_swing_max.value` | **2.0** (stays, D-70 J4) (superseded: 2.5 with `layer_max`, D-82 Q5, D-89 Q3) |

### 3a. The three layers

| Layer | Decision it shapes | Own side at J = 1 | Directive side at J = 1 | Swing at the floor in D-70 | Inside 2.0? | Headroom |
|---|---|---|---|---|---|---|
| A. Action: `_directive_bonus` and identity bonus (shipped) | Which plan type wins (attack, guard, move, idle) | 1 + 0.35 = 1.35 | 0.75 | 1.35 / 0.75 = **1.80** | Yes | 0.20 |
| B. Spatial acceptance (new, J2 C) | Which route option wins (how much exposure) | 1.0 (style alignment is not scaled by J; A7) | `floor_a` = 0.60 | 1.0 / 0.60 = **1.67** | Yes | 0.33 |
| C. Stop cause (new, Q4) | Whether a route stops short | identity scale at J = 1 = 1.0 | `floor_s` = 0.60 | 1.0 / 0.60 = **1.67** | Yes | 0.33 |

At floor 0.55 (low end of D-70): B and C are 1.82. Still inside 2.0. Floor 0.50 gives 2.00 (no headroom, not allowed). The valid range of `judgment_floor` is 0.55 to 1 (D-83 B). The validator rejects a value below 0.55. The two floors must stay at or above 0.55 by test.

Layer B assumes the own side is 1.0. The guard test `movement_arbiter/acceptance_own_side_has_no_judgment_input` fails if the Echo's own style gains a Judgment input. Slice 7 must then pass the style multiplier at J = 1.

The fear lean (J2 B) is not a Judgment layer. It is not scaled by J, so it has no swing. It has its own size bound in section 4 (the monotone rule).

New test rule (for `mechanics-developer`):

| Change | Detail |
|---|---|
| Keep | `arbiter/interpretation_swing_within_declared_budget` unchanged (layer A). |
| Add | A static function beside `compute_interpretation_swing` for layer B: `own_side_mul / floor_a`, with `own_side_mul` = 1.0 unless the spatial path gains a J-scaled own term. A missing floor returns 1.0. A floor not above 0 returns INF. |
| Add | A static function for layer C: `identity_scale(J = 1) / floor_s`, from the `data.actor.stop_short` identity base and the new floor. |
| Add | Tests `movement_arbiter/acceptance_swing_within_declared_budget` (B) and `stop_short/directive_swing_within_declared_budget` (C). Both read the SAME `interpretation_swing_max.value`. |
| Why one budget key | A second key would let budgets drift. Q4 says scaling "must sit inside `interpretation_swing_max`". |
| Floor location | B: `data.combat.movement.exposure_acceptance.judgment_floor`. C: `data.actor.stop_short.directive.judgment_floor`. Each test reads the block that owns its floor. **Superseded by D-88:** one shared key `data.combat.movement.directive_judgment.judgment_floor` (minimum `judgment_floor_min`) serves B and C. |

If layer B cannot use the same convention (it can, while A7 holds), the options are:

| Option | Rule | Advice |
|---|---|---|
| 1. Same convention with a verified own-side multiplier | If a later change makes style alignment scale with J, own side = that multiplier at J = 1. | Default. |
| 2. Raise the floors | Raise `floor_a` until `own / floor_a <= 2.0`. | Use if option 1 gives more than 2.0. |
| 3. A second budget key for the spatial layer | Separate ceiling. | Advise against: budgets drift. Needs Jeff's approval. |

### 3b. Do the layers stack in one decision?

Yes, in one decision, but additively. They never multiply.

| Question | Answer |
|---|---|
| Do A and B meet in one candidate score? | Yes. A route candidate gets `_directive_bonus` for its plan type (layer A) and `_spatial_utility` (layer B) in the same score (`BehaviorArbiter.gd:787-810`). |
| Do they compare the same thing? | Mostly not. A is the same for every route option of one plan (`_score` runs once per candidate with the plan type; the options of one plan differ by `_spatial_utility`, style alignment and stop bias). So A discriminates between plans. B discriminates between route options of one plan. B also shifts route candidates against stationary candidates through the exposure slope, so a small overlap with A exists. |
| Do B and C meet? | Yes, on one route option: B sets the exposure slope; C adds the stop bias. Different terms of the score. |
| How is the combined effect bounded? | Each layer adds its own Directive term to the score. Each Directive term falls by its own factor in `[floor, 1]` as J rises (A: 0.577, B: 0.60, C: 0.60 of its J = 0 value). A sum of terms, each scaled by a factor in `[0.577, 1]`, is scaled by a factor in `[0.577, 1]`. So the combined Directive pull of a seasoned Echo is never less than 0.577 of a young Echo's, in one decision. That is a ratio of at most 1.73. No product of layers (not 0.577 x 0.6 x 0.6). |
| Is the combined own-side to Directive swing at most 2.0? | Each layer is at most 1.80 (checked, section 3a). A cross-layer worst case pairs the largest own-side multiplier (1.35, layer A only) with the smallest Directive factor (0.577 to 0.6, layers A to C): 1.35 / 0.6 = 2.25. That pairing does not occur. The 1.35 identity growth lives in the action identity bonus. It does not scale terms in layers B and C. So the rule is per layer. The test checks each layer against 2.0. |
| Option to enforce the cross pair | Floors at or above 0.675 (`1.35 / floor <= 2.0`). This is above the D-70 range (0.55 to 0.6). Not proposed. Named so Jeff can see the limit. |

Limit to understand (same limit as the first version). The convention measures the ratio at J = 1, not the change from J = 0.
A change-from-J = 0 measure would read higher: layer A (1.35 / 0.75) / (1.0 / 1.3) = 2.34. Layer C (1.0 / 0.6) / (0.5 / 1.0) = 3.33.
That measure is not in the shipped test and D-70 J4 keeps the shipped convention (assumption A2).
The budget caps reinterpretation depth. At floor 0.6 a seasoned Echo keeps at least 0.6 of a young Echo's Directive pull in layers B and C. A bigger change needs Jeff's approval (J4).

Why the two Directive layers (A and C) do not count the same pull twice: the first version's argument holds. `_directive_bonus` is equal for all route options of one plan, so it cannot choose between stopping short and walking on. MUST VERIFY (assumption A1).

---

## 4. Double-count table — where the Directive, fear and Judgment meet in combat after phase D

| # | Place | Directive input | Judgment input | Fear input | Direction with J | Budgeted by | Double count? |
|---|---|---|---|---|---|---|---|
| 1 | `_directive_bonus` (`BehaviorArbiter.gd:1835-1860`) | `intent_weights` x `directive_action_muls` | `interpretation_width` = J, lerp 1.30 to 0.75 | via J only | falls | layer A (1.80) | Shipped. Unchanged. |
| 2 | Identity bonus in `_score` (trait, vector) | none | `1 + J x 0.35` | via composure bracket | rises | same budget (numerator) | Shipped. Unchanged. |
| 3 | `_spatial_utility`, acceptance Directive part `D_scaled` (new) | `T - offset` | `floor_a + (1 - floor_a)(1 - J)` | via J only | falls | layer B (1.67) | No. Different decision from row 1 (route option, not plan). Section 3b. |
| 4 | `_spatial_utility`, fear lean `F` (new) | none | none | `fear_bound x ramp(fear)` | flat | its own monotone rule (below) | See "fear in combat" table. (superseded by D-89: `fear_lean_bound x afraid(status)`) |
| 5 | Stop cause "directive" (new) | `(1 - T) x affinity` | `floor_s + (1 - floor_s)(1 - J)` | via J only | falls | layer C (1.67) | No. Different decision from row 1. |
| 6 | Stop cause "identity" (shipped) | none | `0.5 + 0.5 J` | none | rises | same budget (numerator) | Shipped. Unchanged. |
| 7 | Stop cause "fear" (shipped) | none | none | direct | flat | none needed | No. Fear is not scaled. |
| 8 | Stop causes 5, 6, 7 together | | | | | | No. `best_cause` takes the maximum. |
| 9 | Rows 3 and 5 on one Scout route | Both read `T` | both | | | | INTENDED STACK. Both push Scout away from exposure by different means: row 3 scores the final cell's exposure; row 5 favours a guard, hold or observe stop. Bounded as in section 3b. Measure the joint size in the probe (2 x 2). |
| 10 | Stage bound `interpretation_width` (`party_stance`) | | | | | | NEVER enters combat (D-09, `design.md:320`). Test C14 (narrowed, section 2b). |

### Fear in combat — every path, and does it count twice?

Fear now reaches movement and stops by five routes. Only two are new.

| # | Fear path | Where | Effect on exposure or stops | New in phase D? |
|---|---|---|---|---|
| F-a | Fear lowers J (`fear_pressure_weight` 0.25) | `derive_expression` | Lower J raises every Directive scale (rows 1, 3, 5) a little | Shipped; reaches rows 3 and 5 for the first time |
| F-b | Fear lean | row 4 | Lowers acceptance. Shyer. | NEW (J2 B) |
| F-c | Fear stop cause | row 7 | Stops short for fear | Shipped |
| F-d | Fear in style alignment (`style_inputs.fear`, `fear_weight`) | `_style_alignment` | Moves route style toward careful styles | Shipped |
| F-e | Fear in the composure bracket of `_score` | action layer | Dampens action scores | Shipped |

Do F-a and F-b fight in the spatial term? They push the same way for Scout and opposite ways for Seek. Numbers (illustrative, defaults, section 2a):

| Directive | F-a effect on `D_scaled` at fear 70 | F-b effect | Net | Reading |
|---|---|---|---|---|
| Scout (D = -0.2) | -0.014 to -0.021 (more negative: shyer) | -0.12 | about -0.14 | Same direction. A frightened veteran is more Directive-bound AND shyer. Both mean "more careful". Consistent. |
| Seek (D = +0.3) | +0.021 to +0.030 (more positive: bolder, because J is lower) | -0.12 | about -0.10 | Opposite direction, but F-b is 4 to 5 times larger. Net: shyer. A frightened veteran under Seek is more Directive-bound in principle, and shyer in practice. |

The largest possible F-a effect is `(1 - floor_a) x fear_pressure_weight x max|D|` = 0.4 x 0.25 x 0.3 = **0.03** (at fear 100, J large enough not to clamp at 0).
The fear lean reaches 0.12 at fear 70. So the fear lean is at least 4 times the F-a effect once `ramp` is full. (superseded by D-89 C2: the lean reaches 0.12 at the `hollow` status, not at fear 70; it steps per status band)

One readable rule (so the two never fight in play):

> "More fear never makes exposure more acceptable, except a small bounded rise in two places."

Fear lowers Judgment (F-a). A lower Judgment raises the Directive part `D_scaled`. So acceptance may rise slightly with fear in two places:

1. Just above `fear_start`, before the lean overtakes the Judgment path. The peak is 0.006 for Seek. The bound is 0.01. (superseded by D-89 C2: no `fear_start`; the rule is checked per status step, see tests F5 and F6)
2. Above `fear_full` (fear 70 to 100). The lean is flat there. The rise is at most `judgment_slope` per fear point (0.0003) and about 0.009 in total for Seek. (superseded by D-89 C2: no `fear_full`)

In both places acceptance stays below the calm value. The test tolerance is in section 5 (tests F5 and F6). The F5 test derives its window from config (D-83 A).

Config-integrity rules (test F6, section 5): the slope rule, the pre-start bound and the total bound. Defaults: slope 0.12 / 50 = 0.0024 >= 0.0003; pre-start 0.006 <= 0.01; total 0.12 >= 0.03. **Superseded by D-89 C2:** test F6 now checks two rules: (1) softened bound x largest afraid step of the band table >= the Judgment path rise `(1 - floor) x fear_pressure_weight x max abs(D) x step`; (2) softened bound >= the total Judgment path `(1 - floor) x fear_pressure_weight x max abs(D)`. The softened bound is `fear_lean_bound x (1 - composure_dampen_scale)`.
Pre-start size: below `fear_start` (fear 0 to 20) the lean is zero, so F-a alone can raise Seek acceptance by at most `0.4 x 0.25 x 0.2 x 0.3 = 0.006`. That is 0.10 score points at weight 17. (superseded by D-89 C2: no pre-start window)

Does this count fear twice by the stage rule (`design.md:31`: do not scale fear by Judgment again)? No. Fear lean is not scaled by J (step 3 follows step 2). Fear still enters J through the shipped F-a. That is the shipped, accepted path (D-70 J3). The stage has the same two paths and the same size relation.

F-b and F-d overlap (both shift exposure care for the afraid Echo). The stage has the same pair (fear lean plus `tolerance_by_style` and `MovementStyleService` tables). The lean is small by default (0.12). Probe step 9 measures the pair. If F-b plus F-d is too strong, `fear_bound` falls first. It is one key.

---

## 5. Contrast table — test targets

Test names are PROPOSED. `mechanics-developer` may rename. Suite prefixes follow the registered suites in `AGENTS.md`.
Fixtures must build Judgment through the production path (`MaturityExpressionService.derive_expression`) with real Standing and real bonds. A fixture with empty bonds or a default `judgment` of 0.3 hides the term (LESSONS: probe must mirror production construction; D-26).
Each test lands in the slice named in section 10.

| # | Contrast | Expected difference | Test name (proposed) | Slice |
|---|---|---|---|---|
| C1 | Scout vs Seek, same Echo, Standing 1, route into exposure | Acceptance -0.2 vs +0.3 in slice 1 (Judgment is not in yet); -0.184 vs +0.276 once the Judgment scale lands (illustrative). The Seek route score is higher on an exposed option. Seek takes the exposed option where Scout takes the lower one (two-option fixture). | `movement_arbiter/acceptance_scout_vs_seek_exposed_option` | 1 |
| C2 | Scout vs Seek, same Echo, stop cause | Scout strength > Seek strength for every benefit. Seek below `min_cause_strength` for observe. | `stop_short/directive_cause_scout_stronger_than_seek` | 4 |
| C3 | Standing 1 vs Standing 6, same Calling, Scout | Directive strength falls as J rises; never below `floor_s x base x affinity`; never above `base x affinity`. | `stop_short/directive_cause_falls_with_judgment` | 4 |
| C4 | Same pair, anchor Calling | The winning cause flips from Directive to identity as J rises. | `stop_short/directive_cause_yields_to_identity_at_higher_judgment` | 4 |
| C5 | Same pair, edge Calling (identity affinity 0) | Directive cause still exists at Standing 6 and 9 (floor). Weaker, not zero. | `stop_short/directive_cause_floor_holds_for_edge_calling` | 4 |
| C6 | Standing 1, two Callings, same Directive (D-08) | Different stop owner or strength per Calling. | `stop_short/directive_contrast_by_calling_at_standing_1` | 4 |
| C7 | Calm vs afraid, same Standing, stop cause | The Directive scale is not lower for the afraid Echo. Fear itself is not multiplied by J. | `stop_short/afraid_directive_scale_not_below_calm` and `stop_short/fear_cause_not_scaled_by_judgment` | 4 |
| C8 | (replaced) Old test "acceptance ignores fear" is dropped. It would contradict J2 B. | | (see F1 to F6) | |
| C9 | Seek, seasoned vs young, guard | Young Seek can still pause for the Directive (0.184). Seasoned Seek cannot (0.132 < 0.15). | `stop_short/seek_directive_cause_gone_when_seasoned` | 4 |
| C10 | Best cause is a maximum | Directive and identity strengths never add. | `stop_short/directive_cause_does_not_stack_with_identity` | 4 |
| C11 | Budget, layer C | Stop swing <= `interpretation_swing_max`. | `stop_short/directive_swing_within_declared_budget` | 4 |
| C12 | Config integrity | `weight x max(acceptance) < abs(exposure_weight)`; offset exists in config; acceptance in -1..1. | `directive_cfg/exposure_acceptance_never_attractor` | 1 |
| C13 | Data-only Directive (D-14) | A test-only third Directive with other tolerance produces a Directive cause and an acceptance value with no logic change; a grep test finds no Directive id literal in the new code. | `directive_char/synthetic_directive_reaches_stop_cause` and `directive_char/synthetic_directive_reaches_acceptance` | 1 and 4 |
| C14 | Stage bound stays out (narrowed) | No `interpretation_width`, `leans`, `lean_strength`, `directive_profile` or `bounds` stage key is read in combat code. Only `state_ramps.fear_start` and `fear_full` are shared. | `stop_short/stage_bound_not_read_in_combat` | 2 (superseded by D-91: no ramp key is shared. The test `movement_arbiter/stage_bound_not_read_in_combat` scans combat code for `directive_profile`, `lean_strength` and `leans` only.) |
| C15 | Fingerprints | Each slice moves Scout hashes for one named cause (section 10). | existing `fingerprint_*` suites, re-recorded by an `opus` agent per slice (D-69 Q1, D-70) | each |

### Fear lean (J2 B)

| # | Contrast | Expected difference | Test name (proposed) |
|---|---|---|---|
| F1 | Calm vs afraid, same Echo, same Standing, same Directive | Afraid acceptance is lower, for Scout and for Seek. Same fear value both read. | `movement_arbiter/fear_lean_lowers_acceptance` |
| F2 | Fear below `fear_start` | Lean is exactly 0. Fear 20 gives 0; fear 70 gives the full `fear_bound`. | `movement_arbiter/fear_lean_ramp_matches_stage_ramp` (superseded by D-89 C2: the test is now `movement_arbiter/fear_lean_follows_status_band`; it checks the lean per status band. The test `fear_lean_ramp_matches_stage_ramp` no longer exists.) |
| F3 | Same fear, Judgment 0.2 vs 0.85 (build J through production, hold fear fixed by setting the bonds and Standing, not by fear) | The lean `F` is equal. Only `D_scaled` differs. | `movement_arbiter/fear_lean_not_scaled_by_judgment` |
| F4 | Fear read | Lean uses `max(fear, fear_base)`. A high `fear_base` with low `fear` still leans. | `movement_arbiter/fear_lean_reads_max_of_fear_and_base` |
| F5 | The one readable rule | Acceptance(fear) <= acceptance(calm), for both Directives and J from 0 to 1, with F-a included, except two bounded rises. (a) Just above `fear_start`, before the lean overtakes: peak 0.006 for Seek, bound 0.01. (b) Above `fear_full` (fear 70 to 100): at most `judgment_slope` (0.0003) per fear point, about 0.009 in total for Seek. Acceptance stays below the calm value. The test derives its window from config (D-83 A). | `movement_arbiter/more_fear_never_more_accepting` (superseded by D-89 C2: with Judgment fixed, more fear never raises acceptance; each fear point may lower it by at most the largest table step x the bound. No `fear_start` or `fear_full` window.) |
| F6 | Config integrity | Three rules. Slope: `fear_lean_bound / (fear_full - fear_start) >= (1 - floor) x fear_pressure_weight x max abs(D) / 100`. Pre-start bound: `(1 - floor) x fear_pressure_weight x fear_start / 100 x max abs(D) <= 0.01`. Total bound (kept): `fear_lean_bound >= (1 - floor) x fear_pressure_weight x max abs(D)` (0.03 at shipped values). The slope rule alone fails only below a bound of 0.015, so the total bound is kept to fail below 0.03. | `directive_cfg/fear_lean_bound_exceeds_fear_judgment_path` (superseded by D-89 C2: two rules, see section 4 note; the test name is unchanged.) |
| F7 | Seek stays a cost, not a ban | With default config, a frightened seasoned Seek Echo has acceptance above -0.05 (it hesitates, it does not refuse). This pins the answer to question O1 so a later change is deliberate. | `movement_arbiter/afraid_seek_still_treats_exposure_as_cost_not_ban` |
| F8 | No stage leak | A fixture changes `data.stages.party_stance.bounds.exposure_tolerance`. Combat acceptance does not move. | `movement_arbiter/fear_bound_is_combat_owned` |

### Judgment scale on acceptance (J2 C)

| # | Contrast | Expected difference | Test name (proposed) |
|---|---|---|---|
| J1 | Same Echo, same Directive, Standing 1 vs 6 vs 9 (production Judgment) | `abs(D_scaled)` falls with Standing; never below `floor_a x abs(D)`; never above `abs(D)`. | `movement_arbiter/acceptance_falls_with_judgment` |
| J2 | Sign | The scale never flips the sign of `D`. Scout stays negative, Seek positive. | `movement_arbiter/acceptance_judgment_scale_keeps_sign` |
| J3 | Growth, in a decision | Two-option fixture. Standing 1 Scout Echo avoids the exposed option by a larger margin than the Standing 9 Scout Echo. For Seek, the margin to take it is larger at Standing 1. | `movement_arbiter/seasoned_echo_reads_directive_exposure_less_literally` |
| J4 | Pillar guard | The Scout and Seek acceptance gap at Standing 9 is smaller than at Standing 1 and still above 0. | `movement_arbiter/directive_contrast_narrows_but_never_closes` |
| J5 | Order of operations | The formula in section 2a, step by step, on the four illustrative Echoes. Pins the numbers. | `movement_arbiter/acceptance_order_of_operations` |
| J6 | Missing tolerance | `D = 0`; fear lean still applies. | `movement_arbiter/acceptance_missing_tolerance_is_neutral_plus_fear` |
| J7 | Budget, layer B | `own_side_mul / floor_a <= interpretation_swing_max`. | `movement_arbiter/acceptance_swing_within_declared_budget` |
| J8 | Fixture trap | A fixture with no `judgment` key fails loudly, not silently at 0.3. DONE on the movement path: `_validate_movement_inputs` returns `missing_judgment` (D-83 C). The legacy selector `select_intent` keeps the silent default 0.3. A separate story could add the same check. | `movement_arbiter/acceptance_requires_production_judgment` |
| J9 | Both floors at or above 0.55 | Config integrity for `floor_a` and `floor_s` (valid range 0.55 to 1, D-83 B). | `directive_cfg/judgment_floors_at_least_half` |

Standing 1 failure check: C6 and J1 together must show contrast at Standing 1 without any Judgment effect. At Standing 1 both scales are near 1.0, so the Echo follows the Directive (young Echo follows). Calling still gives contrast through identity and style.

---

## 6. Config keys (names only; mid-game-designer authors values)

| Key (proposed path) | Purpose | Notes |
|---|---|---|
| `data.combat.movement.exposure_acceptance.offset` | Offset in `D = T - offset` | New sibling block of `spatial_utility`. Not in the closed block. |
| `data.combat.movement.exposure_acceptance.judgment_floor` | `floor_a` | Range 0.55 to 0.6. Must be >= 0.55 (D-83 B). (superseded by D-88: key is `data.combat.movement.directive_judgment.judgment_floor`) |
| `data.combat.movement.exposure_acceptance.fear_lean_bound` | `fear_bound` | Combat-owned. Start equals the stage bound 0.12. Must satisfy F6. |
| `data.combat.movement.spatial_utility.directive_exposure_acceptance_weight` | Weight of the acceptance term | EXISTS (2.0). Raised to 17 (D-73, which replaces the D-70 J1 range 8 to 14). Not a new key. |
| `data.stages.party_stance.state_ramps.fear_start` / `fear_full` | Fear ramp | EXIST (20, 70). Read-only shared. Not copied. (removed by D-91: `state_ramps` no longer exists) |
| `data.actor.stop_short.directive.affinity.guard` | Affinity per benefit | Large. |
| `data.actor.stop_short.directive.affinity.hold` | Affinity per benefit | Large. |
| `data.actor.stop_short.directive.affinity.observe` | Affinity per benefit | Small. |
| `data.actor.stop_short.directive.judgment_floor` | `floor_s` | Range 0.55 to 0.6. Must be >= 0.55 (D-83 B). (superseded by D-88: removed; the stop cause reads the shared key) |
| `data.maturity_expression.interpretation_swing_max.value` | Budget | EXISTS (2.0). Unchanged (D-70 J4). (superseded: 2.5, D-82 Q5) |
| `data.maturity_expression.autonomy_outputs.judgment.fear_pressure_weight` | Fear to Judgment | EXISTS (0.25). Read by test F6. Not retuned in phase D. |
| `data.actor.stop_short.min_cause_strength` | Cutoff | EXISTS (0.15). Do not retune in phase D (it moves fear and identity too). |
| `data.actor.stop_short.stop_short_weight` | Bias weight | EXISTS (6.0). Same. |

No new Directive key (ANSWERS #81). The `_comment` fields use the project rule that tunables live in config (ANSWERS #83).

---

## 7. Decided and still open

### Decided (Jeff, D-70, 2026-10-16)

| # | Question | Answer | Where it lands in this note |
|---|---|---|---|
| J1 | Acceptance weight | Raise to 17 (D-73 replaces the range 8 to 14) | 2a, slice 1 |
| J2 | Acceptance matures or reacts to fear | BOTH: fear lean (B) and Judgment scale (C), inside phase D | 2a, 2b, 3, 4, 10 |
| J3 | A frightened Echo follows the Directive more | Accept. One Judgment value. | 4 (fear paths) |
| J4 | Reinterpretation depth against the budget | Floors 0.55 to 0.6 (start 0.6). `interpretation_swing_max` stays 2.0. | 3 (superseded by D-82 Q5: budget 2.5) |
| J5 | Seek rarely has a Directive stop | Accept | 2c |

### Still open (each changes what the player sees or a number)

#### O1. May a very afraid Echo treat exposure as a pure cost under Seek?
With `fear_bound` 0.12 a frightened Seek Echo still has acceptance above 0 (+0.099 in the table). Fear makes it hesitate. It does not make it refuse exposure.
A bound near 0.25 to 0.30 flips a frightened seasoned Seek Echo to a negative acceptance. It then avoids exposure like a Scout.

| Option | Effect |
|---|---|
| A. Bound 0.12 (start) | Fear shows as hesitation. Seek stays the bold stance. Matches GDD 11.5 "modify planned action rather than replace it". |
| B. Bound 0.25 to 0.30 | A shaken Echo ignores a Seek order for exposure. Strong fear signal. Seek loses its identity under fear. |

Advice: A. Probe step 9 measures it. Raise only if the probe shows fear is invisible in movement. Test F7 pins A.

#### O2. What is the "own exposure habit" of a seasoned Echo?
Today it is the existing movement style alignment (Calling, virtues, fear, morale). It is not scaled by J. As `D_scaled` shrinks, style alignment decides more.

| Option | Effect |
|---|---|
| A. Existing style alignment only | No new term. Growth shows as a weaker Directive. One authority. |
| B. A new Calling exposure habit that grows with J (as the stage does: anchor shy, edge bold, scaled by Judgment) | A seasoned Edge Echo becomes bolder and a seasoned Anchor Echo shyer. Strong growth signal. Counts Calling twice (style alignment already reads Calling family). Layer B swing needs a new own-side multiplier (section 3a option 1). |

Advice: A now. Measure in probe step 10 whether Echoes of different Callings diverge at Standing 9. Open B as a new story only if they do not.

Remaining open item from the first version: Q6, the player text for the Directive stop cause (after the code exists).

---

## 8. Risks and what the probe must measure

### Risks

| Risk | Why | Control |
|---|---|---|
| Acceptance has no visible effect | Weight 2.0 is below the decision threshold (combat-003: first decides at 15 to 20). | The weight sweep (step 6). |
| Acceptance becomes an attractor | `weight x 0.3 >= 6.0` at weight 20. | Test C12. |
| Directive cause never changes a route | Bias at most `6.0 x 0.64` = 3.9 competes with `objective_progress_weight` 8.0 and others. LESSONS #38: a feature that fires rarely needs a measured rate. | Probe step 1: a small slice that proves the cause can change a chosen route, before any matrix. |
| Scout stops too often | Part 1 and part 4 push Scout the same way. | Streak veto (shipped) stops consecutive stops. Probe the rate. |
| Hash moves lose attribution | Four causes move Scout hashes. | Section 10: four slices, one re-record each. |
| Judgment range is unknown in play | The J values here are illustrative. Maximum positive weight sum is 0.95; Standing 1 has `rank_strength` 0. | Probe step 3. If J rarely passes 0.5, both Directive scales barely move and growth is invisible. |
| Judgment scale flattens Scout against Seek at Standing 9 | Gap 0.46 to 0.33 in the table. | Test J4 (never closes). Probe step 10. |
| Fear is counted in too many movement paths | F-a to F-e (section 4). | Monotone rule (F5, F6). `fear_bound` is the one dial. Probe step 9. |
| Fear lean makes Seek timid | Bound too large (O1). | Test F7. |
| Shared fear ramp couples stage and combat | One config read crosses D-09. | Only `fear_start` and `fear_full` are shared. Test C14 (narrowed) and F8. (superseded by D-91: no ramp is shared) |
| Fixture hides the term | Default `judgment` 0.3 in ctx; empty bonds. | Section 5 fixture rule and test J8. |
| Seek stop cause is dead weight | Most Seek values fall below 0.15. | Accepted (J5). Re-check after the probe. |
| Stage bound leaks into combat | Same word "interpretation width". | Test C14; D-09. |
| A plan-level `_directive_bonus` does favour the stop option | Assumption A1 false. | `mechanics-developer` verifies before build. If false, section 4 row 1 against row 5 becomes a real double count and the floor needs a joint budget. |
| Layers B and C break the budget cross pair | 1.35 / 0.6 = 2.25 as a bound. | Section 3b: not a real pairing. Per-layer tests. Named for Jeff. |

### The probe must measure

The main chat runs it (RUN REQUEST rules in `AGENTS.md`). Subagents do not.
Use shipped boards, production construction, Echo-only, fixed seeds, a clean save directory.

| # | Measure | Why | Needed before slice |
|---|---|---|---|
| 1 | Lever check: on a small slice, how many chosen routes change if the Directive stop cause is removed (counterfactual re-score) | LESSONS #38. Stop before any matrix if the count is 0. | 4 |
| 2 | 2 x 2: acceptance on/off x Directive stop cause on/off, under Scout and Seek. Count stop-short events per fight and changed route choices | Separates the acceptance parts from the stop cause. Measures the joint size of row 9. | 4 |
| 3 | Real Judgment per Standing (1 to 9) for the shipped starter Echoes, with and without fear and bonds | Replaces the illustrative J values. Sets `floor_a`, `floor_s` choices inside 0.55 to 0.6. | 3 |
| 4 | Directive-cause share of all stops, by Standing and Calling family, under Scout | Proves the pillar: share falls, identity share rises, with Standing. | 4 |
| 5 | Stops per Echo per fight, Scout and Seek | Detect spam (Scout) and dead feature (Seek). | 4 |
| 6 | Acceptance weight sweep (0, 2, 8, 11, 14, 17, 19) with the base map only | Picked the weight 17 (D-73; the first list was 2, 8, 11, 14). Count changed route choices, as combat-003 did. | 1 |
| 7 | Whether an edge Echo's stop rate under Scout changes between Standing 1, 6, 9 | Checks that edge growth is visible (D-70 J4). | 4 |
| 8 | Hash moves per slice, each with one named cause | D-69 Q1 attribution. | each |
| 9 | Fear counterfactual: acceptance with fear lean on and off, for Echoes at fear 0, 20, 45, 70. Also with F-d (style fear) on and off. | Sizes F-b against F-a and F-d. Decides O1. | 2 |
| 10 | Judgment counterfactual: acceptance with the Judgment scale on and off, Standing 1, 6, 9, per Calling family. Count changed route choices. | Shows growth in movement. Decides O2 and J4. | 3 |

---

## 9. Deferrals — what phase D does not cover

| Item | Owner |
|---|---|
| Player-facing text for the Directive stop cause (D-69 Q6) | Jeff, after the code exists. Copy rule: a fear or Judgment reason never reads as a fault of the Echo (D-40 item 4). |
| Player-facing text for fear lean or Judgment scale | None needed. They change movement only. Jeff decides if any text is wanted. |
| A new Calling exposure habit that grows with J (O2 option B) | New story, only if probe step 10 shows no divergence. |
| Scaling the shipped stop-cause fear or the action layer by anything new | Not in phase D. |
| Divergence detection for a skipped Directive stop (ANSWERS #46) | Not in phase D. Name it as a follow-up if the probe shows seasoned Echoes walking on. |
| `reposition`, `regroup`, ping and guidance code | V2-COMBAT-004 (D-07, D-09). |
| Stage `interpretation_width` in combat | Never (D-09). |
| Hazard data in the exposure map | "Stage hazards and exposure" story (D-02, D-31). |
| Press the Path, Hold the Circle | V2-DIRECTIVE-003 (D-06). |
| Moving the shared fear ramp to a neutral config location | Optional clean-up. Not needed while the helper reads the stage keys read-only. |

---

## 10. Slice order for attribution

Rule (D-70): four causes, in this order. Each lands alone, then one re-record of the recorded values. So each moved value has one named cause.
The fingerprint tests run Scout only. They are the recorded values that can move. Seek-only fixtures move less.
No two slices land together. Re-records run one after another (no parallel re-record).

| Slice | Cause | Code changes | Contrast tests that land with it | Can Scout fingerprint hashes move? |
|---|---|---|---|---|
| 1 | Base acceptance map (`T - offset`) and the new weight | `exposure_acceptance.offset`, weight value, acceptance from `T` in `_spatial_utility` | C1, C12, C13 (acceptance half) | YES. Scout acceptance goes from the intent weight (shipped) to -0.2 (Judgment is not in yet; -0.184 is the later illustrative value). Any Scout fixture that chooses between routes with different exposure can change. If the hashes include the score trace, every route candidate moves. The probe (step 6) says which. |
| 2 | Fear lean | `fear_lean_bound`, shared ramp helper, fear argument | F1 to F8, C14 | ONLY IF a fingerprint fixture holds an Echo at or above `fear_start` (20), or with `fear_base` at or above 20. If every fixture is calm, the hashes do not move. A "no move" is a valid and recorded result for this slice. |
| 3 | Judgment scale on acceptance | `judgment_floor` (acceptance), `judgment` argument in `_spatial_utility` | J1 to J9 | YES, in nearly every Scout fixture with a route choice. Fixture Judgment is above 0 whenever Standing or bonds are above the floor. A `judgment` of 0.3 default in a fixture also scales. |
| 4 | Directive stop cause, with its Judgment scale | `CAUSE_ROWS` row, ctx tolerance field, stop affinities, `floor_s` | C2 to C11, C13 (stop half) | YES, where a Scout fixture holds a stop-short decision with a candidate guard, hold or observe cause at or above 0.15. Fixtures with stop-short disabled do not move. |

### Per slice: owner, model, runs

| Slice | Builder (role, model) | Value author | Attribution of the hash move | RUN REQUEST needed |
|---|---|---|---|---|
| 1 | `mechanics-developer`, `sonnet` | `mid-game-designer`, `sonnet` (offset, weight start) | `opus` agent (D-69 Q1) | Yes: (a) probe step 6 weight sweep, before the weight is final; (b) the fingerprint re-record; (c) the sharded or full suite after the slice. |
| 2 | `mechanics-developer`, `sonnet` | `mid-game-designer`, `sonnet` (`fear_lean_bound`) | `opus` agent. Likely a short job if the result is "no move". | Yes: probe step 9; the fingerprint re-record (even if expected unchanged, run it to prove "no move"). |
| 3 | `mechanics-developer`, `sonnet` | `mid-game-designer`, `sonnet` (`judgment_floor`) | `opus` agent | Yes: probe steps 3 and 10; the fingerprint re-record. |
| 4 | `mechanics-developer`, `sonnet`. `opus` only if the work touches `EchoFactory` draw order or save schema (it should not). | `mid-game-designer`, `sonnet` (affinities, `floor_s`) | `opus` agent | Yes: probe steps 1, 2, 4, 5, 7 (step 1 first; stop before the matrix if the count is 0); the fingerprint re-record. |
| End | `qa-verifier`, `opus` (combined tree: four slices meet, either could mask the other) | | | Full suite: main chat or `qa-verifier` only (not the builders). |

Rules for every slice:

1. The builder runs only the compile check and filtered suites (`-- tests <filter>`). Anything that can pass 2 minutes goes to the main chat as a RUN REQUEST with the five items from root `AGENTS.md`.
2. Before the re-record, the main chat saves a copy of every file the run edits and checks it is back to the original afterwards (`cmp`).
3. The `opus` agent attributes each moved value to the one named cause of the slice. If a moved value has no cause in the slice, the slice stops. No fix inside the re-record.
4. The next slice starts only after the previous re-record is committed or saved in a clean state.
5. The slice 1 weight is final only after probe step 6. If the sweep runs on a build with the map only, the weight is part of cause 1 (D-70 lists "map and weight" as one cause).
6. A contrast test of a later slice is not written into an earlier slice (so a test failure also has one cause).

---

## OPEN — questions and assumptions

ASSUMED: A1. A stop-short route option scores with its plan's `_directive_bonus`, which is equal for all options of that plan, so `_directive_bonus` cannot favour a stop. | WHY: `BehaviorArbiter.gd:787-801` calls `_score(str(plan["type"]) …)` once per candidate; route options differ only by `_spatial_utility`, style alignment and the stop bias. I read the call, not a run. | WRONG IF: the route candidate's score carries a benefit-action Directive bonus (guard or observe). Then rows 1 and 5 of section 4 double count and the floor needs a joint budget.

ASSUMED: A2. The swing budget convention (own-side multiplier at J = 1 over Directive multiplier at J = 1, affinities ignored) is right for layers B and C. | WHY: It copies `compute_interpretation_swing` (`BehaviorArbiter.gd:1935-1950`), so one budget key covers all layers. | WRONG IF: Jeff wants the budget to include affinities or the J = 0 baseline. Then the numbers in section 3 change (section 3b gives 2.34 and 3.33 for the J = 0 baseline).

ASSUMED: A3. The acceptance keys sit in a new sibling block `data.combat.movement.exposure_acceptance`, outside the closed `spatial_utility` block. | WHY: Avoids a schema change and three fixture edits. | WRONG IF: `mechanics-developer` finds `_validate_spatial_config` or the movement config loader rejects unknown siblings of `spatial_utility`.

ASSUMED: A4. The Judgment values per Standing (0.2, 0.5, 0.85) and the fear 70 example are illustrative. | WHY: Real values depend on archetype, accent, bonds, vows and fear. | WRONG IF: Probe step 3 shows another range. Then the tables in sections 1c, 2a and 2c need a redo.

ASSUMED: A5. Affinity ranges, floors 0.6 and `fear_bound` 0.12 are starting points only. | WHY: D-69 Q3 and D-70 J4 fix the shape and the floor range, not the final numbers. | WRONG IF: `mid-game-designer` authors values that break the budget tests or the F6 rule.

ASSUMED: A6. A missing `exposure_tolerance` gives `D = 0` and no Directive stop cause. Fear lean still applies. | WHY: A future Directive may be stage-only (D-19). Neutral is the safe default. | WRONG IF: Jeff wants D-15 to make `exposure_tolerance` a required field.

ASSUMED: A7. Style alignment (the Echo's own exposure habit in combat) is not scaled by Judgment, so layer B's own-side multiplier is 1.0. | WHY: `style_inputs` in `BehaviorArbiter.gd:765-779` carries no Judgment key. I did not trace `_style_alignment` end to end. | WRONG IF: `_style_alignment` or `_style_urgency_factor` scales with J. Then layer B swing is that multiplier over `floor_a`, and may need higher floors.

ASSUMED: A8. Fear lean reads `max(fear, fear_base)`, not current fear alone as the stage does. | WHY: The arbiter's style inputs and `derive_expression` both use that max. One fear reading in the arbiter keeps F-a and F-b aligned (the monotone rule F5 relies on it). | WRONG IF: Jeff wants fear lean to ignore structural dread. Then F-a and F-b read different values and rule F5 needs a new proof.

ASSUMED: A9. Combat may read `state_ramps.fear_start` and `fear_full` from the stage block through one shared helper, and D-09 stays intact. | WHY: D-09 blocks the Judgment bound (`interpretation_width`). A fear ramp is a state input, not a Judgment bound. The brief asked for the same config source. | WRONG IF: Jeff reads D-09 as "no stage config key at all in combat". Then copy the two values into combat keys and add a drift test (cost: a second place to tune). [Superseded by D-91: `state_ramps` is removed.]

ASSUMED: A10. The two Judgment floors (`floor_a` for acceptance and `floor_s` for stops) are separate keys that start equal at 0.6. | WHY: Each layer has its own swing test and its own decision. | WRONG IF: Jeff wants one dial. Then merge to one key and keep both tests.

BLOCKED: O1 (may fear make a Seek Echo avoid exposure), O2 (what a seasoned Echo's own exposure habit is) | CHECKED: D-69, D-70, `design.md` lines 31, 100, 320, 349, `StagePartyStance.gd`, `BehaviorArbiter.gd` 690-830, 1373-1475, 1935-1950, `MaturityExpressionService.gd` 180-215, `data/balance.json` state_ramps, bounds, leans, spatial_utility, interpretation_swing_max, GDD 11.5, 17.1, 22.4 | NEED: Jeff's choice per question in section 7. Phase D can start slice 1 now. Slice 2 needs O1 only for the bound value. Slice 3 needs O2 only if option B is chosen (it adds a new story).

BLOCKED: Q6, player-facing words for the Directive stop cause | CHECKED: D-69, D-40 item 4 | NEED: Jeff's wording after the code exists.
