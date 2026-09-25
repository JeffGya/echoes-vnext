# Pace Bonus — System Design Spec

**Status:** APPROVED by Jeff, 2026-09-25 (decisions.md D-14). Code may start after phase 2 sets the values.
**Owner:** sr-game-designer. **Story:** merged speed-bonus / board-size story (decisions.md D-01 to D-02, ANSWERS.md #63, #64).
**Scope:** design only. No code, no config values, no numbers — those are Jeff's / mid-game-designer's.

---

## 0. Introduction

The old speed bonus used one fixed round count: 5 rounds, for every mode, on every board size.
`RewardCalc.gd:80-82` checked `round_ended < speed_threshold` and paid one flat bonus for wins
before that round. A win exactly on round 5 did not earn the bonus.

This had two problems. A board-size change moved most modes across the 5-round line at once.
5 rounds means something different on a small board than on a large one. Some modes cannot use a
round count at all. Their win condition is a fixed duration (a timer), not a race. They could
never earn the bonus.

This design replaces the fixed round count with **pace**. Pace compares two numbers: the round
the fight ended, and **par**. Par is the number of rounds a good win needs in that specific
fight. The design computes par at the start of the fight. Par uses three inputs: the distance to
the target, the party's movement range, and the fight's hold requirement (if any). Par is a
formula, not an authored number, so it adjusts by itself to any board size.

The **pace bonus** pays a share of the stage base reward. The share is full at or below a limit
called `pace_full_ratio`, and drops in a straight line to zero at a second limit called
`pace_zero_ratio`.

Four modes are pace modes: COMBAT and PURIFY_SHRINE (win by killing), RECOVER (win by holding a
relic), and PURSUE (win by containing a quarry). Three modes are no-pace modes: PROTECT, ENDURE,
and GUIDE_SPIRIT, which has two variants (protect and escort). Their win condition is a fixed
duration, not a race. A timer-based fight has no faster-or-slower version of the win, so there is
nothing for a pace bonus to measure. GUIDE_SPIRIT's escort variant has a separate reason for
carrying no pace bonus, stated in §3.

During the fight, the player sees pace only as a colour on the existing round counter and
objective progress (§6). At the fight result, the player also sees a "Pace bonus" reward row and,
when it applies, a rank-cause note (§6). No pace text appears at any point (decisions.md D-12).

---

## 1. Terms

Each row defines one term. The document uses only the term in the left column; it does not use a
synonym for it.

| Term | Field / code name | Definition |
|---|---|---|
| Round | `round_counter` | One unit of fight time. The fight advances round by round. |
| Round ended | `round_ended` | The round number at which the fight's win or loss condition triggered. |
| Par | `par_rounds` | The round count a good win needs in this fight, computed at fight start. |
| Travel rounds | `travel_par` | The part of par that covers movement: distance to the target divided by the party's mean movement range, floored at 1. |
| Hold rounds | `required_hold` | The part of par that covers holding the objective, after arrival: `max(0, hold_amount - 1)`. |
| Pace ratio | `pace_ratio` | `round_ended` divided by `par_rounds`. A value of 1.0 means the fight ended exactly at par. |
| Pace bonus | `pace_bonus_awarded` | A reward paid to a pace-mode win, sized by the pace ratio against the bonus curve (§4). |
| Full-bonus limit | `pace_full_ratio` | The pace ratio at or below which the pace bonus is at its maximum. |
| Zero-bonus limit | `pace_zero_ratio` | The pace ratio at or above which the pace bonus is zero. |
| Maximum bonus | `pace_bonus_pct` | The largest fraction of the stage base reward the pace bonus can pay. |
| Reached enemy | (tracked in `combat_state["reached_enemy_ids"]`) | An enemy that has, at least once, ended a round within Chebyshev distance 1 of a living echo. |
| Pace mode | — | A mode whose win condition can happen faster or slower: COMBAT, PURIFY_SHRINE, RECOVER, PURSUE. |
| No-pace mode | — | A mode whose win condition is a fixed duration or is not yet trackable: PROTECT, ENDURE, GUIDE_SPIRIT (both variants). |
| Pace state | `pace_state` | A three-state value, for pace modes only: `full`, `partial`, or `none`. It compares the current or final round to the two bonus-curve limits (§4). One field carries it during the fight; one field carries it at the result. Both use the same three values (§6). |

---

## 2. Player rule

The old line was: "Win with room to spare, and you earn a pace bonus." This line uses an idiom
("room to spare") and does not say what "room" means.

**DECIDED (decisions.md D-11):**
> "Stay on pace, and you earn the pace bonus."

---

## 3. Pace per mode

Par is `par_rounds = travel_par + required_hold`. The pace ratio is `pace_ratio = round_ended /
par_rounds`.

**Travel rounds.** `travel_par` = distance divided by mean party movement range, floored at 1, not
rounded up. The design uses floor, not ceiling. Ceiling systematically raised par for every mode.
It pulled pace ratios further apart, not closer together (measured in §9).

- Distance uses `GridService.chebyshev_distance` (`core/grid/GridService.gd:81`). The design never
  uses Manhattan distance: all movement is 8-way (`core/combat/CombatActivationService.gd:37-79`).
- Movement range uses the mean, over echoes, of
  `MovementProfileService.derive_profile(actor, data.combat.movement.capacity)["capacity"]`.
- `travel_par` is computable once actors have positions, right after `GridService.place_actors()`
  returns (`core/combat/EncounterSetupService.gd:394`).

**Hold rounds.** `required_hold = max(0, hold_amount - 1)`. This `-1` is not a tuning number. It
reflects how the round counters already work. The round an echo first arrives adjacent to the
target already advances that round's counter. RECOVER's counter is `hold_counter`
(`CombatRoundSpawnService.gd:139`). PURSUE's counter is `contain_counter`
(`CombatRoundObjectiveService.gd:312`). Only the rounds beyond arrival are extra.

**Win-type table.** The formula uses one shape for every mode, classified by win type.

| Win type | Modes | Distance measured to | `hold_amount` |
|---|---|---|---|
| Kill | COMBAT, PURIFY_SHRINE | Nearest enemy, mean over echoes (`d_mean`) | 0 |
| Hold | RECOVER | Relic, from the nearest echo only (`d_obj`) | `hold_rounds` (win condition `relic_secured`, `CombatState.gd:283`) |
| Contain | PURSUE | Quarry, mean over echoes (`d_mean`) | `contain_rounds` (decision below), applied to every PURSUE fight |

PURIFY_SHRINE measures distance to the nearest **enemy**, not the shrine. PURIFY_SHRINE's win
condition is `all_enemies_defeated` (`CombatState.gd:252`); the shrine's death is the loss
condition (`:258`), not the win condition.

RECOVER measures distance from the nearest echo, not the mean over echoes. Only one echo needs to
reach and hold the relic, so the closest echo sets the par.

**Decided (Jeff, decisions.md D-08): PURSUE charges the contain term on every fight, including a
fight that ends by killing the quarry.** PURSUE's par is set at fight start. This is before the
round-by-round contest between the kill path and the contain path is decided. Par cannot look up
which win will happen. Charging the contain term on every fight makes one par value correct for
both cases. PURSUE's kill-reason wins land near COMBAT and PURIFY_SHRINE (median 1.19 old board,
1.09 new board). Its contain-reason wins land near RECOVER (median 0.84 old board, 0.86 new
board). See §9 for the full table. The design tested one alternative: charging
`required_hold = 0` on kill-reason wins, as if they were COMBAT wins. This was rejected. It
reproduces the same large mismatch this design exists to fix. A fleeing quarry reliably takes
longer to run down than a static distance-and-capacity estimate predicts. **Accepted trade-off:**
a PURSUE kill win earns the pace bonus more easily than a PURSUE contain win (median about 1.1
against about 0.85).

