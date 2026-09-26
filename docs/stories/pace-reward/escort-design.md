# Escort pace — system design proposal

**Status: PROPOSED — not approved.**
**Owner:** sr-game-designer. **Story:** pace-reward, extension under decisions.md D-31.
**Depends on:** `docs/stories/pace-reward/design.md` (APPROVED), `docs/stories/pace-reward/decisions.md`
(D-02, D-06, D-08, D-09, D-10 superseded, D-15, D-16, D-21 to D-23, D-31), ANSWERS.md #63, #64,
`docs/stories/v2-combat-003.5/decisions.md` #58 to #60.

This document proposes how the escort variant of GUIDE_SPIRIT earns a pace bonus. It answers the
ten questions Jeff raised through D-31. It is a proposal. No value or rule here is built until
Jeff approves it.

---

## 0. Summary table

| # | Question | Recommendation |
|---|---|---|
| 1 | Whose movement sets par | The spirit's own movement, not the party's. `travel_par = distance(spirit start, destination) / spirit capacity`, minimum 1.0. |
| 2 | Hold rounds | None. `hold_amount = 0`. Arrival is the win; `required_hold` stays 0. |
| 3 | Two ways to win | One par for both `spirit_escorted` and `all_enemies_defeated`, fixed at fight start, same rule PURSUE already uses. |
| 4 | Variant roll (join / no-join) | Same formula for both. Flag that a joined spirit is not steered toward the destination; report its wins separately in measurement. |
| 5 | Swap blocking | No extra slack. The swap does not delay the spirit's own step; the shared curve already tolerates normal path noise. |
| 6 | Rank | Add escort to the pace-mode set, guide-mode aware. Same additive mechanism design §5 already uses; protect stays excluded. |
| 7 | Player rule | Unchanged. "Stay on pace, and you earn the pace bonus." Same three colours, same meaning. |
| 8 | Measurement plan | A dedicated escort-only probe, both boards, both realms, join and no-join split, before any curve number is treated as final. |
| 9 | Acceptance criteria | Ten criteria, listed in §9, extending design.md §9's pattern. |
| 10 | What does not change | Protect variant, the other four modes' formulas and curve values, the colour and result-screen rules, the variant/join rolls, D-23's kill rules. |

---

## 1. Whose movement sets the escort par

In COMBAT, PURIFY_SHRINE, and PURSUE, the party walks to the target, so the party's mean movement
capacity sets `travel_par`. In RECOVER, only the nearest Echo must arrive, so that Echo's own
capacity sets it (decisions.md D-09). Escort follows the same rule: **the actor that must arrive
sets the par.** In escort, that actor is the spirit, not the party. The party's own movement plays
no part in whether the spirit reaches the destination.

**Formula:**

```
travel_par = max(1.0, distance(spirit_start, destination) / spirit_capacity)
par_rounds = travel_par + required_hold   (required_hold = 0, see §2)
```

- `distance` is `GridService.chebyshev_distance`, the same primitive every other mode's par uses
  (`core/grid/GridService.gd:81`), from the spirit's fight-start `grid_pos` to
  `objective_params.destination_col/destination_row`.
- `spirit_capacity` comes from `MovementProfileService.derive_profile()`
  (`core/movement/MovementProfileService.gd:50`), the same function every other mode's par already
  calls. The capacity depends on the join roll:
  - **Non-joining spirit:** always capacity 1, via the authored override
    (`core/movement/GuideSpiritActivationService.gd:41,`~`301-309`, `AUTHORED_CAPACITY`). This is
    a fixed one-cell-per-round pace, not derived from Standing or agility.
  - **Joined spirit:** capacity from the ordinary formula (Standing, agility, Calling, skills),
    because a joined spirit is built as an EnemyActor with no `is_structure` flag and no override
    (`core/combat/EncounterObjectiveSpawnService.gd`~`400-427`). See §4 for why this still needs a
    caveat.
- The value is not rounded, matching every other mode's `travel_par` (design.md §3).

`compute_par()` (`core/combat/PaceService.gd:43-90`) needs a new branch: when
`mode == GUIDE_SPIRIT` and `guide_mode == "escort"`, find the spirit actor (`is_spirit == true`,
not `is_ally`) instead of the echo party, and use its own capacity instead of the party mean. The
call site, `EncounterSetupService._setup_pace()` (`core/combat/EncounterSetupService.gd:707-729`),
already runs after the spirit is placed and after `objective_params.destination_col/row` and
`spirit_joins_battle` are written (`core/combat/EncounterObjectiveSpawnService.gd:576-581`), so the
inputs exist at the point par is computed. No reordering of setup is needed.

---

## 2. Hold rounds

**Recommendation: no hold term. `hold_amount = 0`.**

