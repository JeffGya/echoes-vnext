# V2-DIRECTIVE-002 phase D — design note: combat expression and stop-short Directive cause

Status: DESIGN ONLY. No code, data or test changed. Author: sr-game-designer, 2026-10-16.
Inputs: D-05, D-08, D-09, D-10, D-14, D-69 (`decisions.md`), `design.md` lines 100, 320, 349, ANSWERS #81 to #83, Working GDD section 11.5.
Every number here is `PROPOSED DEFAULT`. `mid-game-designer` authors the final values.
Player-facing text is Jeff's wording (D-69 Q6). This note proposes none.
Internal names in this note (`cause_id`, config keys) never reach the player.

---

## 0. What phase D builds (one paragraph)

Phase D has two parts.
Part 1: combat exposure acceptance comes from the Directive's `exposure_tolerance` (D-69 Q1).
Part 2: the Directive becomes a third stop-short cause beside fear and identity (D-69 Q3, Q4, Q5).
Judgment lowers the Directive stop cause. Higher Standing follows the Directive less.

---

## 1. Pillar check — does each decision show an Echo growing?

Pillar (Jeff, 2026-10-16): the core of the game is to watch Echoes grow over time and watch their behaviour change with it.

### 1a. What Standing means in the Working GDD

| GDD source | Quote | Meaning for phase D |
|---|---|---|
| 11.5 "Storyweight, Step, Standing" | "`Standing` = the major maturity threshold" | Standing is maturity, not power. |
| 11.5 "Hidden maturity-expression layer" | "low-Standing Echoes should feel more externally authored" | A young Echo follows the Directive closely. |
| same | "high-Standing Echoes should feel more internally authored" | A seasoned Echo acts from its own nature. |
| same | "higher Standing should not mean more obedient, more tactically optimal, or more generally compliant" | The Directive cause must fall with Judgment. It must never rise. |
| same | "it should mean more self-command, more interpretation, more opinion, and more consequence when identity is crossed" | Own causes (identity, fear) stay or rise. Only the Directive cause falls. |
| same | "higher-Standing Echoes should be less casually swayable by noise, but more sharply affected by true contradiction" | Fear is not scaled by Judgment. A true fear still stops a seasoned Echo. |
| 11.5 "Behavior / refusal / autonomy" | "most autonomy friction should modify planned action rather than replace it" | The Directive cause gets weaker. It does not switch off or turn into a refusal. |
| 11.5 same, Realm direction | "most contradiction should first appear as reinterpretation, hesitation, substitution, or altered emphasis" | A seasoned Echo stops short for its own reason, or walks on. Both are "altered emphasis". |
| 11.5 same, in-combat guidance | "higher Standing means more coherent judgment and self-assertion, never increased obedience" | Same rule. |
| 10.6 | "Story recovery must alter: Echo growth …" | Growth must be visible in play, not only in a number. |
| 22.4 | "Echoes are not obedient units" | A first-session test of the pillar. |

Note on Jeff's choice (D-69 Q4 option B): "higher Standing obeys less" fits the GDD quotes above.
It does not mean "more disobedient". The Echo's own causes take over (section 1c).

### 1b. Pillar table — each decision

| Decision | How it shows growth | Gap |
|---|---|---|
| Q1 acceptance = tolerance minus offset | None over time. The Directive sets acceptance. Standing does not change it. Stands as a Directive contrast (Scout vs Seek). | PILLAR GAP: movement exposure does not mature. See question J2. |
| Q2 old `exposure_acceptance` stays for action choice | `_directive_bonus` already scales by Judgment. Growth already shows there. | None new. |
| Q3 stop cause = (1 - tolerance) x affinity | Contrast between Directives. Contrast between benefits (guard strong, observe weak). | None. |
| Q4 Judgment scales the Directive stop cause down | The main growth carrier in phase D. Young Echo stops because the Keeper asked. Seasoned Echo stops because of who it is, or walks on. | Bounded by the swing budget (section 3). |
| Q5 route formula unchanged | No new growth effect. Keeps the change small and measurable. | None. |

### 1c. The curve — young follows, seasoned reinterprets

The Directive cause and the identity cause move in opposite ways with Judgment (J, 0 to 1).