**Decided (Jeff, decisions.md D-09): RECOVER's par uses the nearest echo's walk to the relic.** Only
one echo must reach and hold the relic, so the nearest echo's Chebyshev distance sets par, not the
party mean.

**Decided (Jeff, decisions.md D-10): GUIDE_SPIRIT's escort variant earns no pace bonus at this
stage.** In the probe data, 0 of 48 escort fights ended in `spirit_escorted`. A non-joining escort
spirit is currently built as an immobile structure. This is filed as defect V2-COMBAT-004
(`docs/stories/v2-infra-003/defect-register.md:265`). No code currently tracks a live spirit-to-destination
distance (`CombatRoundGuideSpiritService.gd:40/259/313` only tests arrival). Once V2-COMBAT-004
makes the escort win reachable, the design revisits this. Escort would become a contain-type
mode: spirit to destination, `hold_amount` 0, since arrival is itself the win. PROTECT, ENDURE,
and GUIDE_SPIRIT's protect variant earn no pace bonus. Their win condition is a fixed duration.
There is no faster-or-slower version of it (`CombatState.gd:295/301/325`).

Measured medians are reported in §9, where the acceptance criteria live. This section states the
formula; §9 states what it measures to.

---

## 4. Bonus curve

`pace_ratio` measures against a shared scale: 1.0 means the fight ended exactly at par. The
**bonus curve** maps `pace_ratio` to a bonus fraction of the stage base reward. The curve replaces
the old all-or-nothing cliff.

