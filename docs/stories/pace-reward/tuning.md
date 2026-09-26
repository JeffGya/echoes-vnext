# Pace Bonus — Tuning Values

**Status:** DECIDED. Values set by Jeff, decisions.md D-15 to D-16, 2026-09-25.
**Depends on:** `docs/stories/pace-reward/design.md` (APPROVED, decisions.md D-14).
**Scope:** values only. No code, no config edits, no Godot, no commits.

---

## 0. Decided values (decisions.md D-15 to D-16)

Jeff did not pick the Generous set this document recommended. Jeff picked the Strict curve's
`pace_full_ratio` and `pace_zero_ratio`, with a lower `pace_bonus_pct`.

**D-15. Values:**

| Value | Decided |
|---|---|
| `pace_full_ratio` | 1.10 |
| `pace_zero_ratio` | 1.60 |
| `pace_bonus_pct` | 0.05 |

Reason: Ase flows too much today. The pace bonus must not be generous. Measured effect: up to 3
Ase per win, 2.31 Ase average per pace-mode win. Today's speed bonus averages 3.6 Ase.

**D-16. Gap A and Gap B, as drift guards, not equality goals:**

| Limit | Decided |
|---|---|
| Gap A | ≤ 50 percentage points |
| Gap B | ≤ 90 percentage points |

These are drift guards. They do not promise equal modes. Equal modes on stage 0 is not a goal of
this set.

The Generous set (§3, §4.1) is **not chosen**. Its data stays below for reference only.

---

## 1. Overview

The design spec sets a pace formula and a linear bonus curve. Phase 2 sets the curve's three
numbers. This document first proposed three candidate sets, then records Jeff's decision (§0).
Each set uses one global value per setting, as ANSWERS.md #63 requires. Values come from the
stage-0 probe data: 336 fights, 7 modes, 2 realms, 2 board sizes, 12 seeds each. Only pace-mode
wins count: COMBAT, PURIFY_SHRINE, RECOVER, PURSUE. Gap A and Gap B, the two acceptance limits
design spec §9 left for phase 2, are now decided (decisions.md D-16, §0, §5).

---

## 2. User stories

- As a player, I want a full pace bonus for a normal, unhurried win, so that I am not punished for
  playing at a natural pace.
- As a player, I want the pace bonus to feel similar across pace modes, so that no mode feels
  stingier than another for the same effort.
- As a player, I want the pace bonus to feel similar across board sizes, so that a board-size
  change does not silently change my reward.
- As a designer, I want the pace bonus to pay more than the old flat bonus on average, so that the
  new curve reads as an upgrade, not a cut.

---

## 3. Candidate value sets

| Set | `pace_full_ratio` | `pace_zero_ratio` | `pace_bonus_pct` | Chosen |
|---|---|---|---|---|
| Generous | 1.50 | 2.00 | 0.15 | No |
| Middle | 1.30 | 1.80 | 0.15 | No |
| Strict (curve) | 1.10 | 1.60 | 0.12 | No, curve only |
| **Decided (decisions.md D-15)** | **1.10** | **1.60** | **0.05** | **Yes** |

This document originally recommended Generous. Jeff did not pick it. Jeff picked the Strict
curve's `pace_full_ratio` and `pace_zero_ratio`, with `pace_bonus_pct` lowered from 0.12 to 0.05
(§0). Reasons for the original recommendation, and for Middle and Strict, stay below for record
and reference only.

**Original reasoning for Generous (not chosen):**

1. It gave the smallest Gap A and Gap B of the three original sets (§4, §5). The design's own goal
   was that the four pace modes feel similarly generous (design.md §9-§10).
2. Its full-bonus shares sat between 73% and 100% across all four modes and both boards.
3. Its mean pace bonus (8.40 Ase) was higher than the old flat mean (3.62 Ase).

Middle and Strict were included because they cost less Ase per win. Both carried a larger gap
between modes and boards than Generous, which the design spec flags as a risk (design.md §9-§10).
Jeff's decision (§0) accepts this larger gap as a drift guard, not a target to close.

---

## 4. Measured effect — full / partial / none share and mean bonus Ase