The escort win fires the round the spirit's cell equals the destination cell
(`core/combat/CombatState.gd:250-251`, `destination_reached`). Arrival is the win; nothing must
hold after arrival. This differs from RECOVER, where the relic must be held for extra rounds after
the first echo arrives. Escort's `required_hold = max(0, hold_amount - 1) = max(0, -1) = 0` under
the same formula, so `par_rounds` equals `travel_par` exactly. This confirms the earlier design.md
§3 text ("spirit to destination, hold 0"); it is not changed.

---

## 3. Two ways to win

Escort can end in `spirit_escorted` (arrival) or `all_enemies_defeated` (every enemy killed,
`core/combat/CombatState.gd:252`, checked after the spirit-death and arrival checks). Par is fixed
at fight start (decisions.md D-21), before either path is decided.

**Recommendation: one par for both win reasons**, computed by §1's formula regardless of which
reason ends the fight. This is the same rule design.md §9 AC3 already states for PURSUE, which
also has two win reasons (`quarry_contained`, `all_enemies_defeated`) under one par. The reasoning
carries over exactly: par cannot look ahead at which win happens, so one value must serve both.

**Expected trade-off (unmeasured, flag for §8):** an `all_enemies_defeated` win in escort mode may
land far from the travel-based par, the same way a PURSUE kill-reason win lands near COMBAT's
pace rather than PURSUE's own hold-based par (design.md §3, D-08). The design does not add a
second, kill-reason-only par for escort. Adding one would be a hidden per-reason calibration,
which ANSWERS.md #63 and design.md §4 both rule out for modes; §8 asks mid-game-designer to
measure the size of this gap and report it split by win reason, the same way design.md §9 reports
PURSUE's split.

---

## 4. The variant roll: join or no-join

The escort/protect roll and the join roll are both seeded coin-flips at setup
(`core/combat/EncounterObjectiveSpawnService.gd`~`349-427`). Pace must follow the rolled variant
(escort vs protect), not the mode name — this is already true of §6's rank fix. Within escort,
does a joined spirit get the same pace rule as a non-joining one?

**Finding, read from code:** the two variants do not move the same way.

- A **non-joining** spirit is steered toward the destination every round by
  `GuideSpiritActivationService.activate_spirit()`, called from
  `core/combat/CombatRoundGuideSpiritService.gd`~`264-306`, gated by
  `if not bool(combat_state.get("spirit_joins_battle", false))`.
- A **joined** spirit is never routed toward the destination by that call. It fights as an
  ordinary combatant through the normal behaviour path (faction `"echo"`, built as an EnemyActor).
  The `destination_reached` position check still runs every round regardless of the join flag
  (`core/combat/CombatRoundGuideSpiritService.gd`~`324-331`), so a joined spirit can still win by
  arriving, but only if its combat movement happens to put it there.

**Recommendation: use the same formula (§1) for both.** Par states what a good, purposeful walk
needs; it is not a model of the AI path a joined spirit actually takes. Changing the formula per
variant would be a second hidden calibration, which ANSWERS.md #63 rules out.

**But flag this clearly, twice:**

1. A joined spirit's arrival is largely incidental, not steered. Its pace ratio is expected to be
   noisier than a non-joining spirit's, and "on pace" may not mean the same thing for it.
2. §8's measurement plan must report joined-spirit escort wins as their own row, separate from
   non-joining wins, so a small number of lucky-arrival wins cannot hide inside the aggregate and
   quietly move the curve.

This is consistent with decisions.md D-23, which already treats a joined spirit as not fully
party for the kill term (its kills pay Ase but do not count in rank). Escort pace treats it as not
fully steered, for the same underlying reason: a joined spirit is a combatant on loan, not a
guided companion.

---

## 5. Swap blocking

Decisions #59/#60 (`docs/stories/v2-combat-003.5/decisions.md`) added a swap: when the spirit's
next planned cell holds a living, non-structure party Echo, the spirit and the Echo trade cells as
part of the spirit's own activation, at no cost to the Echo
(`core/combat/CombatRoundGuideSpiritService.gd` `_apply_escort_yield`, ~`438-484`).

**Recommendation: no extra slack term for escort.** The swap does not cost the spirit a round. It
trades positions in the same activation that already resolves the spirit's one-cell step; the
spirit still moves its full authored capacity that round. Structurally, blocking by a friendly
Echo is fixed by the swap, not merely reduced.

**What is not fixed, and does not need a new term:** the spirit's route is recomputed each round
over live occupancy, so on a crowded board the walked path can still be longer than the straight
Chebyshev distance — terrain costs, non-yielding occupants (enemies, other structures), and the
fact that the swap only clears the very next cell, not a path further ahead. This is the same
travel-time caveat design.md §10 already states for every mode: Chebyshev distance is a lower
bound, not the walked path. The shared bonus curve (`pace_full_ratio` 1.10 to `pace_zero_ratio`
1.60) already exists to absorb this kind of normal slack for every mode. Adding an escort-specific
allowance now would be tuning before measuring, which D-02 already rejected once for this story.
**Recommendation: measure first (§8); add slack only if the probe shows a systematic gap.**

