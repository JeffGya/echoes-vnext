# V2-COMBAT-003.5 — Decision Log

> Running record of scope and implementation decisions made during ordinary orchestration on this
> story (build/review gates, AskUserQuestion rounds outside a formal `/interview` pass). Distinct
> from `ANSWERS.md`, which is reserved for answers gathered through the `/interview` skill's own
> assumption-clearing pass. See `ANSWERS.md` #51-61 for this story's interview-derived contract.

## Overview

| # | Slug | Topic | Date |
|---|------|-------|------|
| 1 | ally-recruit-now-per-fight | Ally-recruit rolls moved from once/stage to once/fight, kept | 2026-09-13 |
| 2 | board-size-raised-to-18-28 | Board size range raised 12-22 → 18-28 | 2026-09-13 |
| 3 | board-size-probe-committed | Measurement probe tool committed for reproducibility | 2026-09-13 |
| 4 | pursue-reward-drift-out-of-scope | PURSUE reward-payout drift flagged, not fixed here | 2026-09-13 |
| 5 | stale-encountersetupservice-bits-filed | Two pre-existing staleness issues filed separately | 2026-09-13 |
| 6 | movement-style-lives-on-intent-result | movement_style placement corrected to §6.5/§6.7 | 2026-09-14 |
| 7 | interpret-crowding-claim-dropped | Unsupported "Interpret crowded out" claim dropped | 2026-09-14 |
| 8 | movement-style-selection-joint-design | Selection mechanism design routed to two roles jointly | 2026-09-14 |
| 9 | movement-style-deterministic-scoring | Deterministic scoring chosen over weighted-RNG | 2026-09-14 |
| 10 | movement-style-gamefeel-readability-check | Added a readability check step before feasibility pass | 2026-09-14 |
| 11 | movement-style-close-all-route-gaps | All 10 styles get real route distinction, no deferrals | 2026-09-14 |
| 12 | movement-style-measured-renamed | "measured" style renamed to "restrained" | 2026-09-14 |
| 13 | movement-style-finish-allowlist-wiring | forceful/overcommitted/low_exposure builders get added to allowlists and wired into generate_options() this phase, consistent with retreating | 2026-09-14 |
| 14 | movement-style-token-spelling-snakecase | movement_style vocabulary uses code-style snake_case tokens (intercept, low_exposure), not the doc's literal hyphenated prose | 2026-09-14 |
| 15 | interim-wip-commits-per-phase | Adopted WIP commits per shipped phase (local, feature branch) for reviewer traceability, still one PR at the end | 2026-09-14 |
| 16 | movement-style-dedup-cap-raised | Raised the 4-option dedup cap so forceful/overcommitted/low_exposure are actually reachable through generate_options(), not just allowlisted | 2026-09-14 |
| 17 | movement-model-doc-rename-synced-now | docs/movement-model.md updated immediately to say "restrained" instead of "measured", keeping the doc in sync with the rename decision rather than deferring to Phase 3b | 2026-09-14 |
| 18 | movement-style-scoring-integrated-not-repoint | movement_style influences which route option wins by folding style-alignment into BehaviorArbiter._score()'s own pass (like directive_bonus), not by re-pointing the winner after the fact | 2026-09-15 |
| 19 | movement-style-implementation-calls-ratified | Ratified three rebuild judgment calls: intercept→intercepting rename, Seeker vector bias retuned to careful, alignment_weight=0.1 | 2026-09-15 |
| 20 | live-movement-wiring-in-scope | LiveMovementContextService gets wired to generate the full route-shape candidate set (not just "direct") in this story, confirmed as V2-COMBAT-003.5's territory per V2-COMBAT-004's own explicit scope exclusion | 2026-09-15 |
| 21 | overcommitted-ineligible-scores-neutral | Style-ineligible route candidates (e.g. overcommitted on 8 of 12 purposes) score a neutral 0 alignment bonus instead of a hard veto, so they can still win on other mechanical merit | 2026-09-15 |
| 22 | movement-style-bark-line-set | "She made the only right move" set as _REASON_TEXT["style_expression"]; third person confirmed as the correct form for this table (narration, not spoken dialogue) | 2026-09-15 |
| 23 | movement-style-source-doc-updated | docs/movement-model.md §6.6 updated to list movement_style as a real 13th decision source, matching the code | 2026-09-15 |
| 24 | reason-text-pronoun-gap-filed | The _REASON_TEXT table's missing pronoun substitution (all 20 lines always she/her) is pre-existing, filed as a separate task, not fixed in this story | 2026-09-15 |
| 25 | movement-style-bark-line-lowercased | "She made the only right move" lowercased to match the other 19 lines in the same table | 2026-09-15 |
| 26 | truncated-action-stays-verbatim | Truncated route options keep their original planned_action name instead of being downgraded to a generic move, since execution behaves identically either way and the downgrade lost target information | 2026-09-16 |
| 27 | longer-fights-hold-for-investigation | Live wiring made all seven measured fights 20-100% longer; holding the fingerprint re-record until the cause is investigated, not accepted as a baseline update yet | 2026-09-16 |
| 28 | crawl-fix-in-scope-this-story | The distance-vs-commitment scoring flaw (crawl to 1 cell regardless of capacity past a break-even distance) is a regression Phase 3c's own wiring introduced, not a pre-existing flaw it merely exposed — confirmed against Jeff's own prior play testing, where capacity alone (no scoring) correctly drove movement distance. Fixed in this story, not filed separately | 2026-09-16 |
| 29 | scout-carefully-gap-confirmed-as-designed | Test D's residual gap under directive.scout_carefully stays capacity-normalized on purpose, no new decision needed — already covered by decision #28's authorized fix | 2026-09-19 |
| 30 | unit-mismatch-tracked-as-followup | commitment/progress_origin_distance unit mismatch (cost vs. distance) tracked as a follow-up task, not fixed in this story | 2026-09-19 |
| 31 | isolation-experiment-clean-rerun-required | The isolation experiment behind decision #27's "longer fights, cause TBD" may have run on an uncleared test save dir — rerun clean before accepting its cause-finding and acting on decision #27's re-record | 2026-09-19 |
| 32 | pursue-victory-loss-investigate-first | Clean rerun found PURSUE now loses (used to win) and ENDURE drops rank, both from the live-wiring change — investigate the cause before re-recording anything | 2026-09-19 |
| 33 | pursue-loss-fix-designed-in-story | Root cause found: style scoring term outweighs the real distance decision ~6:1 — design a real fix in this story (sr-game-designer + mid-game-designer jointly, mechanics-developer builds, qa-verifier checks) | 2026-09-19 |
| 34 | side-issues-filed-not-fixed | Two issues found during diagnosis, not the cause of the bug (silent stand-still with no logged warning; narrowed path-planning view) — filed as follow-up tasks, not fixed here | 2026-09-19 |
| 35 | urgency-fix-includes-vector-rebalance | The vector_bias rebalance (3 of 10 rows) ships together with the urgency-damping fix, not filed separately | 2026-09-19 |
| 36 | style-visible-from-standing-1-but-grows | Two new Echoes at Standing 1 must never move identically, but style should also visibly develop as Standing grows — needs a floor, not the near-invisible-at-Standing-1 curve the first design produced | 2026-09-19 |
| 37 | full-seven-fixture-re-record-approved-close-out-now | Full 7-fixture re-record approved once fix is verified safe (no win may flip to loss) — build now, no further investigation branches, close Phase 3c | 2026-09-19 |
| 38 | pursue-fix-built-scout-carefully-masking-accepted | Fix built and verified: PURSUE now wins (was a loss), no fixture flipped win→loss, all 7 re-recorded. Production urgency_progress_gain also suppresses the scout_carefully cliff — accepted as an expected side effect of the approved fix, not a separate masking bug; the unit-test canary (Test D) stays red by keeping its fixture config isolated from the production value | 2026-09-19 |
| 39 | endure-rank-regression-accepted | ENDURE's re-recorded baseline is a real step down from the last green baseline (A→B, one fewer kill) — accepted, win is preserved, no further investigation | 2026-09-20 |
| 40 | emotion-trace-fixtures-re-recorded-now | The 6 held emotion_trace_* fixtures (decision #27) get re-recorded now — the hold's reason (cause unknown) no longer applies | 2026-09-20 |

---

## Entries

### 1. ally-recruit-now-per-fight

**Q:** The board-variety fix (encounter_id now identifies one fight, not one stage) incidentally changed `RecruitmentConsequenceService`'s ally-recruit roll from once per stage to once per fight — keep this, or cap it back to one roll per stage?
**A:** Keep it. Every comment in `RecruitmentConsequenceService` already describes per-encounter intent; the old stage-wide guard was itself the `encounter_id` bug masking that intent, not a deliberate scarcity lever.
**Source:** Jeff, 2026-09-13
**Date:** 2026-09-13

---

### 2. board-size-raised-to-18-28

**Q:** Of the three measured board-size options (raise base; scale terrain to board area; do nothing), which should V2-COMBAT-003.5 implement, and what should the late-game max become?
**A:** Option 1, raise the base — measured as the best result on every axis (Courage: 0→81 islands per 50 boards at 18x18, none clamped; Wisdom: least island-size clamping). Jeff also wants the late-game ceiling raised to preserve a real growth range across realm completions, not just the early floor: `base_cols`/`base_rows` 12→18, `max_cols`/`max_rows` 22→28 (the whole range shifted +6, `growth_per_completion` unchanged at 1).
**Source:** Jeff, 2026-09-13
**Date:** 2026-09-13

---

### 3. board-size-probe-committed

**Q:** `tools/BoardSizeOptionsProbe.gd` (the measurement tool behind decision #2) was untracked, and `balance.json`'s comment cites it as evidence — commit it, or drop the citation?
**A:** Commit it. Keeps the cited evidence reproducible; it's a small, additive, read-only measurement tool matching the existing `TerrainRegionProbe.gd` pattern.
**Source:** Jeff, 2026-09-13
**Date:** 2026-09-13

---

### 4. pursue-reward-drift-out-of-scope

**Q:** PURSUE's reward payout moved (Ase 55→64, Ekwan 7→8) as a side effect of the board-size change resolving the fixture's fight one round faster — address it in this story?
**A:** No. Flagged for later attention (see spawned follow-up task), out of scope for V2-COMBAT-003.5.
**Source:** Jeff, 2026-09-13
**Date:** 2026-09-13

---

### 5. stale-encountersetupservice-bits-filed

**Q:** A review found two pre-existing, story-unrelated staleness issues in `EncounterSetupService.gd` while it was open for the board-size change — a comment claiming PURSUE's board is "2x one dimension" when the config is actually 4x, and fallback defaults still reading 12/22 instead of the new 18/28. Fix now, or file separately?
**A:** File separately (see spawned follow-up task). Both predate this story (V2-STAGE-004) and aren't its subject.
**Source:** Jeff, 2026-09-13
**Date:** 2026-09-13

---

### 6. movement-style-lives-on-intent-result

**Q:** The story brief claimed `docs/movement-model.md` §6.6 requires `DecisionTrace` to carry `movement_style`. A direct read of §6.6 shows this is false — `movement_style` is actually a field on §6.5 (Movement Intent) and §6.7 (Movement Result), and `DecisionTrace.PLAYER_SAFE_FIELDS` explicitly excludes it. Follow the doc as written, or amend the doc to route style through DecisionTrace instead?
**A:** Follow the doc as written. `movement_style` lives on Movement Intent and Movement Result, surfaced to the player through Movement Result's `player_explanation` — not added to `DecisionTrace`/`PLAYER_SAFE_FIELDS`.
**Source:** Jeff, 2026-09-14
**Date:** 2026-09-14

---

### 7. interpret-crowding-claim-dropped

**Q:** The story brief claimed collapsing purpose and style into one axis "crowded Interpret out." A full-file grep and code cross-check found no textual support for this — "Interpret" belongs to a structurally separate system (Keeper-guidance consent/reading, `GuidanceContribution.gd`), not the purpose/style movement decision. Drop the claim?
**A:** Yes, drop it. Phase 3's problem statement is reframed around what the doc actually supports: Echoes can't express *how* they act on a held purpose, with no claim about Interpret specifically.
**Source:** Jeff, 2026-09-14
**Date:** 2026-09-14

---

### 8. movement-style-selection-joint-design

**Q:** No selection mechanism for `movement_style` exists anywhere in `docs/movement-model.md` — only "biases, not deterministic assignments" language and a vector-direction tendency table. This is genuinely undesigned. Who designs it before a build agent implements it?
**A:** Both `sr-game-designer` and `mechanics-developer`, jointly — this needs game-feel/narrative judgment (which inputs bias which styles, how strongly) and technical feasibility judgment (what's implementable as a bounded, deterministic, non-`BehaviorArbiter`-growing service) together, not one role guessing at the other's constraints.
**Source:** Jeff, 2026-09-14
**Date:** 2026-09-14

---

### 9. movement-style-deterministic-scoring

**Q:** `sr-game-designer`'s selection design has one architectural fork: deterministic scoring (highest-scoring style wins, same pattern as `BehaviorArbiter._score()`) vs. weighted-RNG sampling (a seeded random draw biased by score). Which?
**A:** Deterministic scoring. Same Echo, same situation, same seed → same style, always — matches the causal-explainability requirement (the winning term IS the reason shown to the player) and reuses two existing scoring precedents already in the codebase (`BehaviorArbiter._score()`, `data.combat.movement.spatial_utility`).
**Source:** Jeff, 2026-09-14
**Date:** 2026-09-14

---

### 10. movement-style-gamefeel-readability-check

**Q:** Should `game-feel-developer` do a narrow readability check on the style-to-route mapping before `mechanics-developer`'s technical-feasibility pass, even though full polish/animation work belongs to a later story?
**A:** Yes. Cheap, and catches a "technically ten styles, feels like two" problem — some styles indistinguishable once executed regardless of later animation — before anything gets built, not after.
**Source:** Jeff, 2026-09-14
**Date:** 2026-09-14

---

### 11. movement-style-close-all-route-gaps

**Q:** A feasibility pass found 6 route-shape gaps preventing full positional distinction across the ten styles, with 2 genuinely expensive (new flanking-path search for `lateral`; new control-cost-tolerant pathfinding for `forceful`/`overcommitted`). Ship 7 of 10 as distinct and 3 metadata-only, or close all gaps now?
**A:** Close all gaps now, including the two expensive ones. All ten styles get genuinely distinct routes this phase — no metadata-only styles.
**Source:** Jeff, 2026-09-14
**Date:** 2026-09-14

---

### 12. movement-style-measured-renamed

**Q:** The proposed "measured" style collides in name with the existing "commitment" field's own `measured` value on the same Movement Intent contract. Rename, and to what?
**A:** Rename to `restrained` — reads as controlled/holding back, clearly distinct from the commitment band's capacity-spend meaning.
**Source:** Jeff, 2026-09-14
**Date:** 2026-09-14

---

### 13. movement-style-finish-allowlist-wiring

**Q:** A review found `forceful`/`overcommitted`/`low_exposure` route builders exist but aren't in `MovementOption.STYLES`/`MovementOptionService.STYLE_ORDER`/`BehaviorArbiter._ROUTE_STYLE_ORDER`, so wiring them into `generate_options()` today fails validation — inconsistent with `retreating`, which was added and wired in the same diff. Finish consistently now, or leave as a deliberate Phase 3b deferral?
**A:** Finish now — add to the allowlists and wire in like `retreating`, so Phase 3b does pure selection-logic work rather than inheriting route-plumbing cleanup.
**Source:** Jeff, 2026-09-14
**Date:** 2026-09-14

---

### 14. movement-style-token-spelling-snakecase

**Q:** `docs/movement-model.md` §9 writes style names as hyphenated prose (`intercepting`, `low-exposure`); the codebase's existing route-shape tokens are snake_case (`intercept`, `low_exposure`). Which spelling should the actual `movement_style` vocabulary use, since it becomes a save/trace-visible identifier?
**A:** Code-style snake_case — matches this project's existing identifier convention; the doc's prose names were never meant as literal tokens.
**Source:** Jeff, 2026-09-14
**Date:** 2026-09-14

---

### 15. interim-wip-commits-per-phase

**Q:** Nothing across Phases 1, 2, or 3a has been committed — a reviewer couldn't isolate Phase 3a's diff by git at all, only by a file list given in the dispatch prompt. Start committing per shipped phase, or stay uncommitted until the single end-of-story PR?
**A:** WIP commit per shipped phase, local to the feature branch — keeps reviewers able to diff cleanly and protects against losing a large amount of uncommitted work. Still one PR at the very end, per the original plan.
**Source:** Jeff, 2026-09-14
**Date:** 2026-09-14

---

### 16. movement-style-dedup-cap-raised

**Q:** `MovementOptionService`'s 4-option dedup cap hard-stops before reaching `forceful`/`overcommitted`/`low_exposure` in almost all cases, since they were appended last in rank order — they're allowlisted and wired but practically unreachable through `generate_options()` output. Raise the cap, re-rank, or defer reachability to Phase 3b?
**A:** Raise the cap so all 11 route-shapes can genuinely surface as distinct candidates when a board produces them, rather than being present in name only.
**Source:** Jeff, 2026-09-14
**Date:** 2026-09-14

---

### 17. movement-model-doc-rename-synced-now

**Q:** `docs/movement-model.md` §9 still says "measured," which was renamed to "restrained" earlier this session (decision #12) — update the doc now as part of Phase 3a, or leave it for Phase 3b since the token itself isn't implemented in code yet either?
**A:** Update now. Keep the doc and decisions in sync rather than letting it contradict a decision already made.
**Source:** Jeff, 2026-09-14
**Date:** 2026-09-14

---

### 18. movement-style-scoring-integrated-not-repoint

**Q:** Phase 3b's first build let `movement_style` override which route option wins by re-pointing the winner AFTER `_score()` already picked one — a review found this breaks two documented invariants downstream (`DecisionTrace`'s margin can go negative, violating §6.6's rule against promoting a tie-break into a character explanation; `DivergenceDetector`'s stated precondition that the winner "genuinely won its own arbiter sort" no longer holds). The alternative is making style purely descriptive (never changes the winner), which avoids the invariant breaks but means vector/calling/fear/morale never actually influence behavior, only narrate it after the fact. Which should it be?
**A:** Style influences selection, but properly — folded into `BehaviorArbiter._score()`'s own scoring pass as a term (same pattern as `directive_bonus`), not as a post-hoc re-point. The winner is honestly the highest-scored candidate from the start, fixing the invariant breaks at the root rather than patching around them.
**Source:** Jeff, 2026-09-15
**Date:** 2026-09-15

---

### 19. movement-style-implementation-calls-ratified

**Q:** Three implementation judgment calls from the integrated-scoring rebuild, bundled for ratification: (1) rename style token `intercept`→`intercepting` to match §9's literal spelling and avoid colliding with the `intercept` purpose token; (2) retune Seeker's vector bias from `lateral` (shared with Opportunist) to `careful` (closer to §10.4's "read, scout, investigate" framing); (3) `alignment_weight = 0.1`, scaling identity score into arbiter score units (worth a few points, same order as a leadership bonus, marked PROPOSED DEFAULT pending playtest). Ratify all three?
**A:** Ratified, all three.
**Source:** Jeff, 2026-09-15
**Date:** 2026-09-15

---

### 20. live-movement-wiring-in-scope

**Q:** `movement_style` selection is fully built and correctly wired into `BehaviorArbiter`'s live scoring pass — but `LiveMovementContextService` (the live per-turn option builder, confirmed live in production since V2-COMBAT-002 Slice 6) only ever builds one hardcoded `"direct"`-shaped candidate per turn, so no live fight can ever show style variety. Does closing this gap belong in V2-COMBAT-003.5?
**A:** Yes. V2-COMBAT-004's own Notion page explicitly disclaims this exact gap ("The movement-style axis is filed to V2-COMBAT-003.5... a movement-layer change across every mode, not a combat-UI item"), and no other story claims it. Wire `LiveMovementContextService` to build the full route-shape candidate set (reusing `MovementOptionService`'s existing shared scoring helpers, per that file's own comment about not duplicating logic) instead of one hardcoded option.
**Source:** Jeff, 2026-09-15
**Date:** 2026-09-15

---

### 21. overcommitted-ineligible-scores-neutral

**Q:** `MovementOptionService` builds an `overcommitted` route candidate for every purpose (mechanical layer, purpose-agnostic), but `movement_style`'s eligibility rules only allow `overcommitted` for 4 of 12 purposes — a deliberate narrative restriction. The current `-1.0e6` sentinel permanently vetoes that candidate on the other 8 purposes for every actor, contradicting the whole point of raising the dedup cap to make these styles reachable (decision #16). Score it neutral instead of vetoing, or stop generating the candidate for ineligible purposes?
**A:** Neutral. Style-ineligible candidates score a 0 alignment bonus instead of a hard veto — they can still win on other mechanical merit (cost, hazard avoidance), they just never get an identity-driven push toward them. This also removes the runner-up margin-inflation side effect the hard veto caused.
**Source:** Jeff, 2026-09-15
**Date:** 2026-09-15

---

### 22. movement-style-bark-line-set

**Q:** A decisive movement_style contribution had no bark text — `GuidanceContribution._REASON_TEXT` fell through to a generic line. What line, and what person/pronoun form?
**A:** "She made the only right move" — third person, matching this table's three existing sibling lines (narration explaining why she acted, not quoted spoken dialogue, which is a different bark surface with its own first-person convention).
**Source:** Jeff, 2026-09-15
**Date:** 2026-09-15

---

### 23. movement-style-source-doc-updated

**Q:** `DecisionTrace.SOURCES` grew to 13 with `movement_style`; `docs/movement-model.md` §6.6 still lists 12. Update the doc, or fold `movement_style` into the existing `vector` source instead?
**A:** Update the doc. `movement_style` is a real 13th source.
**Source:** Jeff, 2026-09-15
**Date:** 2026-09-15

---

### 24. reason-text-pronoun-gap-filed

**Q:** All 20 lines in `_REASON_TEXT` always render she/her, with no pronoun substitution for male Echoes (unlike `ConversationService.gd`, which does substitute). Fix now, or file separately?
**A:** File separately. Pre-existing, affects the whole table not just the new one, keeps this story on one subject.
**Source:** Jeff, 2026-09-15
**Date:** 2026-09-15

---

### 25. movement-style-bark-line-lowercased

**Q:** The new bark line "She made the only right move" was capitalized; all 19 other lines in the same table are lowercase clause fragments. Match the lowercase form, or keep as written?
**A:** Lowercase: "she made the only right move". Matches the other 19 lines, keeps the surface visually consistent.
**Source:** Jeff, 2026-09-15
**Date:** 2026-09-15

---

### 26. truncated-action-stays-verbatim

**Q:** A route option that stops short of its target (truncated by capacity) can either keep its original `planned_action` name, or get downgraded to a generic `actor.move`. Execution behaves identically either way (a later safety check already catches an out-of-range action). The downgrade blanks `target_id`, losing who the mover was closing on. Which?
**A:** Keep verbatim. No safety difference, and it preserves target information a truncated approach would otherwise lose.
**Source:** Jeff, 2026-09-16
**Date:** 2026-09-16

---

### 27. longer-fights-hold-for-investigation

**Q:** Phase 3c's live wiring (plus its own performance fix) made all seven measured fights take 20-100% more rounds than the pre-Phase-3c baseline. Update the seven recorded fingerprints now, or hold until the cause is investigated?
**A:** Hold. Investigate why fights got longer before accepting new baselines — this may be a real balance shift, not just numbers that moved.
**Source:** Jeff, 2026-09-16
**Date:** 2026-09-16

---

### 28. crawl-fix-in-scope-this-story

**Q:** Follow-up investigation found: before Phase 3c, live movement had no scoring choice at all — an actor simply moved as far as its Standing/Calling-driven capacity allowed. Phase 3c's wiring is what introduced the scored choice that sometimes crawls to 1 cell regardless of capacity, past a break-even distance. Given this is a regression Phase 3c's own work caused (confirmed against Jeff's own prior play testing), fix it in this story, or keep it as a separate follow-up?
**A:** Fix it here. This is completing Phase 3c correctly, not a separate rebalance — Jeff confirmed his own testing showed capacity alone correctly driving movement distance with minimal/no scoring influence, matching the diagnosis exactly.
**Source:** Jeff, 2026-09-16
**Date:** 2026-09-16

---

### 29. scout-carefully-gap-confirmed-as-designed

**Q:** qa-verifier's Phase 3c review flagged Test D as failing on purpose (a residual movement-scoring gap under `directive.scout_carefully` specifically). Should `directive_avoid_overcommit` also become distance-normalized, closing this gap, or leave it as-is?
**A:** No new decision needed. This was already authorized inside decision #28's fix — sr-game-designer deliberately left this term capacity-normalized as part of the approved design, and `game-feel-developer` confirmed the shape. Test D stays red on purpose, documenting the gap. Leave as-is.
**Source:** Jeff, 2026-09-19
**Date:** 2026-09-19

---

### 30. unit-mismatch-tracked-as-followup

**Q:** qa-verifier's Phase 3c review found the commitment fix's `commitment / progress_origin_distance` mixes units (move cost vs. distance in cells) — equal today only because terrain cost is uniform, but would silently break once non-uniform terrain cost or bigger hostile-control surcharges exist. Fix now, or track for later?
**A:** Track for later. No live impact today. Spawn a follow-up task.
**Source:** Jeff, 2026-09-19
**Date:** 2026-09-19

---

### 31. isolation-experiment-clean-rerun-required

**Q:** qa-verifier's Phase 3c review flagged that the isolation experiment behind decision #27's "longer fights, cause TBD" (proving RECOVER/PROTECT/PURSUE/ENDURE/GUIDE_SPIRIT fixtures are unaffected by the commitment fix, and that their round-count increases come from the live-wiring change instead) may have run on an uncleared `/tmp/echoes-vnext-tests` save dir. Trust this cause-finding as-is, or rerun clean first?
**A:** Rerun clean first (delete the stale save dir, rerun the same check). Only once the cause is confirmed clean does decision #27's re-record proceed.
**Source:** Jeff, 2026-09-19
**Date:** 2026-09-19

---

### 32. pursue-victory-loss-investigate-first

**Q:** The clean rerun (decision #31) confirmed the round-count cause (live multi-route-shape wiring, not the commitment fix), and also found a more serious result: the PURSUE fixture fight now LOSES (target escapes, round 8, rank F) where it used to WIN (round 4, rank S). ENDURE also drops rank and one enemy that used to die now survives. Both trace to the live-wiring change. Investigate the cause first, or accept as intended and re-record?
**A:** Investigate first. A win turning into a loss is a real gameplay regression, not a number to re-record.
**Source:** Jeff, 2026-09-19
**Date:** 2026-09-19

---

### 33. pursue-loss-fix-designed-in-story

**Q:** Diagnosis (mechanics-developer, opus) found the root cause: `movement_style`'s scoring term (`alignment_weight = 0.1`, decision #19, marked PROPOSED DEFAULT pending playtest) is worth up to ~5 points, while the real mechanical difference between closing distance fast and a sideways/held-back move is only ~0.7 points. Style always wins, even in a time-pressured chase, because nothing in the scoring lets urgency matter more than style. Most Echoes' personalities also structurally lean away from the `direct` style. Fix now with a full design pass, patch just the one number, or pause?
**A:** Design a fix now, in this story. Route to `sr-game-designer` + `mid-game-designer` jointly (same pattern as decision #8), `mechanics-developer` builds, `qa-verifier` checks — same gate sequence used for decision #28's crawl fix.
**Source:** Jeff, 2026-09-19
**Date:** 2026-09-19

---

### 34. side-issues-filed-not-fixed

**Q:** The diagnosis also found two issues that are NOT the cause of the PURSUE/ENDURE regression: (1) some Echoes silently stand still with no path and no logged warning, a pre-existing gap exposed by longer fights; (2) the live-wiring narrows the path-planning view Echoes can see, not observed to cause harm yet but a risk on other boards. Fix now, or file separately?
**A:** File both separately as follow-up tasks, tracked in `docs/v2-combat-003.5-followup-tasks.md` so they are not lost.
**Source:** Jeff, 2026-09-19
**Date:** 2026-09-19

---

### 35. urgency-fix-includes-vector-rebalance

**Q:** `sr-game-designer`'s fix design has two parts: (1) urgency damps the style-scoring term and amplifies distance-closing when a goal is urgent; (2) a rebalance of which style each of the 10 identity vectors leans toward (3 of 10 rows change), since `direct` is structurally the rarest style for an ordinary party in any situation. The urgency fix alone is sufficient to ship; the vector rebalance is a related but separable fix. Include both now, or ship urgency-only and file the rebalance separately?
**A:** Include both now.
**Source:** Jeff, 2026-09-19
**Date:** 2026-09-19

---

### 36. style-visible-from-standing-1-but-grows

**Q:** The design's numbers make movement style nearly invisible at Standing 1 (a new Echo), becoming visible only as Standing grows — reasoning: an Echo has not yet formed her own way of moving. Is near-invisibility at Standing 1 correct, or should style be visible from the start?
**A:** Neither extreme. Two new Echoes at Standing 1 must never move identically — some visible style difference from the very start. But that style should also develop, change, and evolve as the Echo grows (Standing increases), not stay flat. The design needs a floor: visible-but-modest at Standing 1, growing with maturity, not scaling all the way to indistinguishable.
**Source:** Jeff, 2026-09-19
**Date:** 2026-09-19

> **Correction, 2026-09-19**: the reasoning given when this question was asked ("style is near-invisible at Standing 1 because vector_scores are low there") was wrong — `sr-game-designer` verified against `data.vectors.archetype_init` after the fact and found a Standing-1 Echo's dominant vector actually seeds at 60.0, not near zero. Jeff's answer and requirement stand regardless. The real gap: two Echoes sharing the same `class_origin` (only 4 of 10 origins are ever rolled at summon, `EchoFactory.gd`) get byte-identical `vector_scores`, so they DO move identically today — confirmed in the `fp_combat` fixture party itself (3 of 5 Echoes are `pillar`). The fix (below, `trait_nudge` reweight) solves this directly without needing the original (wrong) reasoning.

---

### 37. full-seven-fixture-re-record-approved-close-out-now

**Q:** The full fix (urgency damping + `vector_bias` rebalance + `trait_nudge` floor) is expected to shift all 7 recorded fingerprints, not just PURSUE/ENDURE, because every fixture party is Standing-1. No fight may flip win→loss. Is a full 7-fixture re-record acceptable once the fix is verified safe?
**A:** Yes, re-record all 7 once safe. Jeff flagged concern about scope creep and the story not progressing — approved to continue because this fix is needed, but no further investigation branches after this; build, verify, close Phase 3c, move on.
**Source:** Jeff, 2026-09-19
**Date:** 2026-09-19

---

### 38. pursue-fix-built-scout-carefully-masking-accepted

**Q:** The fix built clean: PURSUE now wins (round 7, rank S, was a round-8 loss), no fixture flipped win→loss, all 7 re-recorded. One side effect: the production `urgency_progress_gain` value also suppresses the `scout_carefully` gap (decision #29) whenever a goal carries urgency — the unit-test canary (Test D) stays red only because its own fixture config is deliberately kept isolated from the production value. Accept this as an expected consequence of the approved urgency fix, or treat it as a new masking concern needing its own review?
**A:** Accepted as an expected, positive consequence of the approved fix — urgency overriding caution during a chase is exactly what was authorized. The unit-test canary staying red (isolated fixture config) is sufficient to keep the gap documented and visible to future work. No further action.
**Source:** Jeff, 2026-09-19 (game-orchestrator call, consistent with decisions #28/#29's scope; not separately re-asked)
**Date:** 2026-09-19

---

### 39. endure-rank-regression-accepted

**Q:** qa-verifier's independent re-run confirmed ENDURE's re-recorded baseline is a step down from the last GREEN baseline (rank A→B, ase 55→50, ekwan 7→6, one enemy that used to die now survives) — not just from the broken interim state. The win itself is preserved (decision #37's hard gate). Accept this rank regression into the new baseline, or investigate why the kill did not return before recording it?
**A:** Accept it, close out now. The win is preserved; further investigation risks more delay than the gap is worth.
**Source:** Jeff, 2026-09-20
**Date:** 2026-09-20

---

### 40. emotion-trace-fixtures-re-recorded-now

**Q:** 6 `combat_baseline/emotion_trace_*` fixtures have been held failing since decision #27, pending investigation into why fights got longer. That investigation is now complete (decisions #32-38) and the cause is fixed. Re-record these 6 now (closing decision #27's hold), or leave them failing and note it in the story close-out docs?
**A:** Re-record them now. The reason for holding them no longer applies; leaving permanent red tests with no active cause is worse than closing it out.
**Source:** Jeff, 2026-09-20
**Date:** 2026-09-20

---
