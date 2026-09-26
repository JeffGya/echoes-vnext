# Pace bonus story — decisions

Story-specific decisions for the pace bonus story. Project-wide decisions stay in `ANSWERS.md`
(this story added ANSWERS.md #63 and #64). Each entry: the question, Jeff's answer, source, date.

| # | Slug | Topic | Date |
|---|---|---|---|
| D-01 | speed-bonus-stories-merged | The PURSUE-payout review and the speed_bonus_threshold/board-size check become one story | 2026-09-25 |
| D-02 | pace-reward-d-plus-e | Keep a pace reward as a gradient against each mode's own reference (option D+E), designed before it is built | 2026-09-25 |
| D-03 | endure-kill-reach-in-scope | The rank counts only enemies that reached the party; this kill-term fix is part of the pace-reward story | 2026-09-25 |
| D-04 | rank-meaning-separate-story | "What should combat rank measure" is a separate follow-up story | 2026-09-25 |
| D-05 | speed-bonus-keys-removed | `speed_bonus_threshold` and `speed_bonus_pct` are removed under the V2-PROG-012 exception | 2026-09-25 |
| D-06 | no-pace-modes-show-nothing | Modes without a pace term show no pace line during the fight | 2026-09-25 |
| D-07 | pace-par-per-win-type | The pace par is defined per win type so every pace-carrying mode lands on a comparable scale; no hidden per-mode calibration | 2026-09-25 |
| D-08 | pursue-hold-par | Every PURSUE fight uses the hold par (travel + contain_rounds − 1), including fights won by a kill | 2026-09-25 |
| D-09 | recover-par-nearest-echo | RECOVER par = nearest Echo's walk to the relic + (hold_rounds − 1) | 2026-09-25 |
| D-10 | escort-no-pace-until-combat-004 | GUIDE_SPIRIT escort has no pace term until V2-COMBAT-004 makes the escort win reachable | 2026-09-25 |
| D-11 | pace-player-rule-copy | Player rule copy: "Stay on pace, and you earn the pace bonus." | 2026-09-25 |
| D-12 | pace-shown-by-colour-only | No pace text during the fight; the existing round counter / objective progress shows pace by colour (green / middle colour / red), in the fight and on the result screen | 2026-09-25 |
| D-13 | pace-result-screen-text | The result screen keeps a "Pace bonus" row in the existing reward list (also at 0) and a short rank-cause text next to the rank letter | 2026-09-25 |
| D-14 | pace-design-spec-approved | The pace bonus design spec `docs/stories/pace-reward/design.md` is approved; phase 2 (values) may start | 2026-09-25 |
| D-15 | pace-values-strict | `pace_full_ratio` 1.1, `pace_zero_ratio` 1.6, `pace_bonus_pct` 0.05 | 2026-09-25 |
| D-16 | pace-gaps-drift-guard | Acceptance limits Gap A 50 and Gap B 90 percentage points guard against drift; equal modes on stage 0 is not a goal | 2026-09-25 |
| D-17 | pace-colour-follows-ase | `pace_state` is `partial` only when the partial bonus pays at least 1 Ase; a bonus that rounds to 0 is `none` | 2026-09-25 |
| D-18 | intro-trial-no-pace | The keeper-intro trial is a no-pace fight: normal colour, no pace data | 2026-09-25 |
| D-19 | defeat-shows-no-pace | A defeat shows nothing about pace: no row, normal colour, no `pace_state` | 2026-09-25 |
| D-20 | pace-ratio-not-in-snapshot | `pace_ratio` stays out of the snapshot data (#59); the screen uses only `pace_state` | 2026-09-25 |
| D-21 | pace-one-stage-base | The live colour and the result pace bonus use one stage base, captured once at fight start | 2026-09-25 |
| D-22 | pace-state-from-ase-paid | `pace_state` is set from the Ase paid: full = maximum, partial = between 0 and maximum, none = 0 | 2026-09-25 |
| D-23 | reached-enemies-and-ally-kills | A party Echo kill marks the enemy reached; only living enemies become reached; ally and spirit kills pay Ase but leave both sides of the rank | 2026-09-25 |
| D-24 | hazard-kills-deferred | How a hazard kill counts for the rank is decided by V2-COMBAT-004 (slice 004B), not here | 2026-09-25 |
| D-25 | pace-colours-approved | The six pace colours (dark HUD and light result card) are approved | 2026-09-25 |
| D-26 | result-screen-findings-to-combat-004 | The Rounds-line position and two other result-screen findings go to V2-COMBAT-004 (004D) | 2026-09-25 |
| D-27 | rank-cause-note-copy | The rank-cause note reads "The party's effort earned this rank" | 2026-09-25 |
| D-28 | pace-polish-scope | D-12 allows an animated colour change; build the colour blend, the drop brightening and the muted +0 row; leave the note delay and the Pace-row colour | 2026-09-25 |
| D-29 | zero-row-colour | A "+0 Ase" row uses the muted colour #6E6450 (4.77:1 on the result card) | 2026-09-25 |
| D-30 | banner-gold-to-combat-004 | The no-pace banner gold looks close to the partial amber; left for V2-COMBAT-004 (004D) | 2026-09-25 |
| D-31 | escort-pace-in-this-story | GUIDE_SPIRIT escort gets a pace term in this story, because PR #79 made the escort win reachable; supersedes D-10 | 2026-09-26 |
| D-32 | joined-spirit-party-par | A GUIDE_SPIRIT escort fight with a joined spirit uses the COMBAT-style party travel par | 2026-09-26 |
| D-33 | escort-par-e-min | A non-joined escort fight uses par = nearest Echo's walk to the spirit + the spirit's walk to the destination; shared curve; one par for both wins; no slack | 2026-09-26 |

---

### D-01. speed-bonus-stories-merged

**Q:** Should the PURSUE-payout review (follow-up task #2, `task_0a287277`) and the `speed_bonus_threshold` board-size check (follow-up task #4, `task_1868ffd0`) in `docs/stories/v2-combat-003.5/followup-tasks.md` stay separate?
**A:** Merge them into one story. Both examine the same term, `RewardCalc.gd:80-82`: one global round threshold (5, set on a 10×10 board in ECONOMY-004 with no recorded rationale) that board-size changes moved across for most modes. A 432-fight probe measured it: wins earning the bonus fell from 44% (12×12) to 18% (18×18), and timer modes (ENDURE; PROTECT and GUIDE_SPIRIT-protect after one completed realm) cannot earn it by their normal win.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-02. pace-reward-d-plus-e

**Q:** Remove the speed bonus (option F), or keep a pace reward that is fair across modes and board sizes (option D+E)?
**A:** D+E: keep a pace reward as a gradient (not a cliff), measured against each mode's own reference, and only after sr-game-designer writes an approved design. Accepted risk, measured on stage 0 only: fights there end near the moment the sides meet (rounds ÷ travel-rounds ≈ 1.1 on both boards), so a travel-based par mostly measures walking; the design must state this limit. Also measured: without any speed term almost every win is rank S, and the speed term is what currently pushes ENDURE to B (halving Thread segment weight via `data.threads.segment_quality_by_grade`).
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-03. endure-kill-reach-in-scope

**Q:** The rank's `max_possible` counts every enemy on the board as killable, but in ENDURE only 40% (12×12) / 12% (18×18) of enemies ever reach the party — fix that in the pace-reward story, or in a follow-up?
**A:** In this story. The rank counts only enemies that reached the party. Measured: removing the old speed term alone already moves ENDURE B→A (the Thread-relevant step); this fix moves A→S. It needs round-by-round reach tracking in `core/`, because waves spawn mid-fight (`CombatRoundSpawnService.gd`).
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-04. rank-meaning-separate-story

**Q:** Once the pace reward is fair, almost every win is rank S — redesign what rank measures in this story?
**A:** No. File "what should combat rank measure" as a separate follow-up story (one story, one subject). This story keeps the rank formula's shape and removes only its unfair parts.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-05. speed-bonus-keys-removed

**Q:** After the pace reward replaces the speed bonus, keep the unread `data.rewards.speed_bonus_threshold` and `speed_bonus_pct` keys (additive-only), or remove them?
**A:** Remove both under the AGENTS.md V2-PROG-012 exception: they become unreachable, and their only consumer (`RewardCalc.gd:80-82`) is migrated in the same change. The story writeup records the full-repo audit (including the inline cfg in `tests/EconomyRewardTests.gd`).
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-06. no-pace-modes-show-nothing

**Q:** During a fight in a mode without a pace term (PROTECT, ENDURE, GUIDE_SPIRIT protect), should the fight screen state that there is no pace bonus?
**A:** No. Show nothing about pace in those modes; the existing objective progress already shows the timer.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-07. pace-par-per-win-type

**Q:** The first unified pace formula was stable across board sizes but not across modes (median win pace ratio: COMBAT ≈1.1, RECOVER ≈0.6-0.7, PURSUE ≈1.8), so one global breakpoint would make the bonus much easier in some modes — accept that, rework the par, or add a hidden per-mode calibration factor?
**A:** Rework the par. sr-game-designer defines the par per win type (kill / hold / contain) so the pace-carrying modes land on a comparable scale, with one global value per gradient parameter and no per-mode calibration number. The orchestrator re-measures the result with the probe before Jeff approves the spec (`docs/stories/pace-reward/design.md`).
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-08. pursue-hold-par

**Q:** PURSUE can end with a kill or with a 3-round hold, but the par is fixed at fight start — price every PURSUE fight as a hold (travel + contain_rounds − 1), or give kill wins a travel-only par?
**A:** Hold par for every PURSUE fight. It is known at the start (it drives the live pace status), and it puts PURSUE's median win pace at 0.94 / 0.98 (old / new board), close to the other modes. A travel-only par for kills brought PURSUE back to a median of about 1.8, because a fleeing quarry takes longer to catch than its start distance predicts. Accepted cost: a kill win earns the pace bonus a little more easily than a hold win (median about 1.1 against 0.85).
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-09. recover-par-nearest-echo

**Q:** What does RECOVER's pace measure?
**A:** Par = the nearest Echo's Chebyshev walk to the relic ÷ mean party movement capacity (floored at 1), plus `hold_rounds − 1` (the arrival round already counts as the first hold round, `CombatRoundSpawnService.gd:139`). Only one Echo must reach the relic, so the nearest Echo sets the par. Measured median win pace 0.85 / 0.92 (old / new board).
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-10. escort-no-pace-until-combat-004

**Superseded by D-31 (2026-09-26).**

**Q:** Should GUIDE_SPIRIT escort carry a pace term in this story?
**A:** No. In the probe, 0 of 48 escort fights ended with `spirit_escorted` (partly the V2-COMBAT-004 defect: a non-joining escort spirit is an immobile structure), so a pace reward for that win could not be earned. Escort is ranked on kills and survivors for now. The spec keeps the formula ready (spirit → destination, no hold) for when V2-COMBAT-004 is done.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-11. pace-player-rule-copy

**Q:** Which player-facing sentence states the pace rule?
**A:** "Stay on pace, and you earn the pace bonus." (option 1 of the three proposals in `docs/stories/pace-reward/design.md` §2).
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-12. pace-shown-by-colour-only

**Q:** The spec proposed an "On pace" / "Behind pace" text line on the fight screen. Should the fight show pace as text?
**A:** No. No pace text and no new UI element during the fight. The existing round counter / objective progress shows pace by colour only: green while a win would still earn the full pace bonus, a middle colour (for example amber) while it would earn a partial bonus, red when it would earn none. The same colour shows on the result screen. No-pace modes keep their normal colour (D-06 still holds). This replaces the "goal visible during the fight" part of ANSWERS.md #64 with a colour signal.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-13. pace-result-screen-text

**Q:** Besides the colour, what does the result screen show about pace?
**A:** Two things: a "Pace bonus" row in the existing reward list, with its Ase amount, also when the amount is 0; and a short text next to the rank letter that names the pace bonus when it changed the rank. No other new element.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-14. pace-design-spec-approved

**Q:** Is the pace bonus design spec approved, so that phase 2 (the values) can start?
**A:** Yes. `docs/stories/pace-reward/design.md` is approved as written in STE, with decisions D-01 to D-13, ANSWERS.md #63, #64. No code starts before phase 2 sets the three global values (`pace_full_ratio`, `pace_zero_ratio`, `pace_bonus_pct`) and the two acceptance gaps, and Jeff chooses them.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-15. pace-values-strict

**Q:** Which values does the pace bonus use?
**A:** `pace_full_ratio` 1.1, `pace_zero_ratio` 1.6, `pace_bonus_pct` 0.05. Measured on the stage-0 probe wins (stage base 60): up to 3 Ase per win, 2.3 Ase on average per pace-mode win, against 3.6 Ase for today's speed bonus on the same wins. Jeff's reason: Ase flows too much today, he plans to reduce Ase output so it becomes meaningful, and a bonus must not be generous.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-16. pace-gaps-drift-guard

**Q:** With the strict values, the modes differ a lot on stage 0 (share of wins with the full pace bonus, old / new board: COMBAT 27 / 52%, PURIFY_SHRINE 5 / 53%, RECOVER 92 / 83%, PURSUE 60 / 67%). How do the design spec §9 acceptance limits work?
**A:** As drift guards, set just above the measured values: Gap A (largest old-board / new-board difference for one pace mode) ≤ 50 percentage points; Gap B (largest difference between two pace modes on the same board) ≤ 90 percentage points. They do not promise equal modes; equal modes on stage 0 is not a goal of this value set. They catch a later change that makes the differences larger.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-17. pace-colour-follows-ase

**Q:** With a maximum pace bonus of 3 Ase, a partial bonus near the zero-bonus limit rounds to 0 Ase (the PURSUE fixture: middle colour, "Pace bonus 0"). What does the player see? (Raised by mechanics-developer.)
**A:** The colour follows the Ase. `pace_state` is `partial` only when the bonus actually paid (or, during the fight, the bonus a win in this round would pay) is at least 1 Ase. A bonus that rounds to 0 gives `none`. Colour and reward row always agree.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-18. intro-trial-no-pace

**Q:** The keeper-intro trial is a COMBAT fight but pays no pace bonus. Does its round counter change colour? (Raised by mechanics-developer.)
**A:** No. The keeper-intro trial is a no-pace fight: normal colour and no pace data, so the colour never promises a bonus that is not paid.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-19. defeat-shows-no-pace

**Q:** After a defeat in a pace mode, what does the result screen show about pace? (Raised by mechanics-developer.)
**A:** Nothing: no "Pace bonus" row, normal round colour, and no `pace_state` in the defeat result data. A loss pays no pace bonus.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-20. pace-ratio-not-in-snapshot

**Q:** Design spec §7 lists `pace_ratio` (a raw float) in the fight snapshot. Keep it? (Raised by mechanics-developer.)
**A:** No. #59 keeps raw floats out of player-facing snapshot data, and the screen needs only `pace_state`. Spec §7 is corrected to match.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-21. pace-one-stage-base

**Q:** The live pace colour read the stage base through `ActiveStageService.get_stage_base_reward()` (stage found by list position), and the result pace bonus through `FlowEncounterState` (stage found by its `index` field). They agree today. How is this handled? (Raised by mechanics-developer.)
**A:** One source for pace. The stage base is captured once at fight start and used for the live colour and for the result pace bonus. So the colour and the "Pace bonus" row can never disagree (D-17). The two older lookups stay as they are; unifying them is a separate follow-up.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-22. pace-state-from-ase-paid

**Q:** A pace ratio just above the full-bonus limit can round up to the full bonus (the merged PURSUE fixture: ratio 1.11, fraction 0.98, pays the full 3 Ase) while `pace_state` says `partial`. How does `pace_state` work? (Raised by mechanics-developer during the merge with main.)
**A:** `pace_state` is set from the Ase paid, in both directions: `full` when the paid pace bonus equals the maximum pace bonus; `partial` when it is more than 0 and less than the maximum; `none` when it is 0. During the fight, the paid bonus is the bonus that a win in the current round would pay. This extends D-17: the colour and the "Pace bonus" row always agree.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-23. reached-enemies-and-ally-kills

**Q:** QA found two defects in the reached-enemy count (`PaceService.record_reached_enemies`). (1) A dead enemy is still checked at its last cell, so a normal kill counts as reached. (2) An enemy can die without reaching the party: a Temporary Ally or a joined spirit kills it, or the killer Echo dies in the same round. How do these kills count? (Raised by qa-verifier.)
**A:** The Temporary Ally and the joined spirit are not party. Their kills do not count toward the rank. The rules:
1. A kill by a party Echo marks that enemy as reached, at kill time. This is true also when the Echo dies in the same round.
2. Otherwise, only a living enemy can become reached. A dead enemy is not checked at its last cell.
3. A Temporary Ally or joined-spirit kill pays the kill Ase (as today), but never counts in the rank. This applies in every mode, COMBAT and PURIFY_SHRINE included. The rank kill term counts only kills by party Echoes. So the fight records which side made each kill.
4. An enemy that a Temporary Ally or joined spirit kills is removed from both sides of the rank: from the kill term and from the rank maximum (`max_possible`). This applies in every mode. So an ally has no effect on the rank (Jeff, option Y).
The rank maximum kill term is then: (all enemies in COMBAT and PURIFY_SHRINE, or reached enemies in the other five modes) without the enemies that an ally or spirit killed (a set difference, so an enemy is never subtracted twice).
Rules 1 and 2 apply to the modes that track reached enemies: PROTECT, ENDURE, RECOVER, PURSUE and GUIDE_SPIRIT.
**Source:** Jeff, 2026-09-25 ("Pays Ase, not rank"; "Ally is not party, it should not count"; "An ally kill should not count in the rank. It should pay Ase."; option Y)
**Date:** 2026-09-25

---

### D-24. hazard-kills-deferred

**Q:** An enemy killed by a hazard has no killer. How does that kill count for the rank? (Raised by mechanics-developer.)
**A:** Not in this story. V2-COMBAT-004 decides it, in slice 004B, which places hazards on production boards (filed on its Notion page, 2026-09-25). Today no fight has hazards, so the case cannot happen. The code keeps its current behaviour: the kill pays Ase and counts in the earned rank kill term. See follow-ups.md #13.
**Source:** Jeff, 2026-09-25 ("H3 this should be handled with hazards not here.")
**Date:** 2026-09-25

---

### D-25. pace-colours-approved

**Q:** ui-ux-designer proposed six pace colours: one set for the dark combat HUD, one for the light result card. One set cannot pass contrast on both. Approve? (Raised by ui-ux-designer.)
**A:** Approved. They match the Living Tree system.

| State | Combat HUD (dark) | Result card (light) |
|---|---|---|
| full | `#7EE3C0` | `#1D6552` |
| partial | `#F28C28` | `#7A4B00` |
| none | `#E5533D` | `#9E2F28` |

They live in `assets/theme/LivingTreeSystem.tres` (theme variations `PaceState*`), read through `ui/components/PacePresentation.gd`. Known risk: amber (partial) and red (none) are hard to separate for colour-blind players (D-12 keeps the display colour-only).
**Source:** Jeff, 2026-09-25 ("Yes I approve. They seem to match the Living Tree system.")
**Date:** 2026-09-25

---

### D-26. result-screen-findings-to-combat-004

**Q:** ui-ux-designer found three result-screen issues outside this story: the `Rounds` line is below the visible scroll area at 1600×900; `_format_reason` shows raw ids such as "relic_secured"; the board under the result card keeps its last pace colour. Fix here? (Raised by ui-ux-designer.)
**A:** No. The UI/UX needs a bigger restructure, and these belong to it. Filed on the V2-COMBAT-004 Notion page (slice 004D, post-battle report), addendum dated 2026-09-25.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-27. rank-cause-note-copy

**Q:** What does the rank-cause note next to the rank badge say? It shows only when the pace bonus raised the rank (`pace_changed_rank`). (Raised by ui-ux-designer, which proposed "Pace bonus raised the rank".)
**A:** "The party's effort earned this rank". The party earns the result, not the player: the fight runs by itself (ANSWERS.md #64).
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### D-28. pace-polish-scope

**Q:** game-feel-developer proposed five polish items. Does D-12 ("colour only") allow an animated colour change, and which items are built? (Raised by game-feel-developer.)
**A:** D-12 allows animation of the colour value (no motion, no new element, no text). Build:
1. A colour blend on the combat HUD when `pace_state` changes. Its time follows the playback speed (the existing `_MOVE_DURATION_*` values).
2. A short brightening before the blend, only on a drop (full→partial, partial→none).
3. A "+0 Ase" breakdown row uses the muted colour, not the positive green.
Do not build: the delayed rank-cause note, and the pace colour on the Pace bonus amount.
**Source:** Jeff, 2026-09-25 ("Agreed with recommendations. Animation is fine. build 1, 2 and 3. Leave 4 and 5")
**Date:** 2026-09-25

---

### D-29. zero-row-colour

**Q:** The first muted colour for a "+0 Ase" row, #908870, has a contrast of 2.89:1 on the light result card. That is below the 3:1 minimum for large text. Which colour? (Raised by game-feel-developer.)
**A:** #6E6450, contrast 4.77:1 (WCAG AA). It is the `color_zero` export in `ui/components/RewardEntryItem.gd`.
**Source:** Jeff, 2026-09-25 (option A)
**Date:** 2026-09-25

---

### D-30. banner-gold-to-combat-004

**Q:** In no-pace fights, the objective banner glyph and progress line keep their authored gold (#D4AF37, `CombatBoardScreen.tscn:157,174`). That gold looks close to the partial amber (#F28C28). A player can read an ENDURE banner as "partial pace". Change a colour now? (Raised by game-feel-developer.)
**A:** No. Leave it for the UI restructure. Filed on the V2-COMBAT-004 Notion page (slice 004D). The round label still separates the two cases: it stays cream in a no-pace fight.
**Source:** Jeff, 2026-09-25 (option A)
**Date:** 2026-09-25

---

### D-31. escort-pace-in-this-story

**Q:** PR #79 (V2-COMBAT-003.5 decisions #58-#60) made the GUIDE_SPIRIT escort spirit walk and added an escort swap rule. Escort wins by escort went from 0 of 11 to 2 of 11 fights. D-10 excluded escort from pace because the escort win was not reachable. Keep that exclusion, or add escort pace now? (Raised by a read-only comparison of main and this story, 2026-09-26.)
**A:** Add escort pace in this story. The escort spirit now moves, and that movement affects pace. This supersedes D-10. The GUIDE_SPIRIT protect variant keeps no pace term (timer mode, D-06).
**Source:** Jeff, 2026-09-26 ("B escort needs to move and this would affect pace. So we need to take this into account.")
**Date:** 2026-09-26

---

### D-32. joined-spirit-party-par

**Q:** In a GUIDE_SPIRIT escort fight where the spirit joins the battle, the game never steers the spirit toward the destination (`CombatRoundGuideSpiritService.gd:266`). In the escort probe, 0 of 77 joined-spirit wins were escort wins; all 77 were kill wins (`escort-tuning.md`). Which par does a joined-spirit escort fight use? (Raised by sr-game-designer and mid-game-designer.)
**A:** The COMBAT-style party travel par: `max(1, mean Echo distance to the nearest enemy / party mean movement range)`, no hold. The fight is a kill fight, so it gets the kill-fight par. Measured full-bonus share: 43% (old board), 49% (new board).
**Source:** Jeff, 2026-09-26 (option A)
**Date:** 2026-09-26

---

### D-33. escort-par-e-min

**Q:** Which par does a GUIDE_SPIRIT escort fight with a non-joined spirit use? The spirit does not move until an Echo stands next to it (`CombatRoundGuideSpiritService.gd:231-244`), then walks 1 cell per round while an Echo stays within 2 cells (`:248-265`). Options measured on 100 fights: A (spirit walk only), C (longer of A and the party par), E-min, E-mean (`escort-tuning.md` §6). (Raised by the escort probe.)
**A:** E-min. Fixed at fight start:
`par_rounds = max(1, max(0, nearest Echo distance to the spirit - 1) / party mean movement range + spirit distance to the destination / spirit movement range)`, no hold term.
Consequences Jeff accepted with this choice:
1. The shared curve applies (full at ratio ≤ 1.10, zero at ≥ 1.60, 5% of the stage base). No escort-only curve (ANSWERS.md #63).
2. One par for both win reasons (`spirit_escorted` and `all_enemies_defeated`), as in PURSUE.
3. No separate blocking slack; the party-walk term absorbs it.
4. Measured: escort wins median ratio 0.97 / 0.98; full bonus in 91% (old board) / 100% (new board) of wins; Gap A 5 pp; Gap B 83 / 43 pp. So escort wins nearly always earn the full bonus.
**Source:** Jeff, 2026-09-26 ("We will go for E-min.")
**Date:** 2026-09-26

---