---

## 6. Rank

GUIDE_SPIRIT already sits in `PaceService.REACHED_ENEMY_MODES`
(`core/combat/PaceService.gd:22-28`), so its rank ceiling already excludes never-reached enemies,
for both variants. That part does not change.

Today `PaceService.PACE_MODES` (`core/combat/PaceService.gd:13-18`) does not include
GUIDE_SPIRIT, so `is_pace_mode()` returns `false` for it, `max_pace_bonus` is always 0
(`core/economy/RewardCalc.gd`, `is_pace` line), and neither side of `max_possible` carries a pace
term. Adding escort's pace bonus to both sides of the ratio uses the exact mechanism design §5
already built and proved fair for the other four modes: the top of the curve stays reachable
because both the numerator and the denominator gain the same `max_pace_bonus` term. This does not
newly cap escort; it adds one more earnable term to a ceiling escort already meets today without
it.

**Code implication, flagged for mechanics-developer:** `is_pace_mode()` is keyed on mode name
alone. GUIDE_SPIRIT has two variants, and only one of them should be a pace mode. This differs
from `tracks_reached_enemies()`, where both GUIDE_SPIRIT variants share one rule. The pace check
for GUIDE_SPIRIT must read `combat_state.guide_mode`, not just the mode name:

- `guide_mode == "escort"`: `is_pace_mode` true, `par_rounds` from §1.
- `guide_mode == "protect"`: `is_pace_mode` false, `par_rounds` 0.0, unchanged from today.

This must not cap PROTECT's rank. Confirmed: PROTECT stays out of `PACE_MODES` entirely (it
already is), so its `max_pace_bonus` stays 0 on both sides, the same reason D-06 gives for keeping
every timer mode pace-free. This proposal only touches GUIDE_SPIRIT-escort.

---

## 7. Player rule

**The rule is unchanged: "Stay on pace, and you earn the pace bonus."** (D-11.) ANSWERS.md #63
requires that the player state the rule in one sentence and never learn a number per mode, but
allows a formula that "derives each mode's target from values the mode already has." Escort's par
comes from the spirit's own start distance and its own capacity — values the mode already has,
exactly like PURSUE's window, distance, and capacity. No new player-facing sentence is needed.

**Colour meaning in escort:** identical to the other three pace modes (D-12, D-25). Green
(`full`) while a win right now would earn the maximum pace bonus; amber (`partial`) while it
would earn part of it; red (`none`) when it would earn none. Escort simply joins the existing
three-state legend on the round counter and objective banner. The protect variant keeps its
normal, no-pace colour, unchanged (D-06, D-30).

---

## 8. Measurement plan

2 of 11 escorted wins is far too small to set or confirm any curve number for escort. Before
values are treated as final, mid-game-designer must run a dedicated probe:

| Item | Requirement |
|---|---|
| Sample size | At least the scale of the existing probe per cell: design.md §9 used n=17-24 wins per mode per board; tuning.md §4.5 used 12 seeds × 2 realms × 2 boards. Force `guide_mode = "escort"` via the existing dev override (`dev_guide_mode`) so the 50/50 coin-flip does not halve the usable sample. Recommend at least 20 seeds per board, further split by the join roll (`dev_guide_joins`) so join and no-join each get a clean, separate cell. |
| Boards | Both board sizes (old, new), matching every other mode's probe. |
| Realms | Both realms (realm.01, realm.02), matching every other mode's probe. |
| Numbers | Escort-win rate, split by win reason (`spirit_escorted` vs `all_enemies_defeated`); `pace_ratio` distribution (median, p10, p90) for each win reason and combined, mirroring design.md §9's PURSUE split; full/partial/none share at the decided curve (1.10 / 1.60 / 0.05); Gap A (escort's own old-vs-new-board full-share gap) and Gap B (escort vs each of the other four modes, same board), both recomputed with escort folded in against the D-16 limits (≤ 50 pp, ≤ 90 pp). |
| Join split | Report joined-spirit wins and non-joining-spirit wins as separate rows (§4), not merged, until their pace behaviour is confirmed similar or different. |

**Do I expect the 1.10 / 1.60 / 0.05 curve to hold for escort? No, not without checking.** The
curve was set from COMBAT, PURIFY_SHRINE, RECOVER, and PURSUE data only (tuning.md §1). Escort's
par uses a single spirit's own capacity, which is fixed at 1 for the common non-joining case — a
much slower mover than a multi-echo party mean. A slow, fixed-capacity mover can land on a very
different part of the same ratio scale than the other four modes did. This must be checked, not
assumed.

