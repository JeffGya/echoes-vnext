# Escort pace — measurement

**Status: MEASURED — decided in decisions.md D-32, D-33.**

**Owner:** mid-game-designer. **Story:** pace-reward, extension under decisions.md D-31.
**Input:** `docs/stories/pace-reward/escort-design.md` §8 (PROPOSED, not approved).
**Purpose:** data for Jeff. This document sets no value and approves no formula.

---

## 1. What ran

| Item | Value |
|---|---|
| Mode | GUIDE_SPIRIT, `dev_guide_mode = "escort"` forced (no seeded 50/50 coin-flip) |
| Join roll | Forced both ways: `dev_guide_joins = "join"` and `"nojoin"`, as separate groups |
| Seeds per cell | 25 (seeds 0 to 24) |
| Realms | realm.01, realm.02 (merged in each cell; see note below) |
| Boards | old (12×12 base) and new (18×18 base) |
| Cells | 2 join states × 2 boards = 4 cells, each n = 50 fights (25 seeds × 2 realms) |
| Total fights | 200 |
| Total wins | 137 |
| Stage | stage.0. Stage base reward 60 Ase in every fight (max pace bonus 3 Ase, matches tuning.md §4.5) |
| Round limit | 30 rounds, unchanged from every other probe |
| Errors | 0 `PROBE_ERR` or script errors across all 8 log files |

Realms are merged per cell, not reported as separate rows, because the story's other probes
(tuning.md §4.5) also pool realms and the two realms showed no separable pattern in this data.