| Cause | Judgment scale | At J = 0 | At J = 1 | Direction |
|---|---|---|---|---|
| Identity (shipped) | `judgment_base + (1 - judgment_base) x J`, base 0.5 (`StopShortService.gd:192-193`) | 0.5 | 1.0 | rises |
| Directive (new) | `floor + (1 - floor) x (1 - J)` | 1.0 | `floor` | falls |
| Fear (shipped) | none | 1.0 | 1.0 | flat. Fear already lowers J through `fear_pressure_weight` (0.25). |

`best_cause` takes the strongest cause per benefit. It does not add them (`StopShortService.gd`, `best_cause`).
So the two curves cross. The Echo's stop changes owner as it grows.

Worked example (PROPOSED DEFAULT: Directive floor 0.6, guard affinity 1.0, anchor family guard affinity 0.8).
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
| 1 | Under Scout Carefully, all Echoes pause and guard or watch before danger. Echoes look alike, except that Calling and fear give some contrast (D-08). Under Seek Signs, almost none pause for the Directive. |
| 6 | The same Scout party pauses less evenly. Anchor-minded Echoes still pause, now because of who they are. Edge-minded Echoes pause less and push on. The same Directive gives different behaviour per person. |
| 9 | The Directive is a hint, not a leash. A seasoned Echo pauses when its own nature or real fear says so. It may walk on under Scout. The Directive cause is weak, never zero for Scout (floor). |

The player learns "this Echo has become someone" by comparing one Echo across fights. This is the growth signal. It needs no number on screen.

---

## 2. Formulas

### 2a. Combat acceptance map (Q1)

```
acceptance = clamp(exposure_tolerance - offset, -1, 1)
```