Base reward is 60 Ase in the probe data (stage 0). All numbers below use victory-only fights.

### 4.0 Decided set (`pace_full_ratio` 1.10, `pace_zero_ratio` 1.60, `pace_bonus_pct` 0.05)

Full-bonus share, old board / new board:

| Mode | Old-board full share | New-board full share |
|---|---|---|
| COMBAT | 27% | 52% |
| PURIFY_SHRINE | 5% | 53% |
| RECOVER | 92% | 83% |
| PURSUE | 60% | 67% |

Measured Gap A (largest old-vs-new gap, any one mode): **48.4 percentage points** (PURIFY_SHRINE).
Measured Gap B (largest gap between two modes, same board): **87.1 percentage points** (RECOVER
92% vs PURIFY_SHRINE 5%, old board). Both pass the decided limits (§0): Gap A 48.4 ≤ 50, Gap B
87.1 ≤ 90.

Mean pace bonus: **2.31 Ase** per pace-mode win. A win pays at most 3 Ase (0.05 × 60, rounded).
This is close to, and slightly below, today's speed bonus average of 3.6 Ase.

### 4.1 Generous, not chosen (`pace_full_ratio` 1.50, `pace_zero_ratio` 2.00, `pace_bonus_pct` 0.15)

| Mode | Board | n | Full | Partial | None | Mean bonus (Ase) |
|---|---|---|---|---|---|---|
| COMBAT | old | 22 | 86% | 9% | 5% | 8.49 |
| COMBAT | new | 21 | 86% | 5% | 10% | 8.06 |
| PURIFY_SHRINE | old | 22 | 73% | 18% | 9% | 7.76 |
| PURIFY_SHRINE | new | 17 | 76% | 18% | 6% | 8.07 |
| RECOVER | old | 24 | 100% | 0% | 0% | 9.00 |
| RECOVER | new | 24 | 88% | 8% | 4% | 8.36 |
| PURSUE | old | 10 | 100% | 0% | 0% | 9.00 |
| PURSUE | new | 9 | 89% | 11% | 0% | 8.98 |

Overall mean pace bonus: **8.40 Ase** per pace-mode win.

### 4.2 Middle, not chosen (`pace_full_ratio` 1.30, `pace_zero_ratio` 1.80, `pace_bonus_pct` 0.15)

| Mode | Board | n | Full | Partial | None | Mean bonus (Ase) |
|---|---|---|---|---|---|---|
| COMBAT | old | 22 | 68% | 27% | 5% | 7.91 |
| COMBAT | new | 21 | 86% | 5% | 10% | 7.89 |
| PURIFY_SHRINE | old | 22 | 45% | 45% | 9% | 6.40 |
| PURIFY_SHRINE | new | 17 | 71% | 24% | 6% | 7.34 |
| RECOVER | old | 24 | 96% | 4% | 0% | 8.91 |
| RECOVER | new | 24 | 83% | 12% | 4% | 8.02 |
| PURSUE | old | 10 | 90% | 10% | 0% | 8.73 |
| PURSUE | new | 9 | 78% | 22% | 0% | 8.34 |

Overall mean pace bonus: **7.88 Ase** per pace-mode win.

### 4.3 Strict curve, not chosen (`pace_full_ratio` 1.10, `pace_zero_ratio` 1.60, `pace_bonus_pct` 0.12)

Same shares as the decided set (§4.0); only `pace_bonus_pct` differs (0.12 here, 0.05 decided).

| Mode | Board | n | Full | Partial | None | Mean bonus (Ase) |
|---|---|---|---|---|---|---|
| COMBAT | old | 22 | 27% | 64% | 9% | 5.28 |
| COMBAT | new | 21 | 52% | 33% | 14% | 5.62 |
| PURIFY_SHRINE | old | 22 | 5% | 73% | 23% | 3.49 |
| PURIFY_SHRINE | new | 17 | 53% | 24% | 24% | 5.07 |
| RECOVER | old | 24 | 92% | 8% | 0% | 6.95 |
| RECOVER | new | 24 | 83% | 4% | 12% | 6.16 |
| PURSUE | old | 10 | 60% | 40% | 0% | 6.19 |
| PURSUE | new | 9 | 67% | 33% | 0% | 5.87 |