The curve shape is linear, with two breakpoints:

1. At or below `pace_full_ratio`, the bonus fraction is at its maximum, `pace_bonus_pct`.
2. At or above `pace_zero_ratio`, the bonus fraction is zero.
3. Between the two breakpoints, the bonus fraction drops in a straight line.

`pace_full_ratio`, `pace_zero_ratio`, and `pace_bonus_pct` are each **one global value**. This is
valid now because every mode's pace ratio sits on the same scale (§3). Under the old design, one
global value sat over two different scales, which is why it produced a flat cliff instead of a
gradient.

No mode gets its own copy of these three values. Each mode's par (§3) is a formula computed from
that mode's own fight data. It is not an authored number and not "a number per mode"
(ANSWERS.md #63).

---

## 5. Rank

**Ceiling problem, pace bonus.** Today, `max_possible` (`RewardCalc.gd:87-106`) always includes the
full pace bonus in its numerator and denominator, even for modes that cannot earn it. This gives
those modes an unremovable rank ceiling below S/A.

**Fix.** For no-pace-mode fights, `max_possible` excludes the pace bonus from both numerator and
denominator; those fights rank on kills and survival alone. For pace-mode fights, both sides of
the ratio use the same bonus curve, so the top of that mode's own scale stays reachable.

**Ceiling problem, kill term — in scope this story** (Jeff, overriding an earlier deferral).
`max_possible`'s `total_enemies * enemy_bonus_per` term currently counts every enemy placed on the
board, including enemies that never reached the party. This must change to count only **reached
enemies** (§1).

- **Reached** means: the first round an enemy ends within Chebyshev distance 1 (melee adjacency,
  `GridService.is_adjacent`, `:88`) of a living echo. The design does not define a separate
  attack-range concept, because none exists. `CombatService.gd`'s only resolution path is
  `_resolve_melee` (`:70`). Adjacency-1 already is every enemy's actual reach today. A future
  ranged enemy type would need its own range definition; none exists now, so this is out of scope.
- **Tracking.** The design adds new round-by-round bookkeeping in `core/`, because enemy waves can
  spawn mid-fight (`CombatRoundSpawnService.gd`). An unspawned enemy has not reached yet. An
  enemy that reaches in round 3 and dies in round 5 must still count as reached.
  `combat_state["reached_enemy_ids"]` is an id list, not a per-actor flag (§7). It gains an
  enemy's id the first qualifying round and never loses an id. This is the same accumulate-never-
  reset pattern `protect_counter` and `guide_protect_counter` already use.
- **Scope.** This fix applies to PROTECT, ENDURE, RECOVER, PURSUE, and GUIDE_SPIRIT (both
  variants). It does not apply to COMBAT or PURIFY_SHRINE. Those two modes win only through
  `all_enemies_defeated` (`:252`). That win condition already forces every board enemy to be
  engaged, so `total_enemies` is already the correct ceiling for them. The ceiling problem is
  specific to modes whose win condition lets the fight end without engaging every enemy.
- **Measured reach rates** confirm the problem is mode-specific (`pace-measurements.txt` M2, old
  board / new board). Rates are: ENDURE 40% / 12%, PROTECT 87% / 83%, GUIDE_SPIRIT 62% / 33%,
  RECOVER 22% / 14%. On the new board, 88% of ENDURE's placed enemies never reached the party, yet
  all still count under the current rule.
- This fix combines with the pace-bonus fix above. For the same five modes, `max_possible`
  excludes both the full pace bonus and any never-reached enemy, on both sides of the ratio.

**Separate follow-up.** With both fixes in place, most wins likely sit near rank S
(`pace-measurements.txt` M4, "no-speed" / "+reached" columns). What rank should measure is a
design question the old speed cliff and the inflated kill ceiling were masking, not one this
design creates. The design recommends a separate follow-up story on that question.

---

## 6. Screens

**Decided (Jeff, decisions.md D-12): pace shows as colour, not text.** ANSWERS.md #64 asked for the
goal to be visible during the fight. This design meets that goal with colour, not with a new text
line. No new screen element is added during the fight.

**During the fight** (`CombatBoardScreen.gd`; round label at `:329`; objective banner at
`_render_objective_banner`, roughly `:449-477`). For pace modes only, these two existing elements
change colour, driven by `pace_state` (§1):

| `pace_state` | Meaning | When |
|---|---|---|
| `full` | A win now would earn the full pace bonus. | `round_counter <= pace_full_ratio * par_rounds` |
| `partial` | A win now would earn part of the pace bonus. | Between the two limits |
| `none` | A win now would earn no pace bonus. | `round_counter >= pace_zero_ratio * par_rounds` |

`par_rounds` is fixed at fight start (§3). Only `round_counter` changes, so `pace_state` is a
plain comparison, re-evaluated each round. It needs no new tracking. ui-ux-designer and Jeff pick
the actual colours; this design names only the three states (`full`, `partial`, `none`), not
colour values.

**No-pace-mode fights keep their normal colour (decisions.md D-06 still holds).** These modes never
show a pace colour. No placeholder colour and no colour-only "no pace" signal are shown either.

**At the fight result — decided (Jeff, decisions.md D-13)** (`ResolveScreen.gd`, next to `_rank_badge` at
`:164-166`, and in `_build_breakdown` at `:442`). Three things happen for pace modes, and only these three:

1. The round count / win-condition line carries the same `pace_state` colour it had at the
   moment of the win, the same three states as during the fight.
2. The reward list keeps one "Pace bonus" row (`EconomyService.gd:161`, was "Speed bonus"), with
   its Ase amount, shown every time — including at 0, not only when it is greater than zero.
3. When the pace bonus changed the rank, a short rank-cause note names it next to the rank badge.
   This note is new. No rank-cause rule exists in the code today; decisions.md D-13 decides it.

For no-pace modes, none of these three appear: the round line keeps its normal colour, and there
is no "Pace bonus" row.

---

## 7. Data contract

Field names below are proposed; mechanics-developer confirms the exact shape before
implementation. The Snapshot Shape rule applies (`AGENTS.md:360-368`).

The live `pace_state` and the final `pace_state` are two separate fields, one per screen. Both
use the same term and the same three values (§1): `full`, `partial`, `none`. The **live field**
updates each round, while the fight is in progress. The **final field** is fixed once the fight
has ended.

| Location | Field | Type | Values | Present when |
|---|---|---|---|---|
| `flow.encounter.data.objective_state` | `pace_state` | string | `full`, `partial`, `none` | Pace mode only; absent otherwise and in the keeper-intro trial (decisions.md D-18) |
| `flow.resolve.data` | `pace_bonus_awarded` | int (Ase) | any value, mirrors `speed_bonus`'s shape | Pace-mode victory only |
| `flow.resolve.data` | `pace_state` | string | `full`, `partial`, `none` | Pace-mode victory only; absent after a defeat (decisions.md D-19) |

`pace_ratio` is not in the snapshot data. It is a raw float, and ANSWERS.md #59 keeps raw floats
out of player-facing data. The screen needs only `pace_state` (decisions.md D-20).

**`pace_state` follows the Ase (decisions.md D-17).** The state is `partial` only when the pace
bonus pays at least 1 Ase. During the fight, this is the bonus that a win in the current round
would pay. A bonus that rounds to 0 Ase gives `none`. So the colour and the "Pace bonus" row
always agree.

`pace_state` sits alongside the existing per-mode fields in
`flow.encounter.data.objective_state` (`CombatBoardScreen.gd:440-480`).

`pace_bonus_awarded` and `pace_state` sit alongside `rank`, `ase_awarded`, and
`reward_breakdown` in `flow.resolve.data` (`ResolveScreen.gd:164-179`). `reward_breakdown` keeps
its existing `{label, delta, currency}` shape (`EconomyService.gd:155-161`). The pace entry
replaces the "Speed bonus" line under a new label. It is present at 0 with a distinguishing label
when the pace bonus is missed. This lets `ResolveScreen.gd` render it every time, instead of only
when the value is greater than zero.

No existing field is renamed or removed at the snapshot layer.

**Reached-enemy tracking (§5), placement corrected.** The field is not stored on the enemy actor
dict. Actor dicts are read-only views, deep-copied at construction (`AGENTS.md:392-393`).
Nothing may write a persistent flag onto one. The field belongs on
`combat_state` instead, alongside `protect_counter` and the other per-fight accumulators:
`combat_state["reached_enemy_ids"]`, an Array of enemy actor ids, not a bool per actor. An id is
appended the first round that enemy ends adjacent (Chebyshev 1) to a living echo, and never
removed. `RewardCalc.compute()` gains a `reached_enemies` input (`reached_enemy_ids.size()` at
encounter end), used instead of `total_enemies` for PROTECT/ENDURE/RECOVER/PURSUE/GUIDE_SPIRIT's
`max_possible`. COMBAT and PURIFY_SHRINE keep `total_enemies` unchanged.
Mechanics-developer confirms whether `reached_enemy_ids` belongs directly on `combat_state` or on
a sub-dict before implementation.

---

## 8. Config (`data.rewards`)

**Decided (Jeff): `speed_bonus_threshold` and `speed_bonus_pct` are removed from
`data/balance.json`**, under the `AGENTS.md:357-358` V2-PROG-012 exception, not the default
additive-only rule. Once `RewardCalc.gd:80-82` stops reading them, they become unreachable in
exactly the sense that exception requires.

**Added keys:** `pace_full_ratio`, `pace_zero_ratio`, `pace_bonus_pct`. `pace_bonus_pct` is a new
key, not a reuse of `speed_bonus_pct`: its meaning changes from "flat bonus" to "maximum of a
gradient."

**Removed keys, every consumer migrated in the same change:**

| Consumer | Change |
|---|---|
| `core/economy/RewardCalc.gd:80-82` | Only production reader; migrates to the bonus curve. |
| `tests/EconomyRewardTests.gd:33-34` | Inline test config sets both keys; migrates too. |
| `data/balance.json` | Both keys deleted, not left as dead config. |

The story writeup records this as a full-repo audit under the V2-PROG-012 precedent
(`AGENTS.md:358`), the same way that exception's four prior renames were recorded.

---

## 9. Acceptance criteria

**Measured medians** (stage-0 probe, 336 fights, `victory == true` only), using §3's formula:

| Mode / win type | Old board | New board |
|---|---|---|
| COMBAT (kill) | n=22 med **1.13** [p10 1.07, p90 1.52] | n=21 med **1.10** [p10 0.88, p90 1.60] |
| PURIFY_SHRINE (kill) | n=22 med **1.40** [p10 1.11, p90 1.76] | n=17 med **1.10** [p10 0.95, p90 1.63] |
| RECOVER (hold) | n=24 med **0.85** [p10 0.71, p90 1.00] | n=24 med **0.92** [p10 0.86, p90 1.53] |
| PURSUE, all wins (contain) | n=10 med **0.94** [p10 0.84, p90 1.25] | n=9 med **0.98** [p10 0.85, p90 1.44] |
| — PURSUE, kill-reason wins only | n=7 med 1.19 [p10 0.89, p90 1.32] | n=6 med 1.09 [p10 0.93, p90 1.46] |
| — PURSUE, contain-reason wins only | n=3 med 0.84 [p10 0.83, p90 0.94] | n=3 med 0.86 [p10 0.82, p90 1.04] |

All four medians sit in **0.85-1.40** (old board) and **0.92-1.10** (new board). Every mode stays
stable across boards within about 0.1-0.3, and no mode's median differs from any other's by more
than about 1.6x. Under the earlier formula the gap was up to 3.2x (COMBAT 1.13 against PURSUE
1.89, old board).

This is not a perfect match across modes. PURIFY_SHRINE's old-board median, 1.40, is the widest
outlier. On the same old board, COMBAT is 1.13, RECOVER is 0.85, and PURSUE (all wins) is 0.94. A
median is not moved by a small number of unusually long fights. It is the middle value of 22
fights. p10 is 1.11: 90% of PURIFY_SHRINE's old-board wins already sit at or above 1.11. This is a
systematic difference on the 12x12 (old) board specifically, not an effect of outliers. Its cause
is not established. A possible cause is that shrine-defense combat takes structurally longer than
a single-enemy COMBAT fight at this stage; this is unverified. The gap shrinks on the new board
(1.10), so it does not block this design. It should not be described as noise. This formula fits
the data better than any earlier variant tested. No further start-state formula tried in this
design closes the remaining gap. Closing it further would need either looser bonus-curve
breakpoints (§4) or a change to PURIFY_SHRINE's or RECOVER's fight length, not a different pace
formula.

**Bonus rate at a fixed limit `R`** (share of wins with `pace_ratio <= R`, old board / new board).
This table matters for one reason. The median table above does not say how equally the four
modes will earn the bonus at any one breakpoint choice.

| R | COMBAT | PURIFY_SHRINE | RECOVER | PURSUE |
|---|---|---|---|---|
| 1.0 | 9% / 38% | 4% / 17% | 91% / 83% | 60% / 55% |
| 1.5 | 86% / 85% | 72% / 76% | 100% / 87% | 100% / 88% |

At `R=1.0`, RECOVER and PURSUE pay the bonus to most winners, while COMBAT and PURIFY_SHRINE pay
it to almost none. Median convergence does not mean the four modes feel equally generous at any
one breakpoint. At `R=1.5`, all four sit within about 14 percentage points of each other on both
boards.

This criterion cannot be settled by the formula alone. It depends on the `pace_full_ratio` and
`pace_zero_ratio` values mid-game-designer proposes and Jeff picks in phase 2. The criterion is
restated below against those values, not against the formula in isolation.

**Criteria:**

1. **Once `pace_full_ratio` and `pace_zero_ratio` are set (phase 2), re-run the probe and confirm
   both:**
   a. For each pace mode, the share of wins earning the full bonus (`pace_ratio <=
      pace_full_ratio`) is stable across board sizes. Old-board share and new-board share differ
      by no more than a maximum gap, set in phase 2. See the `R=1.0`/`R=1.5` table above for the
      scale of gap to expect.
   b. That same share is comparable across the four pace modes. No two pace modes' full-bonus
      shares differ by more than a second maximum gap, also set in phase 2.
   Both gaps are values a verifier can check pass/fail once phase 2 sets them; this design does
   not set them.
2. RECOVER's `pace_ratio` does not flip discontinuously between board sizes. `par_rounds` includes
   `hold_rounds - 1`, which keeps the denominator well clear of 0 on both boards (measured above).
3. PURSUE's `pace_ratio` uses the same `par_rounds` (including `contain_rounds - 1`) regardless of
   whether the fight ends by `quarry_contained` or `all_enemies_defeated`. The per-reason
   breakdown above confirms this: kill-reason wins land near COMBAT/PURIFY_SHRINE, and
   contain-reason wins land near RECOVER, rather than forming one inconsistent aggregate.
4. No no-pace-mode fight has its rank capped below what kills and survival alone would earn.
5. For PROTECT, ENDURE, RECOVER, PURSUE, and GUIDE_SPIRIT, `max_possible`'s enemy term counts only
   ids present in `combat_state["reached_enemy_ids"]` (§7). Re-run M4's "+reached" column against
   the implemented tracking. COMBAT and PURIFY_SHRINE are unaffected and keep `total_enemies`.
6. `combat_state["reached_enemy_ids"]` only grows within a fight, including across ENDURE's wave
   spawns. It never loses an id once added.
7. The encounter screen's live `pace_state` and the result screen's final `pace_state` are each
   present, in one of three states, if and only if the mode is a pace mode. Both are verified by
   a snapshot assertion per mode.
8. The result screen's "Pace bonus" row is present, at any value including 0, if and only if the
   mode is a pace mode.
9. When the pace bonus causes a rank change, the rank badge names it as the cause.

**Recorded values that move.** The 14 fingerprint/determinism suites need FINAL/SAVE
re-recording for any fixture that touches the pace bonus or the reachability-based kill term.
`tests/EconomyRewardTests.gd` (tests 5-6, `:109-124`, plus the inline config at `:33-34`) are
written against the old cliff and must be rewritten, not only re-recorded. Kinds only, per scope.

---

## 10. Known limits and open questions for Jeff

- **Stage-0-only measurement.** All ratios and rates come from stage-0 fights. Later stages,
  other party sizes, and non-Standing-1 parties are unmeasured. The design should hold by
  construction, because par is derived from live distance and capacity, but this is unverified
  past stage 0.
- **Travel-time caveat.** At stage 0, `travel_par` is close to "time to reach the fight," not a
  measure of tactical skill (§3). This may matter less at later stages; unmeasured.
- **Convergence is close, not exact.** §9's measured medians span 0.85-1.40 (old board) and
  0.92-1.10 (new board). This is better than any earlier variant, but not one identical value. No
  formula tried in this design closes this gap fully; see §9 for what a tighter fit would need.
- **Decided (decisions.md D-08 to D-10):** PURSUE charges `contain_rounds - 1` on every fight, regardless
  of the eventual win reason. RECOVER's par uses the nearest echo's walk to the relic.
  GUIDE_SPIRIT's escort variant earns no pace bonus until V2-COMBAT-004 is fixed. See §3 for the
  reasoning and the accepted trade-off. These are no longer open questions.
- **The breakpoint choice decides how equal the modes feel, separately from whether they
  converge.** §9's `R=1.0`/`R=1.5` table shows this. At `R=1.0`, RECOVER and PURSUE pay the bonus
  to 55-91% of winners, while COMBAT and PURIFY_SHRINE pay it to 4-38%. Median convergence does not
  guarantee bonus-rate convergence at any single breakpoint. Mid-game-designer's
  `pace_full_ratio`/`pace_zero_ratio` proposal should be checked against this table, not only
  against the median table, before Jeff picks values.
- **PURIFY_SHRINE's old-board pace is systematically slower; cause unknown.** Median 1.40, against
  1.13 for COMBAT, 0.85 for RECOVER, and 0.94 for PURSUE (all wins) on the same old board. This is
  not an outlier effect (§9). It is worth a follow-up look at what differs about shrine-defense
  fights specifically, independent of this story.