**What result would change the curve, or the rule:**

- If escort's median `pace_ratio` sits far outside the other four modes' present spread (roughly
  0.92 to 1.10 on the new board, tuning.md §4.5), that is real information, not noise, the same
  way design.md §9 treats PURIFY_SHRINE's old-board median as real, not an outlier.
- If escort pushes any Gap B pairing (escort vs another pace mode, same board) past the decided
  ≤ 90 pp limit (D-16), that is the trigger to revisit. The first thing to check is not the shared
  curve values, but whether the escort par formula itself needs a mode-specific accepted
  trade-off, the same way PURSUE's kill-vs-contain split was accepted rather than changing the
  curve (D-08). Changing the three shared global values to fit escort alone would undo the fit
  the other four modes already have; that is a much larger, separate decision for Jeff.

---

## 9. Acceptance criteria

1. Once implemented, re-run the stage-0 probe (§8). Escort's full-bonus-share Gap A (old vs new
   board) is ≤ 50 percentage points and Gap B (escort vs any other pace mode, same board) is
   ≤ 90 percentage points (D-16's existing limits, escort now included in both comparisons).
2. Escort's `par_rounds` uses one formula for both win reasons (`spirit_escorted` and
   `all_enemies_defeated`), fixed at fight start. This mirrors design.md §9 AC3 for PURSUE.
3. Escort's `par_rounds` is 0.0 whenever `combat_state.guide_mode == "protect"`. `is_pace_mode()`
   for GUIDE_SPIRIT reads `guide_mode`, not only the mode name.
4. No GUIDE_SPIRIT-protect fight's rank is capped below what kills, survival, and reached-enemy
   tracking alone would earn. Unaffected by this change (mirrors design.md §9 AC4).
5. `RewardCalc.compute()`'s `max_possible` for a GUIDE_SPIRIT-escort fight includes
   `max_pace_bonus` on both sides of the ratio, the same mechanism as the other four pace modes
   (design.md §5). A GUIDE_SPIRIT-protect fight's `max_possible` excludes it, unchanged.
6. The encounter screen's live `pace_state` and the result screen's final `pace_state` are
   present, in one of the three states, for every GUIDE_SPIRIT-escort fight, and absent for every
   GUIDE_SPIRIT-protect fight. Mirrors design.md §9 AC7.
7. The result screen's "Pace bonus" row is present, at any value including 0, for a
   GUIDE_SPIRIT-escort victory, and absent for a GUIDE_SPIRIT-protect victory. Mirrors AC8.
8. A defeat in either GUIDE_SPIRIT variant shows no pace row, the normal round colour, and no
   `pace_state` (D-19, unchanged).
9. When the pace bonus changes an escort win's rank, the existing rank-cause note fires
   unchanged (D-27).
10. A joined-spirit escort win and a non-joining-spirit escort win both carry a valid
    `pace_ratio` computed from the same formula (§1, §4). No escort fight silently skips the pace
    term, or falls back to `par_rounds` 0.0, because of the join roll.

---

## 10. What does not change

| Item | Status |
|---|---|
| GUIDE_SPIRIT protect variant | Stays a no-pace, timer mode (D-06). This proposal does not touch it. |
| COMBAT, PURIFY_SHRINE, RECOVER, PURSUE par formulas | Unchanged. |
| `pace_full_ratio` 1.10, `pace_zero_ratio` 1.60, `pace_bonus_pct` 0.05 (D-15) | Unchanged. Escort joins the same shared curve; it does not get its own. |
| Gap A ≤ 50 pp, Gap B ≤ 90 pp (D-16) | Unchanged as limits. Escort is now included in what they measure. |
| Colour rules (D-12, D-25) and result-screen rules (D-13, D-27) | Unchanged. Escort reuses the existing three-state legend and rank-cause note. |
| The escort/protect roll and the join roll (`EncounterObjectiveSpawnService`) | Unchanged. This proposal reads their existing output; it does not touch RNG draw order. |
| D-23 (ally and joined-spirit kills excluded from rank) | Unchanged. Escort pace is a separate, additive term; it does not interact with the kill-term rules. |

---

## Open items for Jeff

- Whether to approve the §1 formula (spirit's own capacity, not party mean) as the escort par.
- Whether to approve one par for both win reasons (§3), accepting the same kind of trade-off D-08
  accepted for PURSUE, without yet knowing the size of the gap.
- Whether to approve using the same formula for joined and non-joining spirits (§4), with the
  reporting split as the safeguard, rather than a separate formula per join state.
- Whether the measurement plan (§8) is the right scope before values are called final, given how
  small the current sample is.