Overall mean pace bonus: **5.55 Ase** per pace-mode win.

### 4.4 Economy comparison — mean Ase of a pace-mode win, all sets

| System | Mean pace-bonus Ase per win (n=149) |
|---|---|
| Old flat bonus (0.15 × 60, if `round_ended < 5`) | 3.62 |
| **Decided (pct 0.05)** | **2.31** |
| Generous, not chosen | 8.40 |
| Middle, not chosen | 7.88 |
| Strict curve, pct 0.12, not chosen | 5.55 |

The decided set pays less than the old flat bonus on average. This matches Jeff's reason for
choosing it (§0): Ase flows too much today, so the pace bonus must not be generous.

---


### 4.5 Re-measured on the implemented code (2026-09-25, commit `f8976f5`)

The same 336 fights (7 modes × 12 seeds × realm.01 and realm.02 × old and new board, stage 0)
ran again on the merged code. This time the probe read the real game values (`pace_bonus_awarded`,
`pace_state`, `par_rounds`), not a model. Stage base is 60 Ase in every pace fight, so the maximum
pace bonus is 3 Ase.

| Board | Mode | Wins | Ratio ≤ 1.10 | `pace_state` full / partial / none | Mean bonus |
|---|---|---|---|---|---|
| Old | COMBAT | 22 | 27% | 59% / 18% / 23% | 2.14 |
| Old | PURIFY_SHRINE | 22 | 5% | 23% / 50% / 27% | 1.41 |
| Old | RECOVER | 24 | 92% | 92% / 8% / 0% | 2.88 |
| Old | PURSUE | 10 | 60% | 60% / 40% / 0% | 2.50 |
| New | COMBAT | 21 | 52% | 62% / 24% / 14% | 2.33 |
| New | PURIFY_SHRINE | 16 | 50% | 62% / 19% / 19% | 2.19 |
| New | RECOVER | 24 | 83% | 83% / 8% / 8% | 2.67 |
| New | PURSUE | 9 | 67% | 67% / 33% / 0% | 2.44 |

Results:
1. **Mean pace bonus: 2.31 Ase** per pace-mode win. This is the same as §4.0.
2. **Gap A** (ratio ≤ 1.10 metric, as in §5): largest 45 pp (PURIFY_SHRINE, 5% vs 50%). PASS (≤ 50).
3. **Gap B** (same metric): largest 87 pp (old board, RECOVER 92% vs PURIFY_SHRINE 5%). PASS (≤ 90).
4. **`pace_state` full is more common than "ratio ≤ 1.10".** D-22 sets `full` from the Ase paid.
   With a 3 Ase maximum, a fraction of 5/6 (about 0.83) or more rounds to 3 Ase, so it shows `full`. On the
   `pace_state` metric, Gap A is 39 pp and Gap B is 69 pp. Both are inside the limits.
5. No no-pace fight and no defeat carries `pace_state`.
6. Every win in a pace mode is rank S. The rank spread problem stays open (follow-ups.md #1).
7. 33 of 336 fights ended in a different round or with a different result than the §4.0 probe.
   The cause is the merged `main` code (V2-COMBAT-003.5 Phases 4 to 6), not the pace code: no pace
   commit moved a ROUNDS fingerprint. The §4.0 numbers still hold within those changes.

### 4.6 Reached enemies re-measured on the implemented code (design.md §9 criterion 5)

Same 336-fight probe as §4.5. `reached` is the size of `combat_state["reached_enemy_ids"]` at fight
end, read from the game. "Contact" is the probe's own independent check (an enemy ends a round
within Chebyshev 1 of an Echo). The two numbers agree in every mode and board.