**Validation (seed −1):** the escort probe copy was run at seed −1 with the pre-existing fixture
settings (`guide_mode = "protect"`, `nojoin`) to check against the old probe
(`probe/pace_probe3.gd`). Every field matched exactly (`ally_killed`, `ase`, `cr_reason`,
`d_obj`, `duration_turns`, `guide_mode`, `pace_bonus`, `pace_state`, `par_rounds`, `rank`,
`reached`, `reason`, `total_echoes`, `total_enemies`, `victory`, `window_turns`, and more) **except**
`d_mean`/`d_min` (46 vs 38) and `round_ended` (9 vs 6). **Explanation:** `EchoFactory.generate`
is seeded from the fight's `seed_tag` string, and the copy uses a different fixture tag
(`fp_escort_nojoin` vs the old probe's `fp_guide_spirit`) to keep the two probes' logs
distinguishable. A different tag draws a different roster, which moves enemy placement and combat
length. This is expected, not a probe defect: every field that does not depend on roster
composition matched byte-for-byte.

### 1a. Fights that hit the 30-round limit, or ended without a win reason

| Join | Board | Fights | Wins | Hit 30-round cap (unresolved) | Ordinary defeat (resolved, no win-reason) | Defeat: spirit killed |
|---|---|---|---|---|---|---|
| nojoin | old | 50 | 33 | 13 (26%) | 0 | 4 |
| nojoin | new | 50 | 27 | 16 (32%) | 2 | 5 |
| join | old | 50 | 44 | 5 (10%) | 1 | 0 |
| join | new | 50 | 33 | 12 (24%) | 5 | 0 |

"Hit 30-round cap" means the probe's own round-driver never observed `combat_over` become true in
30 rounds: no result, no reason, `round_ended` reads 0 because no `flow.resolve` snapshot was ever
published. This is a real and frequent outcome for escort, not a probe artifact: 46 of 200 fights
(23%) never resolved in 30 rounds. It is most common on the new (18×18) board, for both join
states. **Flagged for §4 findings below**, not fixed here: this is a scope boundary (§0 of the
brief says measure only), but it is large enough that Jeff should see it before any curve number
is called final.

---

## 2. Result tables

`pace_ratio = round_ended / par`, computed offline in Python from the raw probe rows, using the
decided curve (`pace_full_ratio` 1.10, `pace_zero_ratio` 1.60, `pace_bonus_pct` 0.05, D-15).
`pace_state` follows D-22 (from the Ase paid, both directions). All rows below are victory-only,
n = the fights with both a valid par and a resolved win.

### 2a. Par A (proposed, escort-design.md §1): `max(1, spirit→destination / spirit capacity)`, no hold

| Join | Board | n (wins) | Median ratio | p10 | p90 | Full % | Partial % | None % | Mean bonus (Ase) |
|---|---|---|---|---|---|---|---|---|---|
| nojoin | old | 33 | 1.29 | 0.62 | 2.29 | 39.4 | 27.3 | 33.3 | 1.67 |
| nojoin | new | 27 | 1.27 | 0.29 | 2.11 | 48.1 | 29.6 | 22.2 | 1.78 |
| join | old | 44 | 1.00 | 0.33 | 1.90 | 70.5 | 4.5 | 25.0 | 2.18 |
| join | new | 33 | 1.17 | 0.57 | 2.44 | 51.5 | 0.0 | 48.5 | 1.55 |

By win reason (Par A):

| Join | Board | `spirit_escorted` n / median | `all_enemies_defeated` n / median |
|---|---|---|---|
| nojoin | old | 17 / 1.53 | 16 / 0.86 |
| nojoin | new | 12 / 1.46 | 15 / 0.77 |
| join | old | 0 / — | 44 / 1.00 |
| join | new | 0 / — | 33 / 1.17 |

### 2b. Par B: COMBAT-style party travel par — `max(1, mean Echo→nearest enemy / party mean capacity)`

| Join | Board | n (wins) | Median ratio | p10 | p90 | Full % | Partial % | None % | Mean bonus (Ase) |
|---|---|---|---|---|---|---|---|---|---|
| nojoin | old | 33 | 1.40 | 0.76 | 3.33 | 42.4 | 12.1 | 45.5 | 1.42 |
| nojoin | new | 27 | 1.30 | 0.63 | 1.73 | 40.7 | 33.3 | 25.9 | 1.70 |
| join | old | 44 | 1.30 | 0.78 | 2.22 | 43.2 | 31.8 | 25.0 | 1.75 |
| join | new | 33 | 1.20 | 0.66 | 2.14 | 48.5 | 18.2 | 33.3 | 1.76 |

By win reason (Par B):

| Join | Board | `spirit_escorted` n / median | `all_enemies_defeated` n / median |
|---|---|---|---|
| nojoin | old | 17 / 1.12 | 16 / 1.71 |
| nojoin | new | 12 / 0.81 | 15 / 1.47 |
| join | old | 0 / — | 44 / 1.30 |
| join | new | 0 / — | 33 / 1.20 |

---

## 3. Gap A and Gap B

Limits (decisions.md D-16, ANSWERS.md #63): Gap A ≤ 50 pp, Gap B ≤ 90 pp. Gap B uses each other
mode's full share on the **same board**, read from tuning.md §4.5 (COMBAT, PURIFY_SHRINE, RECOVER,
PURSUE).

### 3a. Gap A — old board vs new board, full share, by join group

| Par | nojoin gap | join gap | Verdict |
|---|---|---|---|
| Par A | 8.8 pp | 18.9 pp | **PASS** (both ≤ 50) |
| Par B | 1.7 pp | 5.3 pp | **PASS** (both ≤ 50) |

### 3b. Gap B — escort vs each of COMBAT, PURIFY_SHRINE, RECOVER, PURSUE, same board

Largest gap per (join, board) cell:

| Par | Join | Board | Widest pairing | Gap | Verdict |
|---|---|---|---|---|---|
| Par A | join | old | escort 70.5% vs PURIFY_SHRINE 5% | 65.5 pp | PASS |
| Par A | nojoin | old | escort 39.4% vs RECOVER 92% | 52.6 pp | PASS |
| Par A | join | old | escort 70.5% vs COMBAT 27% | 43.5 pp | PASS |
| Par A | nojoin | new | escort 48.1% vs RECOVER 83% | 34.9 pp | PASS |
| Par B | nojoin | old | escort 42.4% vs RECOVER 92% | 49.6 pp | PASS |
| Par B | join | old | escort 43.2% vs RECOVER 92% | 48.8 pp | PASS |

**Maximum measured Gap B across every (par, join, board) cell: 65.5 pp (Par A, join, old board, vs
PURIFY_SHRINE).** This is under the 90 pp limit but is the second-largest Gap B measured in this
story so far (tuning.md §4.0's own maximum was 87.1 pp, RECOVER vs PURIFY_SHRINE). Escort does not
break the limit, but it is not a small margin either.

**Verdict: Gap A and Gap B both PASS, for both pars, for both join groups.**

| Metric | Par A max | Par B max | Limit |
|---|---|---|---|
| Gap A | 18.9 pp | 5.3 pp | ≤ 50 pp |
| Gap B | 65.5 pp | 49.6 pp | ≤ 90 pp |

---

## 4. Plain findings

1. **Does the 1.10 / 1.60 / 5% curve fit escort under Par A?** It passes the two drift-guard
   limits, but escort's own full-share spreads more than any already-accepted mode: 39.4% to
   70.5% across the four (join × board) cells, a 31-point internal spread before Gap A/B are even
   computed. The join roll moves the number more than the board does (Gap A 18.9 pp from the join
   roll's own old-board value vs a much smaller within-group board effect).
2. **Does it fit under Par B?** Par B is steadier: full share sits in a narrow 40.7% to 48.5% band
   across all four cells. Gap A under Par B is small (1.7 to 5.3 pp). Par B, which ignores the
   spirit's own capacity and uses the party's travel par instead, produces a more stable number
   than Par A across join states and boards, on this data.
3. **One par for both win reasons (open point 2):** the two reasons land far apart under either
   par. Under Par A, `spirit_escorted` wins score worse (median ratio ≈1.5, slower than par) than
   `all_enemies_defeated` wins (median ≈0.8, faster than par) — a gap of about 0.7, roughly twice
   the size of PURSUE's own accepted kill-vs-contain gap (≈0.35, design.md §3). Under Par B the
   gap is similar size but the direction flips (`spirit_escorted` scores better than
   `all_enemies_defeated`). Either par produces a real split between the two win reasons; this
   data does not by itself say the split is too large to accept, the same way PURSUE's was
   accepted (D-08).
4. **Joined spirit (open point 3):** across 77 joined-spirit wins (44 old board, 33 new board),
   **zero** ended in `spirit_escorted`. Every joined-spirit win was `all_enemies_defeated`. This
   confirms escort-design.md §4's flag directly: a joined spirit's arrival at the destination is
   not just noisier than a non-joining spirit's, it did not happen once in this sample. Whatever
   par formula is used for a joined spirit's pace, it is scoring a win that never depended on
   reaching the destination.
5. **Blocking slack (open point 4):** for non-joining spirits, a win's rounds with no spirit
   movement (spirit alive, escort not yet complete, end-of-round cell unchanged from the round
   before) are common and large: median 7 rounds on both boards, and a median **35% of a win's
   total rounds on the old board, 50% on the new board**. No win in the sample had zero blocking
   rounds. This is a large share of a fight's length spent with the spirit stationary while still
   in play. It does not by itself say the "no extra slack" recommendation (escort-design.md §5) is
   wrong — the shared curve already absorbs slack for every mode — but the size of it here is
   larger than a single blocked step per fight, which is what §5's reasoning pictured.
6. **The 30-round cap (§1a):** 23% of all fights (46 of 200) never resolved in 30 rounds, rising to
   32% on the new board for a non-joining spirit. This was not measured for the other four modes
   at this rate (design.md §9's probes did not report an equivalent share). A non-joining spirit's
   fixed capacity-1 pace on an 18×18 board, combined with blocking (finding 5), is the likely
   mechanism, but this document does not diagnose it further: that is outside "measure only."
   Flagged because a curve fit on the wins alone silently drops the slowest quarter of fights.

---

## 5. Data for the four open items (escort-design.md §8, §9's open list)

Jeff decides; this section lists options with numbers, not a recommendation.

### 5.1 Same curve or escort's own curve

| Option | What the data shows |
|---|---|
| Same shared curve (1.10 / 1.60 / 5%), Par A | Passes Gap A (≤18.9 pp) and Gap B (≤65.5 pp). Full share spans 39–71% across join/board cells — inside the limits, not close to the other modes' own spread. |
| Same shared curve, Par B | Passes Gap A (≤5.3 pp) and Gap B (≤49.6 pp), with a visibly steadier full share (41–49%) than Par A. |
| A separate escort curve | Not measured. Would require its own full/zero/pct triple and its own gap check; no data collected against a hypothetical alternate curve. |

### 5.2 One par for both win reasons, or a per-reason par

| Option | What the data shows |
|---|---|
| One par, either formula (as proposed, §3 of escort-design.md) | Median ratio gap between `spirit_escorted` and `all_enemies_defeated` is ≈0.6–0.7 under either par (§4 finding 3), roughly double PURSUE's accepted gap. |
| Per-reason par | Not measured. Would need a second par formula defined and re-run; escort-design.md §3 argues against this as a second hidden calibration. |

### 5.3 Joined spirit: same formula, or its own rule

| Option | What the data shows |
|---|---|
| Same formula as non-joining (as proposed, §4 of escort-design.md) | 0 of 77 joined wins were `spirit_escorted`; all were `all_enemies_defeated`. A joined spirit's pace ratio under either par is scoring a win unrelated to the destination it never reached. |
| Joined spirit gets no pace term (like PROTECT) | Not measured directly, but the data supports the premise: a joined spirit practically never wins by arrival, so an escort-arrival par may not describe what actually happened in a joined-spirit win. |
| Joined spirit uses `all_enemies_defeated`-only par, mirroring PURSUE's contain-vs-kill split | Not measured as a separate formula; the existing `all_enemies_defeated` rows (§2a, §2b, by-reason tables) are the closest available data, since every joined win is already that reason. |

### 5.4 Blocking slack

| Option | What the data shows |
|---|---|
| No extra slack (as proposed, §5 of escort-design.md) | Median blocking share of a win's rounds is 35% (old board) to 50% (new board) (§4 finding 5). The shared curve absorbs this today without failing Gap A/B (§3), but the absorbed amount is large. |
| A per-round slack term sized to observed blocking | Not measured as a modified formula; only the raw blocking-round counts above are available. |

---

## 6. Option E re-measure (2026-09-26, orchestrator)

The spirit waits until an Echo stands next to it, so a par must also count the party's walk to the
spirit. The same 100 non-joined fights ran again (identical outcomes) with one extra field: the
Echo-to-spirit distance at fight start.

- E-min: `max(1, max(0, nearest Echo→spirit − 1) / party mean range + spirit→destination / spirit range)`.
- E-mean: the same with the mean Echo distance.

| Par | Board | Escort wins median | Kill wins median | Full share (ratio ≤ 1.10) | `pace_state` full / partial / none | Mean bonus (Ase) | Gap B |
|---|---|---|---|---|---|---|---|
| A | old | 1.53 | 0.86 | 36% | 39 / 27 / 33 | 1.67 | 56 |
| A | new | 1.46 | 0.77 | 44% | 48 / 30 / 22 | 1.78 | 39 |
| C (max of A, B) | old | 1.05 | 0.84 | 64% | 73 / 12 / 15 | 2.42 | 59 |
| C (max of A, B) | new | 0.81 | 0.77 | 74% | 81 / 11 / 7 | 2.63 | 24 |
| **E-min** | old | 0.97 | 0.62 | 88% | 91 / 6 / 3 | 2.82 | 83 |
| **E-min** | new | 0.98 | 0.50 | 93% | 100 / 0 / 0 | 3.00 | 43 |
| E-mean | old | 0.96 | 0.59 | 91% | 91 / 6 / 3 | 2.85 | 86 |
| E-mean | new | 0.97 | 0.49 | 93% | 100 / 0 / 0 | 3.00 | 43 |

Gap A: A 8, C 10, E-min 5, E-mean 2 pp. All options pass Gap A (≤ 50) and Gap B (≤ 90).
**Decided: E-min (decisions.md D-33).** Escort wins land on par; nearly every escort win earns the full bonus.

## OPEN — questions and assumptions (mid-game-designer)

**ASSUMED:** Realms merged per cell rather than reported separately, following tuning.md §4.5's
own precedent, since a per-realm split was not requested and the two realms did not diverge
visibly in this data.

**ASSUMED:** "Rounds the spirit did not move" (open point 4) is measured as end-of-round cell
unchanged from the previous round, for a non-joining spirit only, while the spirit had not yet
reached its destination. This is an approximation: the probe's per-round position log has no
per-round "is this actor dead" flag, so a spirit's death mid-fight cannot be excluded from the
count if it happened. In this sample every counted fight was a win with the spirit presumably
alive throughout (the only alternative end state, `all_enemies_defeated`, does not require the
spirit's death), so this should not have distorted the counts, but it was not directly checked
actor-by-actor.

**ASSUMED:** Par B's "party" is every actor with `faction == "echo"` and not `is_ally`, matching
the `caps` list every other probe in this story already builds the same way (`probe/pace_probe3.gd`
line 101-104). A joined spirit (`faction == "echo"`, `is_spirit == true`) is excluded from this
list by the existing `caps` construction, so Par B's party mean never includes the joined spirit
itself, only the five roster Echoes.

**BLOCKED:** none. Every number in this document was read from a fresh probe run against the
current `HEAD` (`a514a92`), not carried over from an older log.

**FLAGGED, not a question:** the 30-round-cap share (§1a, §4 finding 6) is large enough (up to 32%
on the new board) that it may be worth its own look before escort pace ships, independent of which
curve or par Jeff picks. This is a finding to route to sr-game-designer or mechanics-developer, not
a question this document is positioned to answer.