| Item | Rule |
|---|---|
| Input | `exposure_tolerance` of the active Directive (read through the one accessor from phase A). Shipped: Scout 0.3, Seek 0.8. |
| Offset | Config key, start 0.5 (PROPOSED DEFAULT). Result: Scout -0.2, Seek +0.3. |
| Where the offset lives | `data.combat.movement`, as a SIBLING of `spatial_utility`, not inside it. The block `spatial_utility` is a closed schema (`_SPATIAL_UTILITY_FIELDS` and two validators; fixtures in `MovementArbitrationTests.gd:1099`, `BehaviorArbiterTests.gd:1401`, `MovementStyleServiceTests.gd:520`). A sibling key needs no schema change and no fixture change. |
| Where it is used | `_spatial_utility`, term `directive_exposure_acceptance`. It replaces `weights.get("exposure_acceptance")` in this term only. |
| Not changed | `_directive_bonus` still reads `intent_weights.exposure_acceptance` for action choice (melee 0.4, guard -0.3, idle -0.2 rows). This is D-69 Q2. D-05 is amended: two exposure inputs remain. |
| Missing tolerance | Acceptance 0 (neutral). No Directive id literal anywhere (ANSWERS #81). |
| Judgment | Not in this term (Q1 as approved). See question J2. |

Effect size. The term is `directive_exposure_acceptance_weight x acceptance x exposure`.
It competes with `exposure_weight` (-6.0) x exposure. The slope on exposure is `-6.0 + weight x acceptance`.

| Weight | Scout slope | Seek slope | Reading |
|---|---|---|---|
| 2.0 (shipped) | -6.4 | -5.4 | Almost no contrast. combat-003 measured that this term first decides turns at weight 15 to 20 (`v2-combat-003/handoff.md:1690-1730`, with acceptance 0.2). |
| 8 | -7.6 | -3.6 | Visible contrast likely. |
| 11 | -8.2 | -2.7 | |
| 14 | -8.8 | -1.8 | |
| 20 | -10.0 | 0.0 | Seek treats exposure as free. Too far. |

Rule to protect: `weight x max(acceptance) < |exposure_weight|`. Above it, exposure becomes an attractor for Seek (combat-003 section 22.4: "a sign switch on exposure").
Phase D adds a config-integrity test for this rule (section 6).

### 2b. Directive stop cause (Q3, Q4)

```
base      = 1 - exposure_tolerance                 (Scout 0.7, Seek 0.2)
affinity  = directive.affinity[benefit]            (guard, hold large; observe small)
scale(J)  = floor + (1 - floor) x (1 - J)          (J = ctx.judgment, clamped 0..1)
strength  = clamp(base x affinity x scale(J), 0, 1)
```

The cause then goes through the normal rules: `strength >= min_cause_strength` (0.15) or it does not exist.
Bias = `stop_short_weight` (6.0) x strength. The route scoring formula does not change (Q5).

| Rule | Detail |
|---|---|
| One-way | `scale(J)` is 1.0 at J = 0 and falls to `floor` at J = 1. It never exceeds 1.0. Judgment only lowers the Directive cause. |
| Floor | PROPOSED DEFAULT range 0.55 to 0.65. Start 0.6. Reason: the swing budget (section 3) needs `floor >= 0.5`. |
| Cause id | A new registry row in `CAUSE_ROWS` (D-10). Internal id "directive". The `cause_strength` arm is a `match` on a cause id of the CAUSE, not on a Directive id. No Directive id literal in `core/` (ANSWERS #81). |
| Context | One new ctx field: the active Directive's `exposure_tolerance`. `judgment` already exists in ctx (`StopShortContextService.gd:344`; default 0.3 if the context lacks it, a fixture trap). |
| Source / code | `cause_source` and `cause_code` get new internal values. They feed the trace only. Text is Jeff's (Q6). |
| Missing tolerance | No Directive cause (strength 0). |
| New Directive key | None (ANSWERS #81, D-69 Q3). Affinity lives in `data.actor.stop_short`, not in the Directive entry. |
| Disabled stops | `stop_short.enabled = false` switches the cause off with the rest. |

Scale form options considered:

| Form | Formula | Verdict |
|---|---|---|
| F1 linear mirror of identity | `floor + (1 - floor) x (1 - J)` | CHOSEN. Own key. Reads as the exact mirror of the identity scale, so a designer sees the crossover. |
| F2 reuse the action-layer curve | `lerp(high, low, J) / high` from `directive_interpretation_mul` (floor 0.577) | Rejected. It couples two layers silently. A retune of the action layer would move stops. The budget test would catch size, not intent. |
| F3 step by Standing band | band table | Rejected. `band_by_standing` saturates at Standing 6 to 9. D-08 and the PROG-012 phase 6 fix removed band tables for this reason. |

Illustrative strengths (floor 0.6; guard 1.0, hold 0.8, observe 0.3 affinity; all PROPOSED DEFAULT):

| Directive | Benefit | J 0.2 | J 0.5 | J 0.85 |
|---|---|---|---|---|
| Scout | guard | 0.644 | 0.560 | 0.462 |
| Scout | hold | 0.515 | 0.448 | 0.370 |
| Scout | observe | 0.193 | 0.168 | 0.139 (below 0.15: gone) |
| Seek | guard | 0.184 | 0.160 | 0.132 (gone) |
| Seek | hold | 0.147 (gone) | 0.128 (gone) | 0.106 (gone) |
| Seek | observe | 0.055 (gone) | gone | gone |

Reading: Seek rarely stops for the Directive, and not at all for a seasoned Echo. Scout stops for the Directive at every Standing. Observe is a weak Directive reason. This is the intended contrast.

---

## 3. Swing budget

The shipped test `arbiter/interpretation_swing_within_declared_budget` checks one ratio:
`compute_interpretation_swing = (1 + max(identity_weight_scale.trait, .vector)) / directive_interpretation_mul.low`
(`BehaviorArbiter.gd:1935-1950`).

| Item | Value (from `data/balance.json`) |
|---|---|
| `identity_weight_scale` trait / vector | 0.35 / 0.35 (line 1222) |
| `directive_interpretation_mul.low` | 0.75 (line 1324 block) |
| Shipped swing | (1 + 0.35) / 0.75 = **1.80** |
| `interpretation_swing_max` | **2.0** (line 1227) |
| Headroom | 0.20 |

Facts about what the budget covers today:

1. It covers the ACTION layer only: identity bonus against `_directive_bonus`, at J = 1.
2. It does not cover the stop layer. Today there is no Directive term in the stop layer, so nothing was missing.
3. It does not cover `_spatial_utility`. That function takes no Judgment argument (recon fact).

The new term is the stop layer's Directive scale. Use the same convention (ratio of multipliers at J = 1, affinities ignored):

```
stop_swing = identity_scale(J = 1) / directive_scale(J = 1) = 1.0 / floor
```

| Floor | stop_swing | Inside 2.0? | Note |
|---|---|---|---|
| 0.50 | 2.00 | Yes, zero headroom | A one-step retune fails the test. |
| 0.55 | 1.82 | Yes | Almost equal to the action layer (1.80). Both layers read as one dial. |
| 0.60 | 1.67 | Yes | Start value. |
| 0.65 | 1.54 | Yes | Weak reinterpretation. |
| 0.40 | 2.50 | NO | Needs `interpretation_swing_max` of 2.5 or more. |

**Result: the new term fits inside the current budget when `floor >= 0.5`. The budget value does not change.**
The test must change as follows (design, for `mechanics-developer`):

| Change | Detail |
|---|---|
| Keep | `arbiter/interpretation_swing_within_declared_budget` unchanged. |
| Add | A static function beside `compute_interpretation_swing`: stop-layer swing from the `data.actor.stop_short` identity base and the new Directive floor. |
| Add | A test `stop_short/directive_swing_within_declared_budget`. It reads the SAME `interpretation_swing_max.value`. It fails if the stop swing exceeds it. |
| Why one budget key | Q4 says the scaling "must sit inside `interpretation_swing_max`". A second key would let two budgets drift. |
| Where the new floor lives | Beside the other stop cause config (`data.actor.stop_short.directive`), not in `maturity_expression`. The test reads both blocks. |

Why the two layers do not multiply (no double count):

| Question | Answer |
|---|---|
| Does a stop-short route also receive `_directive_bonus`? | Yes, but only for its PLAN type. `_score(str(plan["type"]) …)` runs once per candidate, and the bonus is the same for every route option of one plan (`BehaviorArbiter.gd:787-801`). It cannot choose between stopping short and walking on. The stop cause is the only Directive term that discriminates between those options. MUST VERIFY by `mechanics-developer` (assumption A1). |
| Can the Directive cause and the identity cause add? | No. `best_cause` takes the maximum per benefit. |
| Can the fear cause and the Directive cause add? | No. Same maximum. |
| Is fear scaled twice? | No. Fear is not scaled by Judgment in the stop layer. Fear already lowers Judgment (0.25 weight). Design rule from `design.md:31`: do not scale fear by Judgment again. |
| Worst case for one Echo | A seasoned Echo at J = 1 has the Directive's action pull at 0.577 of a young Echo's (action layer) and its stop cause at `floor` (0.6). These act on different decisions (which plan; which route option). Each layer has its own ratio, each at most 2.0. |

Limit to understand: the budget caps reinterpretation depth. At floor 0.5 a seasoned Echo has at best half the Directive stop pull of a young one. A bigger change needs a bigger `interpretation_swing_max`. That is question J1.

---

## 4. Double-count table — where the Directive and Judgment meet in combat after phase D

| # | Place | Directive input | Judgment input | Direction with J | Budgeted by | Double count? |
|---|---|---|---|---|---|---|
| 1 | `_directive_bonus` (`BehaviorArbiter.gd:1835-1860`) | `intent_weights` x `directive_action_muls` | `interpretation_width` = J, lerp 1.30 to 0.75 | falls | `interpretation_swing_max` (action layer 1.80) | Shipped. Unchanged. |
| 2 | Identity bonus in `_score` (trait, vector) | none | `1 + J x 0.35` | rises | same budget (the numerator) | Shipped. Unchanged. |
| 3 | `_spatial_utility` acceptance (phase D, new source) | `exposure_tolerance - offset` | NONE | flat | not covered (no J) | No. Judgment is absent. Gap: J2. |
| 4 | Stop cause "directive" (phase D, new) | `(1 - tolerance) x affinity` | `floor + (1 - floor)(1 - J)` | falls | `interpretation_swing_max` (stop layer, new test) | No. Different decision from row 1 (route option, not plan). |
| 5 | Stop cause "identity" (shipped) | none | `0.5 + 0.5 J` | rises | same budget (numerator) | Shipped. Unchanged. |
| 6 | Stop cause "fear" (shipped) | none | none (fear lowers J elsewhere) | flat | none needed | No. Fear is not scaled. |
| 7 | Causes 4, 5, 6 together | | | | | No. `best_cause` takes the maximum. |
| 8 | Acceptance (row 3) and Directive stop cause (row 4) on one Scout route | Both read tolerance | only row 4 | | | INTENDED STACK. Both push Scout away from exposure by different means: row 3 scores the final cell's exposure; row 4 favours a guard, hold or observe stop. Measure the joint size in the probe (section 8, test 2 x 2). |
| 9 | Fear lowers J, so J-scaled terms move | | `fear_pressure_weight` 0.25 | | | A frightened Echo follows the Directive MORE (lower J). Accepted as design: low Judgment is "more externally authored". Question J3. |
| 10 | Stage bound `interpretation_width` (`party_stance`) | | | | | NEVER enters combat (D-09, `design.md:320`). A grep or structure test blocks the stage key in `core/actors/behaviors/`. |

---

## 5. Contrast table — test targets

Test names are PROPOSED. `mechanics-developer` may rename. Suite prefixes follow the registered suites in `AGENTS.md`.
Fixtures must build Judgment through the production path (`MaturityExpressionService.derive_expression`) with real Standing and real bonds. A fixture with empty bonds or a default `judgment` of 0.3 hides the term (LESSONS: probe must mirror production construction; D-26).

| # | Contrast | Expected difference | Test name (proposed) |
|---|---|---|---|
| C1 | Scout vs Seek, same Echo, Standing 1, route into exposure | Acceptance -0.2 vs +0.3. The Seek route score is higher on an exposed option by `(0.5 x weight x exposure)`. Seek takes the exposed option where Scout takes the lower one (two-option fixture). | `movement_arbiter/acceptance_scout_vs_seek_exposed_option` |
| C2 | Scout vs Seek, same Echo, stop cause | Scout strength > Seek strength for every benefit. Seek below `min_cause_strength` for observe. | `stop_short/directive_cause_scout_stronger_than_seek` |
| C3 | Standing 1 vs Standing 6, same Calling, Scout | Directive strength falls as J rises; never below `floor x base x affinity`; never above `base x affinity`. | `stop_short/directive_cause_falls_with_judgment` |
| C4 | Same pair, anchor Calling | The winning cause flips from Directive to identity as J rises. | `stop_short/directive_cause_yields_to_identity_at_higher_judgment` |
| C5 | Same pair, edge Calling (identity affinity 0) | Directive cause still exists at Standing 6 and 9 (floor). It is weaker, not zero. | `stop_short/directive_cause_floor_holds_for_edge_calling` |
| C6 | Standing 1, two Callings, same Directive (D-08) | Different stop owner or strength per Calling. | `stop_short/directive_contrast_by_calling_at_standing_1` |
| C7 | Calm vs afraid, same Standing, Scout | Afraid: fear cause wins for guard once fear passes the floor (shipped). The Directive scale is not lower for the afraid Echo (lower J gives higher scale). Fear itself is not multiplied by J. | `stop_short/afraid_directive_scale_not_below_calm` and `stop_short/fear_cause_not_scaled_by_judgment` |
| C8 | Calm vs afraid, acceptance | Equal. Acceptance ignores fear. This test pins the J2 gap so a later change is deliberate. | `movement_arbiter/acceptance_ignores_fear` |
| C9 | Seek, seasoned vs young, guard | Young Seek can still pause for the Directive (0.184). Seasoned Seek cannot (0.132 < 0.15). | `stop_short/seek_directive_cause_gone_when_seasoned` |
| C10 | Best cause is a maximum | Directive and identity strengths never add. | `stop_short/directive_cause_does_not_stack_with_identity` |
| C11 | Budget | Stop swing <= `interpretation_swing_max`. | `stop_short/directive_swing_within_declared_budget` |
| C12 | Config integrity | `weight x max(acceptance) < abs(exposure_weight)`; offset exists in config; acceptance in -1..1. | `directive_cfg/exposure_acceptance_never_attractor` |
| C13 | Data-only Directive (D-14) | A test-only third Directive with other tolerance produces a Directive cause with no logic change; grep test finds no Directive id literal in the new code. | `directive_char/synthetic_directive_reaches_stop_cause` |
| C14 | Stage bound stays out | No `party_stance` or stage width key read in combat code. | `stop_short/stage_bound_not_read_in_combat` |
| C15 | Fingerprints | Scout hashes move twice (acceptance, then stop cause). Seek-only fixtures move less. Each move has one named cause. | existing `fingerprint_*` suites, re-recorded by an `opus` agent (D-69 Q1) |

Standing 1 failure check: C6 and C3 together must show contrast at Standing 1 without any Judgment effect. At Standing 1 the Directive scale is near 1.0, so the Echo follows the Directive (young Echo follows). Calling still gives contrast through identity.

---

## 6. Config keys (names only; mid-game-designer authors values)

| Key (proposed path) | Purpose | Notes |
|---|---|---|
| `data.combat.movement.exposure_acceptance_offset` | Offset in `acceptance = tolerance - offset` | Sibling of `spatial_utility`. Not in the closed block. |
| `data.combat.movement.spatial_utility.directive_exposure_acceptance_weight` | Weight of the acceptance term | EXISTS (2.0). Candidate retune (J1). Not a new key. |
| `data.actor.stop_short.directive.affinity.guard` | Affinity per benefit | Large. |
| `data.actor.stop_short.directive.affinity.hold` | Affinity per benefit | Large. |
| `data.actor.stop_short.directive.affinity.observe` | Affinity per benefit | Small. |
| `data.actor.stop_short.directive.judgment_floor` | Floor of the Judgment scale | Range 0.55 to 0.65. Must satisfy the budget (>= 0.5 at max 2.0). |
| `data.maturity_expression.interpretation_swing_max.value` | Budget | EXISTS (2.0). Unchanged unless J1 option C. |
| `data.actor.stop_short.min_cause_strength` | Cutoff | EXISTS (0.15). Do not retune in phase D (it moves fear and identity too). |
| `data.actor.stop_short.stop_short_weight` | Bias weight | EXISTS (6.0). Same. |

No new Directive key (ANSWERS #81). The `_comment` fields use the project rule that tunables live in config (ANSWERS #83).

---

## 7. Design questions only Jeff can answer

Each question changes what the player sees or a number. I do not decide these.

### J1. How strongly should the acceptance term show in play?
At the shipped weight 2.0 the acceptance term is nearly invisible (section 2a). The Scout versus Seek contrast would exist in tests but not in play.

| Option | Effect |
|---|---|
| A. Keep weight 2.0 | No new movement difference in play. Fewest moved hashes. Q1 gives little visible result. |
| B. Raise to a measured value (probe range 8 to 14) | Scout visibly keeps to cover; Seek visibly accepts exposed cells. More moved hashes. Stay below the attractor limit. |
| C. Raise to 15 or more | Seek nears indifference to exposure. Rejected. |

Advice: B, after the probe sweep shows a decision change without an attractor. This follows the pillar: a Directive that changes nothing cannot be felt.

### J2. Should acceptance mature or react to fear? (pillar gap)
Today acceptance is the same for a young and a seasoned Echo, and the same for a calm and a frightened Echo.

| Option | Effect |
|---|---|
| A. Keep as approved (static per Directive) | Simple. No growth signal in movement exposure. Growth shows only in stops and in action choice. |
| B. Fear lowers acceptance (state lean, not Judgment-scaled) | Matches stage rule: "Exposure tolerance down (primary)" for fear (`design.md:31`). A frightened Echo shies from exposure. Needs fear passed into `_spatial_utility`. Adds a number path. |
| C. Judgment scales the Directive part of acceptance | Seasoned Echo uses its own exposure habit. Needs a Judgment argument in `_spatial_utility` and a new budget row. Largest change. |

Advice: A now (Q1 is approved). Open B as a separate small story after the probe. Do not mix B or C into phase D: a second moved value would break attribution of the Scout hash moves. C needs its own design.

### J3. A frightened Echo follows the Directive more
Fear lowers Judgment. Lower Judgment raises the Directive stop scale. So a shaken seasoned Echo leans back on orders (and its fear cause also applies, as a maximum, not a sum).

| Option | Effect |
|---|---|
| A. Accept | "Under strain, even a seasoned Echo holds to the plan." Fits the GDD: Judgment is "hold … under pressure". One Judgment value. |
| B. Use a fear-free Judgment for this term | Cleaner Standing story. Needs a second Judgment value. Against one behaviour authority (GDD 11.5 in-combat guidance). |

Advice: A. It adds a readable contrast (calm veteran vs shaken veteran) and costs no code.

### J4. Depth of reinterpretation versus the shared budget
With the budget at 2.0 the seasoned Echo keeps at least half of the young Echo's Directive stop pull (floor 0.5 at the limit). For an edge Echo under Scout the stop only weakens (Standing 9: 0.46 against 0.64). The big growth signals are the cause flip (anchor) and Seek dropping out. Edge Echoes show a smaller change.

| Option | Effect |
|---|---|
| A. Floor 0.55 to 0.6, budget stays 2.0 | Both layers read as one dial (1.67 to 1.82 against 1.80). Small change for edge Echoes. |
| B. Floor 0.5 | Maximum depth inside the budget. Zero headroom. |
| C. Raise `interpretation_swing_max` to 2.5, floor 0.4 | Seasoned edge Echo clearly walks on. Loosens the guard for the action layer too (which is at 1.80). Needs Jeff's approval to change a budget. |

Advice: A first. Probe (section 8). Choose C only if the probe shows an edge Echo's growth is invisible.

### J5. Seek rarely has a Directive stop
With Seek, base is 0.2. Most Directive stops fall below 0.15 (section 2b). Seek Echoes mostly stop for fear or identity.

| Option | Effect |
|---|---|
| A. Accept | Seek is the bold stance. A young Seek Echo can still pause (guard). A seasoned one does not. |
| B. Raise guard and hold affinity toward 1.0 | Young Seek pauses more often. Narrows the Scout and Seek contrast. |

Advice: A. Re-check after the probe.

---

## 8. Risks and what the probe must measure

### Risks

| Risk | Why | Control |
|---|---|---|
| Acceptance has no visible effect | Weight 2.0 is below the decision threshold (combat-003: first decides at 15 to 20). | J1. Probe the weight sweep. |
| Acceptance becomes an attractor | `weight x 0.3 >= 6.0` at weight 20. | Test C12. |
| Directive cause never changes a route | Bias at most `6.0 x 0.64` = 3.9 competes with `objective_progress_weight` 8.0 and others. LESSONS #38: a feature that fires rarely needs a measured rate. | Probe step 1: a small slice that proves the cause can change a chosen route, before any matrix. |
| Scout stops too often | Both Part 1 and Part 2 push Scout the same way. | Streak veto (shipped) stops consecutive stops. Probe the rate. |
| Hash moves lose attribution | Two changes move Scout hashes. | Land the parts in two steps. Acceptance first, record, then stop cause, record. `opus` agent attributes each (D-69 Q1). Serial runs; no parallel re-record. |
| Judgment range is unknown in play | The J values in this note are illustrative. Maximum positive weight sum is 0.95; Standing 1 has `rank_strength` 0. | Probe step 3. If J rarely passes 0.5, the Directive scale barely moves and growth is invisible. |
| Fixture hides the term | Default `judgment` 0.3 in ctx; empty bonds. | Section 5 fixture rule. |
| Seek stop cause is dead weight | Most Seek values fall below 0.15. | J5. Accept or retune affinity. |
| Stage bound leaks into combat | Same word "interpretation width". | Test C14; D-09. |
| A plan-level `_directive_bonus` does favour the stop option | Assumption A1 false. | `mechanics-developer` verifies before build. If false, the double count in section 4 row 1 vs 4 becomes real and the floor needs a joint budget. |

### The probe must measure

The main chat runs it (RUN REQUEST rules in `AGENTS.md`). Subagents do not.
Use shipped boards, production construction, Echo-only, fixed seeds, a clean save directory.

| # | Measure | Why |
|---|---|---|
| 1 | Lever check: on a small slice, how many chosen routes change if the Directive cause is removed (counterfactual re-score) | LESSONS #38. Stop before any matrix if the count is 0. |
| 2 | 2 x 2: acceptance on/off x Directive cause on/off, under Scout and Seek. Count stop-short events per fight and changed route choices | Separates Part 1 from Part 2. Measures the joint size of row 8. |
| 3 | Real Judgment per Standing (1 to 9) for the shipped starter Echoes, with and without fear and bonds | Replaces the illustrative J values. |
| 4 | Directive-cause share of all stops, by Standing and Calling family, under Scout | Proves the pillar: share falls, identity share rises, with Standing. |
| 5 | Stops per Echo per fight, Scout and Seek | Detect spam (Scout) and dead feature (Seek). |
| 6 | Acceptance weight sweep (2, 8, 11, 14) | Pick J1. Count changed lines, as combat-003 did. |
| 7 | Whether an edge Echo's stop rate under Scout changes between Standing 1, 6, 9 | Decides J4. |
| 8 | Hash moves per step, each with one named cause | D-69 Q1 attribution. |

### Design pressure answers

| Question | Answer |
|---|---|
| Is the outcome legible without an ID or number? | Yes for the behaviour: a pause and a visible guard, watch or hold action, and a route choice. The reason text is Jeff's (Q6). |
| Does it survive a player who never reads it? | Yes. The behaviour changes with no screen. |
| Does it produce a decision? | Yes. The Keeper chooses Scout or Seek. The Echoes show different results as they grow. |
| Does it use fear and emotion? | Yes. Fear is an unscaled cause. Fear lowers Judgment, so a shaken Echo leans on orders (J3). |
| Standing 1, 6, 9? | Section 1c. |

---

## 9. Deferrals — what phase D does not cover

| Item | Owner |
|---|---|
| Player-facing text for the Directive stop cause (D-69 Q6) | Jeff, after the code exists. Copy rule: a fear or Judgment reason never reads as a fault of the Echo (D-40 item 4). |
| Fear or Judgment in the acceptance term | New small story if Jeff picks J2 B or C. |
| Divergence detection for a skipped Directive stop (ANSWERS #46) | Not in phase D. Name it as a follow-up if the probe shows seasoned Echoes walking on. |
| `reposition`, `regroup`, ping and guidance code | V2-COMBAT-004 (D-07, D-09). |
| Stage `interpretation_width` in combat | Never (D-09). |
| Hazard data in the exposure map | "Stage hazards and exposure" story (D-02, D-31). |
| Press the Path, Hold the Circle | V2-DIRECTIVE-003 (D-06). |

---

## OPEN — questions and assumptions

ASSUMED: A1. A stop-short route option scores with its plan's `_directive_bonus`, which is equal for all options of that plan, so `_directive_bonus` cannot favour a stop. | WHY: `BehaviorArbiter.gd:787-801` calls `_score(str(plan["type"]) …)` once per candidate; route options differ only by `_spatial_utility`, style alignment and the stop bias. I read the call, not a run. | WRONG IF: the route candidate's score carries a benefit-action Directive bonus (guard or observe). Then rows 1 and 4 of section 4 double count and the floor needs a joint budget.

ASSUMED: A2. The swing budget convention (ratio of multipliers at J = 1, affinities ignored) is the right way to budget the stop layer. | WHY: It copies `compute_interpretation_swing` (`BehaviorArbiter.gd:1935-1950`), so one budget key covers both layers. | WRONG IF: Jeff wants the budget to include affinities or the J = 0 baseline. Then the numbers in section 3 change.

ASSUMED: A3. The offset key sits outside the closed `spatial_utility` block (a sibling in `data.combat.movement`). | WHY: Avoids a schema change and three fixture edits. | WRONG IF: `mechanics-developer` finds `_validate_spatial_config` or the movement config loader rejects unknown siblings of `spatial_utility`.

ASSUMED: A4. The Judgment values per Standing in sections 1c and 2b (0.2, 0.5, 0.85) are illustrative. | WHY: The real values depend on archetype, accent, bonds, vows and fear. | WRONG IF: Probe step 3 shows another range. Then the crossover points and the Seek cutoff move. Redo the tables.

ASSUMED: A5. The affinity ranges (guard and hold large, observe small) and the floor 0.6 are starting points only. | WHY: D-69 Q3 fixes the shape, not the numbers. | WRONG IF: `mid-game-designer` authors values that break the budget test or `min_cause_strength` cutoffs in section 2b.

ASSUMED: A6. A missing `exposure_tolerance` gives acceptance 0 and no Directive stop cause. | WHY: A future Directive may be stage-only (D-19). Neutral is the safe default. | WRONG IF: Jeff wants D-15 to make `exposure_tolerance` a required field.

BLOCKED: J1 (acceptance weight), J2 (acceptance maturity or fear), J3 (frightened Echo leans on orders), J4 (reinterpretation depth versus budget), J5 (Seek's rare Directive stop) | CHECKED: D-05, D-08, D-09, D-10, D-14, D-69, `design.md` lines 31, 100, 320, 349, ANSWERS #81 to #83, GDD 11.5, combat-003 handoff 22.4 | NEED: Jeff's choice per question in section 7. Phase D can start on the parts that do not depend on them (offset key, cause row, test C10, C11, C13, C14) while J1 waits for probe step 6.

BLOCKED: Q6, player-facing words for the Directive stop cause | CHECKED: D-69, D-40 item 4 | NEED: Jeff's wording after the code exists.