| Mode | Board | Fights | Enemies placed | Reached | Contact (probe) | Ally/spirit kills | Win ranks |
|---|---|---|---|---|---|---|---|
| PROTECT | Old | 24 | 24 | 21 (88%) | 21 | 0 | S 24 |
| PROTECT | New | 24 | 24 | 20 (83%) | 20 | 0 | S 24 |
| ENDURE | Old | 24 | 144 | 58 (40%) | 58 | 0 | S 20, A 4 |
| ENDURE | New | 24 | 144 | 17 (12%) | 17 | 0 | S 24 |
| GUIDE_SPIRIT | Old | 24 | 24 | 13 (54%) | 13 | 1 | S 15 |
| GUIDE_SPIRIT | New | 24 | 24 | 8 (33%) | 8 | 3 | S 16 |
| RECOVER | Old | 24 | 49 | 11 (22%) | 11 | 0 | S 24 |
| RECOVER | New | 24 | 57 | 7 (12%) | 7 | 0 | S 24 |
| PURSUE | Old | 24 | 24 | 11 (46%) | 11 | 0 | S 10 |
| PURSUE | New | 24 | 24 | 9 (38%) | 9 | 0 | S 9 |

Results:
1. The implemented reach tracking matches the probe's independent contact count in all 10 rows.
2. On the new board, most placed enemies never reach the party in ENDURE (12%) and RECOVER (12%).
   Without the reached-enemy ceiling, those enemies would cap the rank below S (the §5 problem).
3. Every win in these modes is rank S, except 4 ENDURE wins on the old board (rank A). The rank
   spread problem stays open (follow-ups.md #1).
4. Ally or spirit kills happen only in GUIDE_SPIRIT (4 in 48 fights). D-23 takes them out of both
   sides of the rank.

## 5. Acceptance criteria (design.md §9, filled in for the decided set)

Criterion 1a and 1b, restated with the decided set's measured gaps and Jeff's limits (ANSWERS.md
D-16). Gap A compares one mode across the two board sizes. Gap B compares two modes on the **same**
board. A combined-board Gap B, used in an earlier draft of this document, hides the difference
that shows up on one board alone; it is not used here.

**Gap A — old-board vs new-board full-bonus share, per pace mode:**

| Mode | Old-board full share | New-board full share | Gap |
|---|---|---|---|
| COMBAT | 27% | 52% | 25 pp |
| PURIFY_SHRINE | 5% | 53% | 48 pp |
| RECOVER | 92% | 83% | 9 pp |
| PURSUE | 60% | 67% | 7 pp |

Measured maximum: **48.4 percentage points** (PURIFY_SHRINE).

**Decided Gap A limit (decisions.md D-16): ≤ 50 percentage points.** PASS: 48.4 ≤ 50.

**Gap B — full-bonus share between any two pace modes, on the same board:**

| Board | Widest pair | Gap |
|---|---|---|
| Old | RECOVER 92% vs PURIFY_SHRINE 5% | 87 pp |
| New | COMBAT 52% vs RECOVER 83% | 31 pp |

Measured maximum: **87.1 percentage points** (old board, RECOVER vs PURIFY_SHRINE).

**Decided Gap B limit (decisions.md D-16): ≤ 90 percentage points.** PASS: 87.1 ≤ 90.

**Criterion 1 (a, b): PASS** for the decided set, against Jeff's limits. Both limits are drift
guards, not equality goals (§0). Modes are not close to equal on stage 0 under this set,
especially PURIFY_SHRINE and RECOVER on the old board. This is accepted, not hidden.

**Criteria 2, 3 (RECOVER and PURSUE par stability):** Confirmed by the control-check medians in
§9 of design.md; unaffected by the curve values chosen here.

**Criteria 4-9** (rank ceiling, reached-enemy tracking, screen fields, rank-cause note): unaffected
by curve value choice. They depend on implementation, not on `pace_full_ratio`,
`pace_zero_ratio`, or `pace_bonus_pct`.

---

## 6. Limits

- Measured on stage 0 only. Later stages are unmeasured.
- Measured on Standing-1 parties only. Other party sizes are unmeasured.
- 12 seeds per mode/board/realm cell. Small-n cells (PURSUE, n=9-10 per board) carry wider
  uncertainty than COMBAT or RECOVER (n=21-24 per board).
- PURIFY_SHRINE's old-board pace is systematically slower than the other three modes (design.md
  §9). No curve value removes this; it only changes how much the gap costs in Ase.
