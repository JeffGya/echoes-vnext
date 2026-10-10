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
| 41 | split-into-two-prs-ship-what-is-done-now | Open a PR now for everything committed through Phase 3c; Phase 4 onward becomes a separate PR later — supersedes the original one-PR-at-the-end plan | 2026-09-20 |
| 42 | pr-per-phase-going-forward | PR #69 (already a split from one-PR-at-the-end) was still too large for /ultrareview — going forward, one PR per phase, not per story | 2026-09-20 |
| 43 | resist-fear-fix-all-11-call-sites | resist_fear did nothing anywhere, not just in combat — expand this phase to wire it through all 11 apply_fear_delta() call sites (real count found: 14), not just the combat fix already built | 2026-09-22 |
| 44 | resist-fear-revert-4-inert-sites | Revert resist_fear wiring at the 4 sites where the delta>0 gate can never fire (always-decreasing fear) — keep the diff honest | 2026-09-22 |
| 45 | resist-fear-wire-two-remaining-paths | Wire resist_fear into 2 more fear-gain paths that bypass apply_fear_delta() entirely: ally-death knock (FlowEncounterState.gd) and calling-confirmation fear (CallingService.gd) | 2026-09-22 |
| 46 | resist-fear-combat-bark-visibility | Wire the existing combat_resilient bark to fire for the new combat resist_fear wiring, so the player can see the trait working | 2026-09-22 |
| 47 | resist-fear-bark-needs-cooldown | Add a cooldown to combat_resilient before shipping — priority-2, no-cooldown bark could crowd out fear/morale/guidance barks for a frontline resist_fear echo | 2026-09-22 |
| 48 | resist-fear-wire-two-more-paths | Wire resist_fear into 2 more fear-gain paths: KO-spread fear (CombatRoundEmotionService.gd) and surprise/ambush fear (EncounterSetupService.gd) | 2026-09-22 |
| 49 | phase6-fix-missing-live-styles-before-phase7 | 3 of 10 movement styles never appear in live combat (lateral, low_exposure, retreating) — fix the 2 confirmed bugs (lateral, low_exposure) before Phase 7; retreating's rarity is expected, not a bug | 2026-09-23 |
| 50 | phase6-fix-followup-tasks-file-now | Follow-up tasks file has wrong info (false premise on #10, stale ANSWERS.md refs, #1 marked open though already fixed) — fix now | 2026-09-23 |
| 51 | lateral-fix-must-not-relabel-identical-route | lateral steals the name of an unchanged intercept/screen route in ~40% of appearances — block it from surviving dedup under the wrong name, fix now | 2026-09-24 |
| 52 | low-exposure-hazard-safety-stays-first | low_exposure must never pick a route through more hazards just to stay farther from a live hostile — hazard avoidance stays the strict first priority | 2026-09-24 |
| 53 | lateral-guard-extended-to-all-candidates | lateral's identical-route guard (decision #51) extended to cover every other candidate style, not just the purpose's primary route — confirmed real, not just theoretical: fired 24 times in a 21-fight sample | 2026-09-24 |
| 54 | lateral-fix-recorded-values-signed-off | 15 recorded test values (11 fingerprints, 4 emotion traces) re-recorded, all cleanly attributed to the lateral fix, no fixture flips win→loss | 2026-09-24 |
| 55 | lateral-fix-faster-fights-accepted | 2 fixture fights resolve faster as a side effect (PURSUE, PURIFY_SHRINE) — accepted, same class of already-filed reward-formula concern (follow-up tasks #2/#4) | 2026-09-24 |
| 56 | lateral-test-failure-message-fixed | New end-to-end test correctly catches the regression but fails at the wrong line with a misleading message — fix the message before commit | 2026-09-24 |
| 57 | lateral-guard-cell-only-comparison-confirmed | Codex flagged the same cell-vs-full-route ambiguity qa-verifier's finding 5 raised — confirmed: keep cell-only comparison, no code change | 2026-09-24 |
| 58 | guide-spirit-escort-capacity-bug-fix-before-phase8 | Pre-existing bug (since July, not this story): GUIDE_SPIRIT escort's spirit gets capacity 0 because is_structure is checked before any capacity override — fix before Jeff's Phase 8 playtest | 2026-09-25 |
| 59 | guide-spirit-blocking-routed-to-sr-game-designer | A guarding Echo can block the spirit's path indefinitely — this is a party-AI design question, routed to sr-game-designer for a proper design pass | 2026-09-25 |
| 60 | guide-spirit-swap-design-adds-feel-check | sr-game-designer recommended a deterministic yield/swap (blocking Echo trades cells with the spirit, every round, no threshold) — Jeff added a game-feel-developer readability check before mechanics-developer builds it | 2026-09-25 |
| 61 | spirit-barks-added-to-tier-2-before-commit | qa-verifier found all 5 spirit_* bark contexts missing from data.voice.bark_tiers, so they default to lowest priority and can be silently dropped in a crowded round — add all 5 to tier 2, fix before commit | 2026-09-25 |
| 62 | pr79-ultrareview-nits-fixed-before-merge | Cloud review of PR #79 found 2 verified nit-severity findings (wasted deep-copy, duplicate eligibility lookup) in the escort-yield swap — fix both now, before merge | 2026-09-26 |
| 63 | ashen-hallow-board-sizing-filed-as-followup | Phase 8 playtest found GUIDE_SPIRIT boards look compact (not stretched) on low-plateau-count virtues like courage (Ashen Hallow) — pre-existing V2-STAGE-004 gap, unrelated to this story's subject — filed as follow-up task #14 | 2026-09-26 |
| 64 | large-board-camera-filed-as-followup | Phase 8 playtest found the combat camera does not handle a genuinely large stretched GUIDE_SPIRIT board well — pre-existing UI/camera behavior, unrelated to this story — filed as follow-up task #15 | 2026-09-26 |
| 75 | initiative-rows-stay-tappable | Initiative rows stay tappable in Story 2. The phone redesign of the panel is a follow-up task | 2026-10-02 |
| 76 | two-finger-pinch-pan-fixed-in-story-2 | The two-finger pinch no longer pans the board. The fix is part of Story 2 | 2026-10-02 |
| 77 | locked-actor-death-follows-party | When the locked actor dies, the camera follows the party. Assumed, not confirmed: a dead actor cannot be locked | 2026-10-02 |
| 78 | combat-wheel-zoom-approved | Mouse-wheel zoom in Combat is approved. It zooms only over open board. Assumed: one notch is 1.1x | 2026-10-02 |
| 79 | space-drag-speed-differs-combat-vs-sanctum | Space+LMB drag pans 1:1 in Combat and 2.5x in Sanctum. Left open as a design call | 2026-10-02 |
| 80 | headless-screenshots-need-a-real-window | Godot --headless cannot render screenshots. On macOS, use scripts/screenshot.gd from a real window. Fixture combat_initiative_full added | 2026-10-02 |
| 81 | app-root-shows-a-shown-screen-once | AppRoot._show_screen hides only the other screens. A second snapshot for the shown screen no longer hides and re-shows it | 2026-10-03 |
| 82 | combat-buttons-take-no-focus | Every Combat button has focus_mode NONE, so Space (held for Space+drag) cannot press a focused button | 2026-10-03 |
| 83 | lost-touch-release-safety-net | A finger-0 touch press clears all stale pointer state, so a lost release cannot block the board | 2026-10-03 |
| 84 | dead-actor-cannot-be-locked | Confirmed: a dead actor cannot be locked by a board tap, an echo card or an initiative row | 2026-10-03 |
| 85 | wheel-zoom-is-smooth | One wheel notch is 1.1x (confirmed). The zoom eases toward a target over frames; pinch stays immediate | 2026-10-03 |
| 86 | every-drag-pans-1-to-1 | Mouse drag, finger drag and Space+LMB drag pan 1:1 on every screen, Sanctum included. Trackpad two-finger pan stays 2.5x | 2026-10-03 |
| 87 | board-camera-swallows-space-for-a-focused-button | While a board camera takes input, Space does not press a focused button. Text fields keep Space | 2026-10-03 |
| 88 | new-zoom-range-cancels-wheel-ease | configure_zoom_range stops a running wheel ease, so a new range starts at its default zoom | 2026-10-03 |
| 89 | space-guard-skips-modal-buttons | The Space guard does nothing when the focused button is inside ModalHost, so dialogs keep Space | 2026-10-03 |
| 90 | space-guard-needs-only-an-enabled-camera | The Space guard needs only camera.enabled, so it also works while the echo detail locks the camera | 2026-10-03 |
| 91 | space-guard-covers-every-base-button | The Space guard checks BaseButton (Button, TextureButton, CheckBox and others), not only Button | 2026-10-03 |
| 92 | space-guard-only-on-the-board-view | In Sanctum the Space guard runs only on the board view and its echo detail. Summon, Vows, Weaving, Realm and Echo Party keep Space on their buttons | 2026-10-04 |
| 93 | z-key-zoom-cycle-is-shared | The Z zoom cycle is a shared BoardCamera option. Combat uses it; Sanctum keeps its own Z. Supersedes the Z part of #72 | 2026-10-04 |
| 94 | sanctum-zoom-on-the-shared-levels | Sanctum moves onto the shared zoom levels: Z and its wheel step one level and ease. Supersedes the "Sanctum keeps its own Z" part of #93 | 2026-10-04 |
| 95 | one-wheel-rule-for-every-board-camera | Every board camera uses Combat's wheel: 1.1x per notch, eased, continuous. Sanctum's wheel stops stepping levels; Z keeps the levels. Supersedes the Sanctum-wheel part of #94 | 2026-10-04 |
| 96 | stretched-board-fill-per-virtue | GUIDE_SPIRIT/PURSUE boards keep each virtue's ground share (follow-up #14). New optional signature key `stretch_fill` in `data.stages.map_shape.by_virtue`: `scatter` multiplies plateau count by the board's stretch multiplier; missing or `none` changes nothing. Scatter: courage, acceptance, generosity. None: wisdom, humility, empathy, forgiveness, truth, leadership, compassion (count is identity; filed for a later follow-up). Jeff's play test 2026-10-06: courage looked right; wisdom with count x5 became one solid mass, so wisdom, humility and empathy moved to none (same reason). Regression tolerance: 10 points below the virtue's 18x18 mean. Measured by `tests stretchprobe` (probe removed; numbers kept) | 2026-10-05 |
| 107 | skill-mark-and-reveal-reach-fixed-in-its-own-pr | Skill `actor.mark` and `actor.reveal` resolved as idle at distance 2 or more. Fixed in PR0, before the stop-short work (follow-up #6): `ACTION_RANGES` gains `actor.mark: 3` and `actor.reveal: 3`, and the reveal offer gate gains `enemy_dist <= 3`. Jeff chose option O1 and reach 3. No recorded value moved. Index rows 97 to 106 are not listed here; their bodies are below | 2026-10-06 |
| 108 | stop-short-benefit-after-a-short-route | An Echo whose winning route is the half-capacity `conservative` route now plays one benefit (Guard, Observe or Hold) at the stop cell, only with a cause (fear or low morale; identity) and a benefit. Shipped OFF in PR1; ships ON from PR2 (`data.actor.stop_short.enabled` true, weight 6.0). Follow-up #6, PR1 core | 2026-10-09 |
| 109 | stop-short-visible-tell | The stop is shown on the board: marker outside the Echo, word chip, hop, rest pose for the whole guarding status. Placeholder art and motion. Follow-up #6, PR1 UI | 2026-10-09 |

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
**A:** File both separately as follow-up tasks, tracked in `docs/stories/v2-combat-003.5/followup-tasks.md` so they are not lost.
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

### 41. split-into-two-prs-ship-what-is-done-now

**Q:** The original plan (Phases 0-9) was one story, one PR at the end. Phases 0-3c are done, committed, reviewed. Phase 4 onward (doc/debug fixes, scattered small defects, combined verification, manual test, docs/PR prep) has not started. Open a PR now for what's done, and a separate PR later for the rest — or hold everything for one PR at the very end as originally planned?
**A:** Split into two PRs. Open a PR now covering everything committed through Phase 3c. Phase 4 onward becomes a separate PR later. This supersedes the original plan's "one PR at the end" note (plan snapshot, Phase 9).
**Source:** Jeff, 2026-09-20
**Date:** 2026-09-20

---

### 42. pr-per-phase-going-forward

**Q:** `/ultrareview` refused PR #69 outright — 112 files, 21,043 lines, over its size limit, even though it was already a split from the original one-PR-at-the-end plan (decision #41). What PR granularity should the rest of this story (and future stories) use?
**A:** One PR per phase (or a small cluster of tightly related phases) from now on, not one PR per story. Each of Phase 4, Phase 5, etc. ships as its own PR once reviewed and committed.
**Source:** Jeff, 2026-09-20
**Date:** 2026-09-20

---

### 43. resist-fear-fix-all-11-call-sites

**Q:** Phase 5's `resist_fear` build found the plan's premise was wrong — the trait does nothing at ANY of its supposed 11 existing call sites (recovery, sanctum ticks, vow break, weave, contact fail, near-death, institution, keeper intro, etc.), because none of them pass `resilience_traits`/`expression_band` to `EmotionService.apply_fear_delta()`. The build wired combat's per-hit/near-death fear correctly, but that makes combat the ONLY place the trait works, not one more working site among many. Ship the combat fix now and file the other 11 as a follow-up, or expand this phase to fix all 11 now?
**A:** Expand this phase now. Wire `resilience_traits`/`expression_band` through all 11 `apply_fear_delta()` call sites in this same phase, so the trait works everywhere at once.
**Source:** Jeff, 2026-09-22
**Date:** 2026-09-22

> **Correction, 2026-09-22**: the real count is 14 call sites, not 11 — the original recon list was incomplete (missed `SituationEngagementService.gd`'s 2 sites, undercounted others). All 14 were wired. 4 of them can never fire (`resist_fear`'s gate requires `delta > 0`; these 4 always subtract fear — recovery, keeper intro x2, the sanctum-tick direction where fear is already above base and settling down). Decision #44 reverts those 4 to keep the diff honest.

---

### 44. resist-fear-revert-4-inert-sites

**Q:** 4 of the 14 wired `resist_fear` call sites always subtract fear, so the trait's `delta > 0` gate can never fire there (recovery, keeper intro x2, the sanctum-tick "fear above base, settling down" direction). Keep them wired as harmless dead code for consistency, or revert to keep the diff honest?
**A:** Revert those 4. Keep the diff clean — no wiring that can never do anything.
**Source:** Jeff, 2026-09-22
**Date:** 2026-09-22

---

### 45. resist-fear-wire-two-remaining-paths

**Q:** qa-verifier's combined review found 2 more fear-gain paths that bypass `apply_fear_delta()` entirely, so `resist_fear` still doesn't apply there even after decisions #43/#44: `FlowEncounterState.gd` (an ally dying gives every echo a fear knock via `apply_fear_gain`, same shape as the combat fear this phase already fixed) and `CallingService.gd` (confirming an incompatible/ambivalent calling writes `fear_current` directly, skipping `apply_fear_delta()` altogether). Fix these two now, or file as a follow-up?
**A:** Fix now, in this phase.
**Source:** Jeff, 2026-09-22
**Date:** 2026-09-22

---

### 46. resist-fear-combat-bark-visibility

**Q:** qa-verifier found the existing `combat_resilient` bark (triggered by `emotion._resilience_fired`) never fires for the new combat wiring — combat actors have no `emotion` block, and the flag is set during the attacker's turn but the bark-check pattern expects it readable on the target's own turn. `resist_fear` now works correctly in combat, but the player never sees a sign of it. Fix the visibility now, or file as follow-up?
**A:** Fix now, in this phase.
**Source:** Jeff, 2026-09-22
**Date:** 2026-09-22

---

### 47. resist-fear-bark-needs-cooldown

**Q:** The final combined qa-verifier pass (opus, full suite run: 1684/1685, only Test D fails) found `combat_resilient` is priority-2 and has no cooldown, so a Standing 3+ `resist_fear` echo taking regular hits could say it on nearly every one of its turns, potentially crowding out fear/morale/guidance barks. No test can observe this — it needs a real fight to judge. Ship as-is and judge in the Phase 8 manual playtest, or add a cooldown now before shipping?
**A:** Add a cooldown now, before shipping.
**Source:** Jeff, 2026-09-22
**Date:** 2026-09-22

---

### 48. resist-fear-wire-two-more-paths

**Q:** The same qa-verifier pass found 2 more fear-gain paths still skip `resist_fear`, same shape as sites already fixed: `CombatRoundEmotionService.gd:131` (fear spread to the party when a real ally is KO'd mid-fight) and `EncounterSetupService.gd:550` (surprise/ambush fear at fight start). Fix these too, or stop the resist_fear thread here and file them as follow-up?
**A:** Fix these 2 as well.
**Source:** Jeff, 2026-09-22
**Date:** 2026-09-22

---

### 49. phase6-fix-missing-live-styles-before-phase7

**Q:** Phase 6's combined verification measured 40 real live fights and found 3 of the 10 movement styles never appear at all: `lateral` (no live goal source — only built for `reposition`/`regroup`, which live combat never creates, only the stage-explore adapter does), `low_exposure` (silently loses a dedup tie against `safe` whenever a board has no known hazards — same bug class decision #16 already fixed elsewhere in the option-generation pipeline), and `retreating` (needs a collapse state, legitimately rare — 0 collapses occurred in the 40-fight sample, not confirmed as a bug). This is the story's headline claim ("Echoes visibly vary in how they act on a shared purpose") not fully holding in live play. Fix the 2 confirmed bugs now before Phase 7, or file as follow-up and continue?
**A:** Fix now, before Phase 7. `retreating` is not being fixed — its rarity is expected given its real trigger condition, not confirmed as a defect.
**Source:** Jeff, 2026-09-23
**Date:** 2026-09-23

---

### 50. phase6-fix-followup-tasks-file-now

**Q:** Phase 6 also found `docs/stories/v2-combat-003.5/followup-tasks.md` has wrong information: task #10's premise (only 4 of 10 vector origins are summon-able) was tested directly and found false — `class_origin_weights` has had all 10 since before this story, confirmed by summoning 200 test Echoes; task #1 (`perceived_actors` script error) is already fixed but still listed open; several cited `ANSWERS.md` entry numbers (#63/#65/#66) don't exist (`ANSWERS.md` ends at #62). Fix the file now, or leave it for Phase 9's docs pass?
**A:** Fix it now.
**Source:** Jeff, 2026-09-23
**Date:** 2026-09-23

---

### 51. lateral-fix-must-not-relabel-identical-route

**Q:** qa-verifier's review of decision #49's fix found `lateral` doesn't create real variety in ~40% of its live appearances — it wins a dedup tie against an identical, unchanged `intercept`/`screen` route (same destination, same path, just renamed), because `lateral` sits earlier in `STYLE_ORDER`. This removed real `intercept` variety that was already working (113→69 moves) and violates decision #11's "no metadata-only styles" rule. Should a `lateral` candidate identical to an existing route be blocked from surviving dedup under the wrong name?
**A:** Yes, block it. Fix now, before shipping.
**Source:** Jeff, 2026-09-24
**Date:** 2026-09-24

---

### 52. low-exposure-hazard-safety-stays-first

**Q:** The `low_exposure` fix's new eligibility test allows a candidate to win on `exposure == primary and threat_distance > primary` with no hazard-count condition — meaning `low_exposure` could in principle pick a route through MORE known hazards than the primary, purely to stay farther from a live hostile. Should hazard avoidance stay the strict first priority, or is distance-from-threat allowed to outweigh it?
**A:** No — hazard safety stays first. Distance-from-threat is an additional tiebreak only, never allowed to override known hazard avoidance.
**Source:** Jeff, 2026-09-24
**Date:** 2026-09-24

---

### 53. lateral-guard-extended-to-all-candidates

**Q:** Decision #51's fix blocked `lateral` from stealing the name of the purpose's PRIMARY route only. The build flagged a narrower, unmeasured edge case: `lateral` could theoretically still collapse onto and steal the name of a different EXTRA candidate (`conservative`, `forceful`, `overcommitted`, `low_exposure`) instead, since the guard only compared against the primary. Not confirmed to happen in live play. Fix now, or file as follow-up?
**A:** Fix it now too — extend the same guard to compare against every candidate, not just the primary.
**Source:** Jeff, 2026-09-24
**Date:** 2026-09-24

> **Correction, 2026-09-24**: qa-verifier's final combined review found this case was NOT
> theoretical — instrumented across 21 live fights, the wider guard fired 24 times against a
> non-primary candidate that decision #51's primary-only guard would have missed. Good call to
> fix it now rather than defer.

---

### 54. lateral-fix-recorded-values-signed-off

**Q:** The complete lateral/low_exposure fix thread (decisions #49-53) moves 15 recorded test values — 11 `fingerprint_<mode>` values and 4 `combat_baseline/emotion_trace_*` values — all cleanly attributed to one cause (the `lateral` extra candidate now correctly existing and being chosen in live combat; the shared-routes refactor and the `low_exposure` reorder were independently confirmed to move nothing). No fixture flips from a win to a loss. Sign off on re-recording?
**A:** Yes, re-record all 15.
**Source:** Jeff, 2026-09-24
**Date:** 2026-09-24

---

### 55. lateral-fix-faster-fights-accepted

**Q:** As a side effect of the fix, 2 fixture fights now resolve faster because Echoes route better with the corrected styles: PURSUE 7→5 rounds, PURIFY_SHRINE 9→8 rounds. This can shift reward payout/grade, same class of side effect already flagged and filed separately (follow-up tasks #2, #4 — reward-formula sensitivity to fight speed). Accept as-is, or investigate before moving on?
**A:** Accept it. Matches this story's own precedent (decision #4) — reward-formula sensitivity to fight speed is a separate, already-filed concern, not something to fix here.
**Source:** Jeff, 2026-09-24
**Date:** 2026-09-24

---

### 56. lateral-test-failure-message-fixed

**Q:** qa-verifier's re-record verification found the new end-to-end test (`_t_generate_options_guards_lateral_against_full_candidate_set`) correctly catches the guard regression, but fails at the wrong line with a misleading message — the `forceful` cell being stolen makes the test's own setup check ("fixture must reach both direct and forceful") fail first, so the real assertion never runs and the failure reads as a bad fixture rather than the actual bug. Fix the message now, or accept and commit?
**A:** Fix the message now.
**Source:** Jeff, 2026-09-24
**Date:** 2026-09-24

---

### 57. lateral-guard-cell-only-comparison-confirmed

**Q:** A Codex review comment on PR #77 raised the same ambiguity qa-verifier's second review flagged as unresolved (finding 5): the `lateral` dedup guard (decisions #51/#53) compares only the destination CELL, not the full route (cell + path). A flank that reaches the same cell as another candidate via a genuinely different path still gets blocked, even though the route itself is mechanically distinct. Keep the simpler cell-only comparison, or compare full routes so a same-destination-different-path flank can survive as real variety?
**A:** Keep cell-only comparison. No code change — a flank landing on the exact same spot as another option doesn't read as a distinct flank on screen, even via a different path.
**Source:** Jeff, 2026-09-24
**Date:** 2026-09-24

---

### 58. guide-spirit-escort-capacity-bug-fix-before-phase8

**Q:** Phase 7's full-regression/measurement pass found a real, pre-existing bug, unrelated to this story's own scope: in GUIDE_SPIRIT escort fights, the spirit actor is built with `is_structure: true`, and `MovementProfileService.derive_profile()` checks that flag BEFORE checking any movement-capacity override — so the spirit always gets capacity 0 and can never walk to its destination. Confirmed broken since a July commit (V2-COMBAT-002 Slice 3), well before this story. About half of all GUIDE_SPIRIT fights are escort mode, so Jeff's own Phase 8 in-game playtest would likely hit this. A second, related blocker was also found: even with capacity restored, a guarding/protecting Echo standing on the spirit's path can block it indefinitely (the executor doesn't route around occupied cells by design). Fix now before Phase 8, or file as follow-up and playtest with the known caveat?
**A:** Fix it before Phase 8. Out of this story's original scope, but the playtest should exercise real gameplay, not a known-broken path.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

> **Progress, 2026-09-25**: the capacity fix (authored_override checked before is_structure) is
> built, tested, and confirmed working live — escort fights went from 0/11 winning via
> spirit_escorted to 2/11 in an 11-fight sample, spirit genuinely accumulates movement across
> turns. No fingerprint moved (the existing fixture only covers protect mode, not escort, so
> nothing to re-record). One real problem remains: a guarding Echo can block the spirit's next
> cell indefinitely (measured: one fight blocked 20 rounds straight), because party AI currently
> has no reason to ever vacate that cell. This is a party-behavior design question, not a code
> bug — see decision #59.

---

### 59. guide-spirit-blocking-routed-to-sr-game-designer

**Q:** A guarding/protecting Echo can permanently block the escort spirit's path by standing on its next cell (party AI has no reason to move off it). Three shapes of fix were proposed: (a) Echoes on escort leave the spirit's next cell out of their guard ring, (b) a yield/swap rule where a blocking Echo trades places with the spirit, (c) both plus reinstating the pre-July side-step behavior (the spirit used to route around occupied cells before a live-movement cutover removed that). This changes real party AI behavior, not just a code fix. Quick surgical fix now, route to sr-game-designer for a proper design pass, or accept as-is and file as follow-up?
**A:** Route to sr-game-designer for a proper design pass — this affects party AI behavior broadly, matching how this story has routed other genuine design forks (e.g. decision #8).
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

> **Result:** sr-game-designer recommended (b) — a deterministic yield/swap, firing every round
> with no threshold: when the spirit's planned next cell is occupied by a living friendly
> non-structure Echo, the spirit and the Echo trade positions as part of the spirit's own
> activation (no action/movement cost to the Echo). Confirmed no narrative/mechanical case makes
> indefinite blocking correct (escort/protect only require reach within `escort_radius`, not
> occupying one specific tile) — ruling out a grace-period design. (a) alone was rejected
> (depends on an unconfirmed activation-order precondition); reinstating the old side-step (part
> of (c)) was rejected (mechanics-developer already found free-cell routing often has no option
> once the guard ring fills). See decision #60 for the added feel-check step before build.

---

### 60. guide-spirit-swap-design-adds-feel-check

**Q:** sr-game-designer's yield/swap design has real player-facing implications (an Echo visibly stepping aside for the spirit, every round it happens). Add a game-feel-developer readability check before mechanics-developer builds it?
**A:** Yes — "if needed also game feel, we want this to feel and play right." Matches this story's own precedent (decision #10) of a feel check before a feasibility/build pass.
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

> **Result:** do not ship silent. The existing token-movement lerp already prevents a teleport
> read (no code path in this game ever snaps an actor's position), but a repeating, unmarked swap
> reads as a stuck loop rather than "the party is protecting the spirit," especially in the worst
> case (measured: the same Echo could swap every round for 20 rounds straight). Minimal fix: one
> new bark context (`spirit_escort_yield` or similar), fired via the existing
> `NarrativeVoiceService.fire_spirit_bark()` — already used for this exact actor, deterministic
> rotation avoids repeating the same line, no new system needed. Both the swap mechanic and this
> bark addition are now fully specified and go to `mechanics-developer` as one build.

---

### 61. spirit-barks-added-to-tier-2-before-commit

**Q:** qa-verifier's combined-tree review of the swap+bark+capacity fix (SHIP verdict) found an adjacent gap: none of the 5 `spirit_*` bark contexts (`spirit_escort_start`, `spirit_first_adjacency`, `spirit_guide_win`, `spirit_killed`, and the new `spirit_escort_yield`) are listed in `data.voice.bark_tiers`. `NarrativeVoiceService.apply_round_bark_budget()` resolves any unlisted context to the lowest priority tier, so in a round with 3+ higher-priority barks already queued, a spirit bark — including the new yield bark decision #60 explicitly required to "not ship silent" — is silently dropped before the player ever sees it. This is pre-existing across all 5 contexts, not introduced by this build. Ship as-is and file a follow-up, fix the tier now, or accept the gap permanently?
**A:** Fix the tier now, before commit — cover all 5 `spirit_*` contexts (not just the new one), assigned to tier 2 (matching other narratively-important-but-not-urgent barks like `combat_fear_rising`/`combat_inspired`, one tier below true mechanical alerts like `combat_last_stand`/`combat_ko`).
**Source:** Jeff, 2026-09-25
**Date:** 2026-09-25

---

### 62. pr79-ultrareview-nits-fixed-before-merge

**Q:** `/ultrareview` on PR #79 returned 2 nit-severity findings, both in `core/movement/GuideSpiritActivationService.gd`, both verified real against source: (1) `_post_swap_context()` did a full recursive deep-copy (`context.duplicate(true)`) of the whole movement context every escort-yield round, when only the `occupancy` sub-dict is ever mutated; (2) the swap-eligibility check (`_yield_candidate`) ran twice per swap round — once inside `activate_spirit()`, again in `yielded_occupant()` called by the caller right after. Neither is a correctness bug — both are wasted work that repeats every round a swap fires (up to 20 rounds straight in the worst case measured in decision #58's result). Fix now before merge, file as follow-up, or accept as negligible?
**A:** Fix both now, before merge.
**Source:** Jeff, 2026-09-26
**Date:** 2026-09-26

> **Result:** (1) fixed with a shallow top-level `context.duplicate(false)` plus an explicit
> `.duplicate()` of only the `occupancy` dict before mutating it — every other nested field stays
> shared by reference, safe because nothing downstream (`ActivationService.activate()` /
> `MovementExecutor`) ever writes into the context it receives (qa-verifier traced every
> consumer to confirm read-only). (2) fixed via an optional trailing `out_yield_cache` param on
> `activate_spirit()` and a matching `in_yield_cache` param on `yielded_occupant()`, both
> defaulted to `{}` so every existing call site (including all tests) is unaffected and still
> exercises the fallback recompute path. Two alternatives were considered and correctly rejected:
> attaching the yielder to the returned `result` dict (would fail `ResultContract.validate()`'s
> exact-field check — confirmed by reading the validator), and a static cache keyed by
> `activation_id` (tests reuse the same default id across calls, risking stale cross-call
> contamination). qa-verifier reviewed the combined fix independently: SHIP, both claims confirmed
> via source-level tracing (not just tests — Dictionary `!=` in GDScript is by-value, so the
> existing tests cannot by themselves distinguish a shallow copy from a deep one; the safety proof
> is the downstream-mutation trace, not the green suite). One informational-only adjacent finding
> repeated (the same stale "DORMANT" header comment on `GuideSpiritActivationService.gd` already
> known from earlier in this thread) — not a defect of this fix, no action taken.

---

### 63. ashen-hallow-board-sizing-filed-as-followup

**Q:** During Phase 8's in-game playtest, Jeff observed that GUIDE_SPIRIT boards forced via the debug console (`combat_objective guide_spirit protect nojoin`) on realm.01 ("Ashen Hallow") looked short and narrow in both dimensions, not stretched 5x in one axis as designed. Investigated and confirmed: `StageTerrain.generate()`'s plateau count/size comes only from the realm's virtue-specific terrain signature (`data/balance.json`), with no scaling relative to the board-stretch override. Ashen Hallow's virtue is `courage`, whose signature authors only 2-3 small plateaus (max ~16x14) — on a board stretched to ~18x90, these land clustered together by chance, leaving most of the nominal board an empty void the player never sees filled. Jeff's realm 2 (wisdom virtue, 5-6 plateaus + richer islands) filled a stretched board correctly. This is a pre-existing gap in the V2-STAGE-004 board-stretch mechanism (PURSUE/GUIDE_SPIRIT), not something this story's GUIDE_SPIRIT fix introduced. Fix now, or file as follow-up?
**A:** File as follow-up. Out of scope for this story.
**Source:** Jeff, 2026-09-26
**Date:** 2026-09-26

> **Result:** filed as follow-up task #14 in `docs/stories/v2-combat-003.5/followup-tasks.md`
> (`task_ashen_hallow_board`) — root cause, evidence, and two candidate fix shapes recorded there
> for whoever picks it up.

---

### 64. large-board-camera-filed-as-followup

**Q:** While retesting GUIDE_SPIRIT escort mode on realm.02 (a genuinely large, correctly-stretched board — one spawn landed at column 98), Jeff found the combat camera does not handle a board this large well. Pre-existing UI/camera behavior, unrelated to this story's GUIDE_SPIRIT escort-yield subject. Fix now, or file as follow-up?
**A:** File as follow-up. Out of scope for this story.
**Source:** Jeff, 2026-09-26
**Date:** 2026-09-26

> **Result:** filed as follow-up task #15 in `docs/stories/v2-combat-003.5/followup-tasks.md`
> (`task_large_board_camera`) — reproduction steps and the owning script (to be located) recorded
> there for whoever picks it up.

---

### 65. planning-graph-narrowing-is-dormant-not-a-phase-3c-defect

**Q:** Follow-up #9 (`task_e06782cb`) named "planning graph narrowing" as a possible live defect:
`MovementOptionService._planning_walkable()` intersects `authoritative_walkable` with
`perceived_planning_cells`, which could silently shrink a mover's plannable cells. Is this a
Phase 3c live-wiring bug, and should it be fixed or just logged?
**A:** Investigated by `game-orchestrator` before hand-off, confirmed by `mechanics-developer`
against current source. Not a live defect. The intersection has existed since the service's
first commit (92b418d, V2-COMBAT-002 Slice 2) — `MovementOptionService.gd:896-905`. Phase 3c only
wired the already-existing `generate_options()` into the live path; it did not add the
intersection. Every live call site that builds a `MovementContext` passes the SAME dictionary
for both `authoritative_walkable` and `perceived_planning_cells`
(`LiveMovementContextService.gd:147-148` in `prepare_live_movement_context`, and
`LiveMovementContextService.gd:600-601` in `prepare_guide_spirit_activation_context`), so the
intersection can never narrow anything on a live board today. No perception-limiting system
(fog of war, perception radius, line-of-sight) exists anywhere in `core/` or `data/`.
`CombatPressureService._truthful_region()` (`CombatPressureService.gd:826-830`) also reads
`perceived_planning_cells` for goal-region filtering, confirming this is a deliberate,
load-bearing contract field — a planned seam for a future perception system, not a stray
parameter. Jeff decided: add defensive rejection-logging now anyway, ahead of any perception
system landing, so that system fails loud instead of silent from day one. Not a bug fix.
**Source:** Jeff (via game-orchestrator relay), 2026-09-27
**Date:** 2026-09-27

> **Result:** `mechanics-developer` added `LiveMovementContextService._log_perception_narrowing()`
> (`LiveMovementContextService.gd:316-331`), called once per activation at the end of
> `_movement_live_options()` (`LiveMovementContextService.gd:306`). It compares the same
> `authoritative_walkable` / `perceived_planning_cells` pair `_planning_walkable()` intersects and
> logs `movement.options_rejected` with `reason: "perception_narrowed_planning_graph"` the first
> time a cell is dropped. Placed after the per-goal loop, not before, so the existing follow-up
> #8 test (`movement_option/live_options_logs_unreachable_destination_region`) keeps finding its
> own `no_viable_option` entry first — logging order was the only thing that could have collided
> with that test, since both entries share the `movement.options_rejected` type. Two new tests
> added to `tests/MovementOptionTests.gd`: `live_options_logs_perception_narrowing` (narrows a
> cell off the chosen route, asserts the log fires even though the goal still succeeds) and
> `live_options_silent_when_perceived_matches_walkable` (the real, only shape in play today —
> asserts no log fires). Logic in the pure `core/movement/` layer (`MovementOptionService.gd`) is
> untouched, per that file's own header: it is "the DORMANT-by-design pure layer" and the adapter
> file is the named place for anything that reads live state or logs.

---

### 66. commitment-progress-ratio-unit-mismatch-fixed

**Q:** Follow-up #7 (`docs/stories/v2-combat-003.5/followup-tasks.md`) tracked decision #30's
unit mismatch: `BehaviorArbiter._spatial_utility()` divided `option["commitment"]` (a move-cost,
`BehaviorArbiter.gd:1489` old code) by `option["progress_origin_distance"]` (a pure cell count,
`MovementOptionService.gd:781`). Decision #30 said this had "no live impact today." Was that still
true?
**A:** No. It was correct only for terrain-cost variance (terrain cost is uniform, always 1, at
every live call site). It was NOT correct for the hostile-control edge surcharge, which is live:
`MovementOptionService._build_control()` adds `+1` to `route_cost` per edge adjacent to a
controlling hostile (`MovementOptionService.gd:822-893`). `route_cost` feeds `commitment`
(`MovementOption.gd:149`) but never `progress_origin_distance`. So a route running beside an enemy
already scored a harsher commitment penalty than an equal-length hostile-free route, from mixed
units alone, not from any real cost/benefit tradeoff. Fix: replace `option["commitment"]` with
`(option.get("path", []) as Array).size()` in the ratio's numerator — a pure cell count matching
`progress_origin_distance`'s unit, restoring apples-to-apples without a new tuning value. Closes
follow-up #7.
**Source:** Task brief (follow-up #7), verified against current source, 2026-09-28
**Date:** 2026-09-28

> **Result:** `mechanics-developer` changed `BehaviorArbiter.gd:1489-1495` (line numbers after the
> edit shifted to 1493-1496; the brief's 1489-1491 was the pre-edit location, no other drift). Added a
> `route_cell_distance` local from `option.get("path", [])`, defaulting to 0 for hand-built
> fixtures without a `"path"` key. `tests/MovementArbitrationTests.gd`: `_t_spatial_base_terms`'s
> `"commitment"` case gained a 4-cell `"path"` so its `-2.0` assertion still holds under the new
> formula; all other hand-built-option tests in that file use delta or cancelling comparisons and
> needed no change. `MovementOptionTests.gd`, `MovementStyleServiceTests.gd`,
> `MovementSlice2ContractTests.gd`, `MovementContractTests.gd` do not call `_spatial_utility()` and
> are unaffected. New regression test `_t_commitment_ratio_ignores_hostile_surcharge` builds one
> hostile-adjacent and one clean fixture at the same distance/capacity, matches an exposed option
> to a clean option by destination and path length, confirms their `commitment` (cost) values
> differ (proving the surcharge fixture is live) while their `progress_origin_distance` matches,
> then asserts the resulting commitment scoring TERM is now equal for both. Filtered suite
> `tests movement_arbiter`: 27 total / 26 passed / 1 failed before the fix (baseline), 28 total /
> 27 passed / 1 failed after (new test added, same pre-existing `avoid_overcommit_stays_proportionate`
> failure, untouched — out of scope per follow-up #7 and decision #29/#38).

---

### 67. behaviorarbiter-file-size-extraction-candidates-3-and-4

**Q:** Follow-up #11 (`docs/stories/v2-combat-003.5/followup-tasks.md`) investigated
`BehaviorArbiter.gd`'s growth past its ~1,000-line soft guard and proposed extraction candidates.
Which candidates were extracted, and what is the file's line count now?
**A:** Candidates #3 (board/threat assessment) and #4 (action-candidate generation) were
extracted. Candidates #1 (bias application: `_apply_bias`, `_apply_vow_bias`, `_apply_bond_bias`)
and #2 (movement style: `_style_alignment`, `_style_urgency_factor`,
`_movement_style_bond_pressure`, `_route_style_of`) remain in `BehaviorArbiter.gd` — Jeff decided
to defer them, out of scope for this pass.
**Source:** Task brief (follow-up #11 continuation), verified against current source, 2026-09-28
**Date:** 2026-09-28

> **Result:** `mechanics-developer` created `core/actors/behaviors/BoardAssessmentService.gd`
> (candidate #3: `build_board_summary`, `is_cover_destination`, `line_is_blocked`,
> `is_in_leader_radius`, `situational_bonus`, all `static`) and
> `core/actors/behaviors/ActionCandidateGenerator.gd` (candidate #4: `generate_candidates`,
> `stationary_candidate`, `route_candidate`, `add_perceived_target_health`,
> `apply_stationary_identity`, `append_legacy_purifier_candidate`, `resolve_skill_base`, all
> `static`). Both classes hold no `ConfigService`; every config value (`situational_muls`,
> `guard_range`, `threat_threshold`, the skill-weight tables) arrives as a parameter resolved by
> `BehaviorArbiter._cfg_get()`. `BehaviorArbiter.gd` gained two `preload()` consts
> (`BoardAssessmentServiceScript`, `ActionCandidateGeneratorScript`) and now calls through them at
> every former call site; `_get_most_wounded_enemy()` was converted from an instance method to
> `static` (unchanged body) so the new generator file could call it without an arbiter instance.
> `BehaviorArbiter.gd`: 1,967 code lines before, 1,419 after (grep -vcE '^\s*(#|$)' count).
> `BoardAssessmentService.gd`: 247 code lines. `ActionCandidateGenerator.gd`: 330 code lines.
> Five test call sites were repointed from private-method / `.call()` string-dispatch onto the new
> static functions: `DivergenceDetectorTests.gd`, `MaturityExpressionTests.gd`,
> `LeadershipEmotionTests.gd` (two sites). Filtered suites unchanged from baseline: `divergence`
> 25/25, `leadership` 21/21, `expr` 38/38, `movement_arbiter` 27/28 (same pre-existing
> `avoid_overcommit_stays_proportionate` failure, decisions #29/#38, untouched). Candidates #1 and
> #2 stay for a future pass if Jeff opens one.

---

### 68. vector-variance-wont-fix-trait-nudge-already-satisfies-decision-36

**Q:** Followup #10. Two Echoes with the same `class_origin` get byte-identical `vector_scores`
from `data.vectors.archetype_init`. Decision #36 requires two new Echoes to never move
identically at Standing 1. Does the shipped `trait_nudge` mechanism already meet decision #36, or
does `archetype_init` need its own per-Echo variance added on top?

**A:** Won't-fix. `trait_nudge` already satisfies decision #36 as Jeff stated it. No further
design work is needed.

Decision #36's requirement is that movement must visibly differ, not that `vector_scores` must
differ. `vector_scores` are never shown to the player as a raw number — only movement behaviour
and derived labels are visible, so a `vector_scores` difference with no behaviour difference would
not even be visible.

`docs/movement-model.md` §10.4 lists what should separate two Echoes sharing one vector
direction: Calling, archetype, traits, bonds, fear and morale, vow state, equipment, objective,
terrain. Vector-score variance is not on this list. Traits are.

`trait_nudge` (`core/actors/behaviors/MovementStyleService.gd:182-185`) adds each Echo's own
courage/wisdom/faith straight into the movement-style score. It is not scaled by `vector_scores`.
Weight per trait: 0.20 for that trait's dominant style, 0.08 for its supporting style
(`data.actor.movement_style_weights.trait_nudge`, `data/balance.json`).

`courage`/`wisdom`/`faith` roll independently per Echo from real RNG, range 30-70
(`core/sanctum/EchoFactory.gd:71-73`), before and separate from the `class_origin` roll. Two
Echoes matching on all three trait values happens about once in 68,921 rolls (41³). Two
same-`class_origin` Echoes will almost always get different `trait_nudge` contributions.

Confirmed against `data.vectors.archetype_init` in `data/balance.json`: a Standing-1 Echo's
dominant vector seeds at 60.0, not near zero — the correction note under decision #36 already
recorded this. At that seed, `trait_nudge`'s dominant-style contribution (6.0-14.0 for a trait
value of 30-70) is a meaningful share next to the vector-driven contribution (example: pillar at
60.0 × 0.5 weight for `cohesive` = 30.0). That is enough to change which style wins between two
same-origin Echoes in most cases.

Traits also drift slightly on rank-up (`ProgressionService._compute_drift`, per the
`trait_nudge` config comment in `balance.json`), so the trait-driven signature grows with
Standing — matching decision #36's "grows with maturity" requirement. `vector_scores` stay flat
per origin until the Echo's own play diverges them.

Adding a second, separate offset on `archetype_init` would re-solve an already-solved problem. It
would not be visible to the player by itself, since raw `vector_scores` are never shown. It would
also risk moving shipped balance and any fixture that reads `vector_scores` directly — including
the `dominant_key()` tiebreak call sites fixed in decision #69 below, and calling-milestone
checks.

**Source:** sr-game-designer, 2026-09-28
**Date:** 2026-09-28

---

### 69. dominant-key-tiebreak-extended-to-all-10-vectors

**Q:** Followup #10. `GridService.dominant_key()` is called with a hardcoded 4-vector tiebreak
list at three sites (`GridService.gd:632`, `CombatState.gd:172`, `ShrineService.gd:35`). The
other 6 vectors (opportunist, strategist, skeptic, mediator, devoted, nurturer) can never win an
exact-value tie there, even though `dominant_key()` scores all 10. What order should the full
10-vector tiebreak use at each site?

**A:** Extend each site's existing list to 10 vectors. Keep the current 4 vectors in their
current relative order at every site — do not reorder them. Append the 6 missing vectors in one
fixed order: strategist, skeptic, devoted, opportunist, mediator, nurturer. This order matches
their relative order in `docs/movement-model.md` §10.4's vector table, so the new tail is
traceable to a written source rather than invented.

`GridService.gd:632` and `CombatState.gd:172` (same list today: vanguard, seeker, protector,
pillar) become:

```
vanguard, seeker, protector, pillar, strategist, skeptic, devoted, opportunist, mediator, nurturer
```

`ShrineService.gd:35` keeps its own reversed order — its own comment states this is intentional
and must not match the other two sites. Its list becomes the exact reverse of the list above, so
its existing 4-vector tail order (pillar, protector, seeker, vanguard) stays unbroken and
unchanged:

```
nurturer, mediator, opportunist, devoted, skeptic, strategist, pillar, protector, seeker, vanguard
```

Why not reorder the original 4: ANSWERS.md #60 already chose to keep these lists as they were
rather than change them, when it unified the three copies into one `dominant_key()` helper.
Reordering the 4 existing vectors now would change tie outcomes that already ship, for no reported
problem. Only the missing 6 are broken. Only they need adding.

**Source:** sr-game-designer, 2026-09-28
**Date:** 2026-09-28

---

## Camera feel sign-off

Numbers below are `game-feel-developer` sign-off for the shared `BoardCamera.gd` controller
(ANSWERS.md #74-77, plan `you-are-game-orchestrator-read-soft-crayon.md`). This is a design pass.
No code was changed. `ui-ux-designer` builds against these numbers.

### 70. camera-min-zoom-formula-content-derived

**Q:** What formula sets `min_zoom` per screen, so Combat/Stage boards (18 to ~100 cells on one
axis) and Sanctum's small fixed floor each get a correct zoom-out floor, instead of one shared
hardcoded range?

**A:** For Combat and Stage:

```
min_zoom = clamp(
    (viewport_min_dimension / max(content_span.x, content_span.y)) * 0.90,
    absolute_floor,
    absolute_ceiling
)
```

- `viewport_min_dimension` = `min(get_viewport_rect().size.x, get_viewport_rect().size.y)`, read at
  runtime, recomputed on resize (same pattern as Sanctum's existing
  `_on_spatial_layer_resized` → `_recompute_floor_bounds` → `_clamp_camera_to_floor` chain).
- `content_span` = the real measured board extent in pixels, from `map_to_local()` corners — both
  screens already compute this correctly today (Combat: `_board_span_px`; Stage: `map_to_local`
  calls in `StageExploreScreen.gd`).
- `0.90` is the safety factor. It is a margin, not a shrink: at the exact-fit zoom
  (`viewport / content`), the board fills the viewport edge-to-edge with zero room. `0.90` backs off
  10%, so the full board is visible with a small border at min zoom, on both axes, on any board
  shape. A factor below 1.0 zooms further OUT, not in — confirmed by checking the direction:
  smaller `min_zoom` shows more empty margin around the fully-visible content, never crops it.

Worked check against real board sizes (tile size confirmed `Vector2i(128, 64)` for both screens,
`ui/screens/combat/CombatBoardScreen.tscn` and `ui/screens/venture/StageExploreScreen.tscn`;
`viewport_min_dimension` taken as `720`, `project.godot`'s base viewport height):

| Board (cols×rows) | Content span (px) | Exact-fit zoom | min_zoom (×0.90) |
|---|---|---|---|
| Combat 18×18 (small) | 2304×1152 | 0.313 | 0.28 |
| Combat 28×28 (large normal) | 3584×1792 | 0.201 | 0.18 |
| Combat 100×18 (stretched GUIDE_SPIRIT repro) | 7552×3776 | 0.095 | 0.086 |
| Stage 30×30 (min map) | 3840×1920 | 0.188 | 0.17 |
| Stage ~55×40 (late-stage bump) | 6080×2560 | 0.118 | 0.11 |

This confirms the old hardcoded `_ZOOM_MIN = 0.4` (`CombatBoardScreen.gd:156`) could never reach
far enough for the 100×18 repro board (needs ~0.09) — this is the root numeric cause of follow-up
#15's original bug, confirmed independently of the follow-logic fix already scoped.

**Absolute floor/ceiling (clamp bounds, per screen class):**

| Screen | absolute_floor | absolute_ceiling |
|---|---|---|
| Combat | 0.05 | 0.35 |
| Stage | ~~0.08~~ | ~~0.30~~ |

> **Superseded for Stage by #100 (2026-10-05):** Jeff decided Stage uses Combat's clamp, floor 0.05 and ceiling 0.35. The Stage row above is kept as history only.

`absolute_floor` is a safety net against a pathological board (larger than any config currently
allows) computing an unreadable near-zero zoom. `absolute_ceiling` guarantees `min_zoom` never rises
above a level that would remove pan headroom on the smallest legal board for that screen — Stage's
ceiling is tighter than Combat's because Stage's map never shrinks below `MIN_WIDTH`/`MIN_HEIGHT` =
30×30 (`StageExploreModel.gd:33-34`), so it never needs Combat's small-board 18×18 case.

**Sanctum does not use this formula.** Its floor is small, fixed-shape, and rendered from a
`TileMapLayer.get_used_rect()` that rarely changes size mid-session. Decision #72 keeps Sanctum on
its existing discrete zoom-level list instead.

**Source:** game-feel-developer, 2026-09-29
**Date:** 2026-09-29

---

### 71. camera-max-and-default-zoom-per-screen

**Q:** What are `max_zoom` and `default_zoom` per screen, given Jeff's explicit ask for a visibly
closer default on all three, without losing board-edge readability?

**A:**

| Screen | Old default | New default | max_zoom (old → new) |
|---|---|---|---|
| Sanctum | 1.5 | 2.0 | 2.0 → 2.5 |
| Combat | 1.0 | 1.3 | 2.0 → 2.2 |
| Stage | 0.55 | 0.75 | none → 1.5 |

**Sanctum:** keep the existing discrete list, add one level, shift default up by one step:

```
_zoom_levels = [0.5, 1.0, 1.5, 2.0, 2.5]   # was [0.5, 1.0, 1.5, 2.0]
_zoom_index default = 3                     # 2.0×, was index 2 (1.5×)
```

This preserves the same shape as today — 3 levels below default, 1 above — instead of putting
default at the top of the range with no zoom-in headroom left. `min_zoom` (0.5, the bottom level)
is unchanged; Sanctum's floor is small enough that 0.5 already shows it in full.
`_detail_zoom = Vector2(2.9, 2.9)` (the tap-occupant focus zoom) is untouched — it is not part of
this ask.

**Combat:** `default_zoom = 1.3` (30% closer than 1.0). At 1.3, the visible width on a 1280px-wide
viewport is 985px — already less than a normal 18×18 board's 2304px content span. The old default
of 1.0 (1280px visible) *also* didn't show the full board width; players already rely on pan and
the new selection-lock to reach the edges. Moving to 1.3 does not newly break edge access — it was
never fully visible at default zoom, on any board size in the current 18-28 config range.
`max_zoom = 2.2`, a small bump over the current 2.0, to keep one step of further zoom-in headroom
above the new, closer default (same ratio-preservation reasoning as Sanctum's change).

**Stage:** `default_zoom = 0.75` (up from `_EXPLORE_INITIAL_SCALE = 0.55`). Flag: the current 0.55
has a direct, named justification in `StageExploreScreen.gd`'s own comment — showing the "island
silhouette" around the party's starting position. At 0.75, visible width on a 30×30 map drops from
~2327px (61% of the 3840px content span, at 0.55) to ~1707px (44%). This is a real trade — less of
the surrounding shape is visible by default. I recommend 0.75 as the starting number, since Stage
is gaining manual zoom for the first time and the player can now zoom back out on demand (a
capability the 0.55 default didn't need to compensate for alone). This specific number is more a
feel judgment made in-engine than a value derivable from geometry — flagging it for a quick
in-engine look during Story 3, not holding it back as blocking.
`max_zoom = 1.5` — lower than Combat's 2.2. Stage shows one party token, not a multi-actor tactical
board; there is no dense-read reason to zoom in as far as Combat. Raise this later if Jeff wants
symmetry with Combat instead.

**Source:** game-feel-developer, 2026-09-29
**Date:** 2026-09-29

---

### 72. camera-follow-tuning-and-discrete-zoom-stays-sanctum-only

**Q:** Keep or retune `FOLLOW_ACTOR`'s lerp speed and the manual-override resume delay? Should
Sanctum's discrete zoom-level snapping become a shared discrete/continuous toggle on `BoardCamera`,
or stay Sanctum-only?

**A:**

- **`FOLLOW_ACTOR` lerp speed:** keep `_PURSUE_FOLLOW_SPEED = 5.0` unchanged, now applied
  universally (every selection-lock, not just PURSUE). No reported problem with the feel itself —
  only its scope (PURSUE-only) was the bug. Retuning an already-correct value with no complaint
  against it risks a regression nobody asked for.
- **Manual-override resume delay:** keep `_PAN_RESUME_DELAY = 3.0`s unchanged, as the shared
  default across Combat and (where applicable) Sanctum. Same reasoning — proven value, no reported
  issue.
- **Discrete zoom-level snapping: stays Sanctum-side only, not a shared toggle.** (**Superseded: for the Z key by #93; the Sanctum-only discrete wheel steps by #94 and then #95.** #72 still covers: the follow lerp speed and the resume delay.) Reasoning:
  Combat and Stage need continuous pinch/wheel/wheel-drag zoom over content that varies by an order
  of magnitude (18 to ~100 cells) — a discrete level table would need to be regenerated per board
  size, which is more moving parts than the problem needs. Sanctum's discrete stepping is tied to
  its own small, fixed-shape content and its keyboard `Z`-cycle input, which has no equivalent on
  the other two screens. Building both a continuous engine and a discrete-snapping mode into one
  shared component, for one screen's benefit, adds a mode flag and two code paths for a behavior
  only one screen uses. Simpler and equally correct: `BoardCamera` exposes continuous zoom as its
  only primitive; Sanctum keeps its own discrete-step wrapper on top of it, calling the shared
  component's continuous zoom setter at its own four (now five) fixed values — exactly what it does
  today against its own inline camera code, just retargeted at the shared component instead of
  Sanctum's own `Camera2D` fields.

**Source:** game-feel-developer, 2026-09-29
**Date:** 2026-09-29

---

### 73. stage-follow-party-tween-matches-travel-duration-not-pursue-lerp

**Q:** Stage gains `FOLLOW_PARTY` as an always-on default (no manual-override window, per the
plan) — does it need the same min_zoom formula as Combat, and does it need the same continuous
`_PURSUE_FOLLOW_SPEED` lerp for camera movement?

**A:** Same min_zoom **formula** — yes, decision #70's formula is content-size-derived and does not
depend on how the tracked target moves; it applies unchanged.

Same follow **lerp**, however, should not carry over as-is. Combat's `_PURSUE_FOLLOW_SPEED = 5.0`
lerp is designed for a continuously-moving quarry, chased frame by frame. Stage's party instead
moves in discrete per-advance tweens (`_TRAVEL_DURATION = 0.5`s,
`StageExploreScreen.gd`). Applying a continuous per-frame lerp on top of a discrete hop means the
camera either lags behind and arrives late, or (if the lerp is fast) reaches the destination well
before the token's own travel tween finishes — both break the sense that camera and token moved
together, which is the "Continuity" principle this pass is meant to serve.

**Recommendation:** on each advance, tween the camera's `FOLLOW_PARTY` target position over the
same `_TRAVEL_DURATION` (0.5s) and the same easing as the party token's travel tween, so both
arrive together. Do not reuse `_PURSUE_FOLLOW_SPEED` for Stage. Manual pan/zoom clamping (the
`_PAN_MARGIN = 120.0`px pattern) ports unchanged — no new value needed there.

**Source:** game-feel-developer, 2026-09-29
**Date:** 2026-09-29

---

### 74. stage-card-select-gets-a-transition-cue-not-a-distinct-target

**Q:** (Plan's carried-forward open item.) Should Stage's echo-card tap-to-select get a distinct
visual treatment, given it resolves to the same party-centroid position `FOLLOW_PARTY` already
shows?

**A (recommendation, not final — confirm with Jeff if it changes scope):** give the tap a
distinct **transition**, not a distinct **destination**. Concretely: entering `FOLLOW_ACTOR` from a
card tap plays a faster, slightly different easing snap into position (e.g. a quick ease-out over
~150-200ms) instead of reusing whatever steady-state easing `FOLLOW_PARTY` uses ambiently. The
camera ends up in the same place either way — Stage has only one token to lock onto — but the tap
now visibly *does something* instead of reading as a no-op, satisfying this project's "Response"
game-feel principle (every touch produces immediate acknowledgement) without inventing a new zoom
level or a fake secondary target. This is presentational timing only — no simulation or state
change — so it is inside `game-feel-developer` scope as stated in the brief. Flagging it as a
recommendation, not committed scope, since the plan's own open-items list marked it explicitly
non-blocking.

Out of my scope, noted only: the plan's other open item, `_bark_popup_layer`'s screen-space
assumptions once Combat's fake camera becomes a real `Camera2D`, is a structural/technical concern
for `ui-ux-designer` to resolve during implementation — not a numbers question.

**Source:** game-feel-developer, 2026-09-29
**Date:** 2026-09-29

### 75. initiative-rows-stay-tappable

**Q:** Should initiative rows stay tappable as camera-lock targets, given that the panel rows are small on a phone?
**A:** Yes. Initiative rows stay tappable. The panel layout does not change in Story 2. The phone redesign of the panel is a follow-up task (followup-tasks.md #16).
**Source:** Jeff, 2026-10-02
**Date:** 2026-10-02

---

### 76. two-finger-pinch-pan-fixed-in-story-2

**Q:** A two-finger pinch on touch pans the board. This bug existed before Story 2. Should Story 2 fix it?
**A:** Yes. Story 2 fixes it. A two-finger pinch now zooms only and does not pan. A viewport-level finger count is reset on window focus loss, when the screen hides, and on a new encounter.
**Source:** Jeff, 2026-10-02
**Date:** 2026-10-02

---

### 77. locked-actor-death-follows-party

**Q:** What does the camera do when the locked actor dies?
**A:** The camera follows the party (`follow_party()`). It does not go `FREE`. It does not stay locked on the dead actor.
**ASSUMED, not confirmed by Jeff:** a dead actor cannot be locked. A tap on a dead-only cell does nothing. A card press for a dead echo does nothing. A living actor on the same cell wins. Jeff must confirm this. **Confirmed later: see #84.**
**Source:** Jeff, 2026-10-02 (the fallback); the orchestrator (the assumption)
**Date:** 2026-10-02

---

### 78. combat-wheel-zoom-approved

**Q:** Should Combat allow mouse-wheel zoom?
**A:** Yes (Jeff: "we can allow mousewheel zoom for combat"). The design: `BoardCamera` has opt-in wheel zoom (`wheel_zoom_step` 1.1, `zoom_to_pointer` true, `wheel_surface` is the Combat root). It zooms only when the pointer is over open board, so scrolling panels keep the wheel. A wheel event's `factor` scales the step as pow(step, factor). A factor of 0 or less counts as one ordinary notch. A `FREE` camera zooms toward the pointer. A locked camera zooms about the screen centre. Sanctum keeps its own discrete wheel zoom.
**ASSUMED, not confirmed by Jeff:** one notch is 1.1x. This is a starting value to tune in play. **Confirmed later, and the zoom made smooth: see #85.**
**Source:** Jeff, 2026-10-02 (approval); the orchestrator (the 1.1 value)
**Date:** 2026-10-02

---

### 79. space-drag-speed-differs-combat-vs-sanctum

**Q:** Space+LMB drag pans 1:1 in Combat (`space_drag_pan` is false) and 2.5x in Sanctum. Should the two match?
**A:** Not decided. This is a design call left open for Jeff. Combat treats Space+LMB the same as a plain drag. Sanctum keeps its 2.5x speed unchanged. **Decided later: see #86 (1:1 everywhere).**
**Source:** the orchestrator, 2026-10-02 (open item for Jeff)
**Date:** 2026-10-02

---

### 80. headless-screenshots-need-a-real-window

**Q:** Can `scripts/screenshot.gd` render in Godot `--headless` mode?
**A:** No. `--headless` uses a dummy renderer and gives a null texture. The older cloud method used `xvfb-run`, which exists only on Linux. On macOS, run the script from a real window: `godot --path <checkout> --resolution WxH --script res://scripts/screenshot.gd -- <fixture> <out_dir>`. A new fixture `combat_initiative_full` (8 initiative rows) was added.
**Source:** the orchestrator, 2026-10-02 (finding)
**Date:** 2026-10-02

---

### 81. app-root-shows-a-shown-screen-once

**Q:** `AppRoot._show_screen` hid every shell and then showed one, on every snapshot. This fired `visibility_changed` on the shown shell each time. `CombatBoardScreen` resets its pointer state on that signal, so a drag stopped at every auto-play step. How to fix it?
**A:** Change `AppRoot._show_screen`. It hides only the screens that are not the target. A screen that is already shown stays shown, and no signal fires. First show, screen switch and a real hide work as before.
**Dependencies found:** four handlers react to this signal. `SanctumShell._sync_ui_layer_visibility`, `RealmShell._sync_chrome_layer_visibility` and `StageExploreScreen._sync_transient_visibility` only set layer visibility (and Sanctum's `camera.enabled`); the same value is set again, so they are not affected. `EchoPartyScreen._notification` resets its chart UI (the "compare to party average" toggle) when it becomes visible. Before this change, any sanctum-family snapshot while that screen was open reset the toggle. Now it resets only when the screen really becomes visible.
**Test:** `combat_camera/app_root_rerender_keeps_drag` goes through the real `AppRoot._render_snapshot`.
**Source:** Jeff, 2026-10-03 (chose the AppRoot fix)
**Date:** 2026-10-03

---

### 82. combat-buttons-take-no-focus

**Q:** After a click on a Combat button, the button kept keyboard focus. Space (`ui_accept`), held for a Space+drag, then pressed that button again. Fix now or file?
**A:** Fix now. All 8 Combat buttons in `CombatBoardScreen.tscn` have `focus_mode = 0` (NONE): BackButton, StartCombatButton, AutoToggleButton, SpeedSlowButton, SpeedNormalButton, SpeedFastButton, RecenterButton, EndCombatButton. Cost: these buttons cannot be reached by keyboard focus.
**Test:** `combat_camera/buttons_take_no_focus_from_clicks`.
**Source:** Jeff, 2026-10-03
**Date:** 2026-10-03

---

### 83. lost-touch-release-safety-net

**Q:** A touch release that never arrives (and no focus loss, hide or new encounter follows) leaves the finger count high. Board pan and tap then stay blocked. What safety net?
**A:** A touch press with index 0 clears all pointer state first. The engine gives a new finger the lowest free index, so index 0 means no finger 0 is down; anything still recorded is from a lost release. A real pinch is not affected: its second finger has index 1. Known cost: if finger 0 lifts and lands again while another finger stays down, that other finger is forgotten.
**Test:** `combat_camera/lost_touch_release_does_not_block_board`; the pinch tests still pass.
**Source:** Jeff, 2026-10-03 (fix now); the builder (the rule)
**Date:** 2026-10-03

---

### 84. dead-actor-cannot-be-locked

**Q:** Can a dead actor be locked? (Assumed in #77.)
**A:** No. Confirmed. A board tap on a cell with only dead actors, a press on a dead echo's card, and a tap on a dead actor's initiative row all do nothing. A living actor on the same cell wins.
**Test:** `combat_camera/dead_actor_board_card_and_row_do_nothing` (board, card and row), `combat_camera/living_wins_over_dead_on_one_cell`.
**Source:** Jeff, 2026-10-03
**Date:** 2026-10-03

---

### 85. wheel-zoom-is-smooth

**Q:** One wheel notch is 1.1x (assumed in #78). Should the zoom jump or ease?
**A:** One notch is 1.1x (confirmed). The zoom eases. A notch sets a target zoom; `BoardCamera._process` moves the zoom toward it each frame (lerp speed 12 per second, a per-frame lerp, not a Tween). Notches during an ease multiply the target, so fast scrolling adds up. The target is clamped to min and max zoom. A `FREE` camera with `zoom_to_pointer` keeps the world point under the pointer still in every frame of the ease. A locked camera zooms about the screen centre. A pinch applies at once and stops a running ease. Sanctum's discrete wheel zoom is unchanged. (**Superseded by #95:** Sanctum uses the same wheel rule.)
**Test:** `combat_camera/wheel_zoom_eases_over_frames`, `combat_camera/wheel_free_zooms_toward_pointer` (checks every frame).
**Source:** Jeff, 2026-10-03 (smooth, 1.1); the builder (ease speed 12, to tune in play)
**Date:** 2026-10-03

---

### 86. every-drag-pans-1-to-1

**Q:** Space+LMB drag pans 1:1 in Combat and 2.5x in Sanctum (#79). Should they match?
**A:** Yes. Every drag pans 1:1: mouse drag, finger drag and Space+LMB drag, on every screen, Sanctum included. The world point under the pointer stays under it. `BoardCamera`'s Space+LMB motion path now calls `drag_pan()` (screen delta divided by zoom). The trackpad two-finger pan (`InputEventPanGesture`) keeps `_PAN_SPEED` 2.5.
**Test:** `board_camera.input/space_drag_pans_through_stop_chrome` now asserts the exact 1:1 pan.
**Source:** Jeff, 2026-10-03
**Date:** 2026-10-03

---

### 87. board-camera-swallows-space-for-a-focused-button

**Q:** After #81, a clicked button in Sanctum or the venture chrome keeps keyboard focus across snapshots. Holding Space to pan then presses that button (Space is part of `ui_accept`). How to stop it?
**A:** A guard in `BoardCamera._input()`, which runs before the GUI pass. When the camera is enabled and takes manual input, and a `BaseButton` has keyboard focus, the camera marks every Space key event as handled. The button never sees Space. `Input.is_key_pressed(KEY_SPACE)` still reads true, so Space+drag still pans. A focused text field (`LineEdit`, `TextEdit`) is not a `BaseButton`, so it still gets Space.
**Trade-off:** while a board camera is enabled, Space cannot activate a focused button anywhere on that screen, even with the pointer away from the board. Enter still activates it (`ui_accept` also has Enter). The guard is off when the camera is disabled. **Changed later:** modal buttons are exempt (#89); the guard also works while the camera is locked (#90).
**Test:** `board_camera.input/space_drag_does_not_press_focused_button`, `board_camera.input/space_still_types_in_focused_line_edit`.
**Source:** Jeff, 2026-10-03 (guard in BoardCamera, not `focus_mode` NONE on those screens); the builder (the rule)
**Date:** 2026-10-03

---

### 88. new-zoom-range-cancels-wheel-ease

**Q:** A wheel ease can still be running when a new zoom range is set (new encounter, resize). Should it continue?
**A:** No. `configure_zoom_range()` clears the ease target, so the new default zoom stays.
**Test:** `combat_camera/configure_zoom_range_cancels_wheel_ease`.
**Source:** QA finding, 2026-10-03; fix by the builder
**Date:** 2026-10-03

---

### 89. space-guard-skips-modal-buttons

**Q:** `ModalHost` moves keyboard focus into a modal dialog (`ModalHost.gd` `_ensure_modal_focus`). Should the Space guard (#87) block Space there?
**A:** No. The guard walks up from the focused button. If any ancestor is a `ModalHost` (a type check on the `class_name`, not a node name), the guard does nothing and the dialog button gets Space. Every modal is added under `ModalHost`'s `ModalSlot`, so this covers every modal.
**Test:** `board_camera.input/space_still_presses_modal_button` (a real `ModalHost` scene, `present_modal`).
**Source:** Jeff, 2026-10-03; the builder (the ancestor rule)
**Date:** 2026-10-03

---

### 90. space-guard-needs-only-an-enabled-camera

**Q:** In Sanctum's echo detail, the camera is locked with `manual_resume_delay` 0, so `_accepts_manual_input()` is false and the guard (#87) was off. Should it work there?
**A:** Yes. The guard now needs only `camera.enabled`. A disabled camera (hidden screen) still leaves Space alone.
**Which case applies:** the echo detail is `EchoDetailPanel` inside the SanctumScreen overlay (UILayer), not inside `ModalHost`. So the modal rule (#89) does not apply. Its buttons (DetailBack, DetailPrev, DetailNext, the Overview/Bonds/Skills tabs) take focus on a click. Result: in the echo detail, Space does not press a focused detail button. Enter still does.
**Test:** `board_camera.input/space_guard_works_in_echo_detail` (real Sanctum shell, real tap opens the detail, a click on the Bonds tab, then Space), `board_camera.input/space_guard_off_when_camera_disabled`.
**Source:** Jeff, 2026-10-03
**Date:** 2026-10-03

---

### 91. space-guard-covers-every-base-button

**Q:** Should the guard check `Button` or `BaseButton`?
**A:** `BaseButton`. Every `BaseButton` (Button, TextureButton, CheckBox, CheckButton, OptionButton and others) reacts to `ui_accept`, so each one can be pressed by Space.
**Test:** `board_camera.input/space_guard_covers_any_base_button` (a focused `TextureButton`).
**Source:** QA finding, 2026-10-03; fix by the builder
**Date:** 2026-10-03

---

### 92. space-guard-only-on-the-board-view

**Q:** The Sanctum camera stays enabled whenever SanctumShell is visible (`SanctumShell.gd` `_sync_ui_layer_visibility`), also under Summon, Vows, Weaving and Echo Party. So the Space guard (#87, #90) also blocked Space on those screens' buttons. Where should it run?
**A:** Only on the board view (and its echo detail), and in Combat. New export `BoardCameraController.guard_space_on_buttons` (default true). `SanctumShell.set_snapshot()` sets it to `_current_snap_type == "flow.sanctum"`. This is the same signal `_can_accept_spatial_pointer_input()` already uses for board taps. The echo detail opens inside `flow.sanctum`, so it keeps the guard. Every other sanctum-family type (`flow.summon`, `flow.echo_party`, `flow.realm_select`, `flow.vow_manage`, `flow.weaving_rite`) turns the guard off. Combat never changes the default, so Combat keeps the guard. A disabled camera still leaves Space alone.
**Test:** `board_camera.input/space_guard_follows_sanctum_view` (board → Summon → board → Echo Party → board, through the real shell), `board_camera.input/space_guard_works_in_echo_detail`.
**Source:** Jeff, 2026-10-04; the builder (the signal)
**Date:** 2026-10-04

---

### 93. z-key-zoom-cycle-is-shared

**Q:** Jeff's play test: Z does nothing in Combat. In Sanctum, Z cycles 5 fixed zoom levels. Jeff: "We match Sanctum. Camera should be generic everywhere."
**A:** The Z cycle is now a shared, opt-in option on `BoardCameraController`:
- New export `zoom_levels` (`PackedFloat32Array`; empty means Z does nothing). Combat sets `0.5, 1, 1.5, 2, 2.5` (Sanctum's five values).
- The levels are clamped into the current zoom range, sorted and de-duplicated. In Combat they become 0.5, 1.0, 1.5, 2.0, 2.2.
- Z goes to the first level above the current zoom (so Z also works after a wheel or pinch zoom). After the highest level it wraps to the lowest.
- Z eases through the same zoom target as the wheel (#85), about the screen centre.
- Z is handled in `_unhandled_input`, so a focused text field keeps the letter. It uses the same gate as other manual zoom: an enabled camera that takes manual input. A locked Combat camera zooms about the centre, keeps the actor centred and starts the 3 s hold.

**Sanctum is NOT moved onto the shared Z.** (**Superseded by #94:** Jeff decided Sanctum moves onto the shared levels and accepts the changes below.) It would behave differently in four ways:
1. Sanctum's Z steps an index (`_zoom_index`); the shared Z uses "the next level above the current zoom". After a Sanctum pinch these differ.
2. Sanctum's Z sets the zoom at once; the shared Z eases.
3. Sanctum's wheel steps the same index as its Z. The shared Z has no index.
4. Sanctum's Z is gated on `_echo_detail_open`, not on the camera's input gate.

So Sanctum keeps its own Z and its `zoom_levels` stays empty.

**Defect found and fixed:** `SanctumShell._unhandled_input` (Z and wheel) also ran while AppRoot hid the shell. If SanctumShell sits later in the tree than RealmShell, it took Z first: Combat did not zoom, and the hidden Sanctum stepped its own zoom. A hidden Sanctum also stepped its zoom on a wheel over a Combat panel. Fix: `SanctumShell._unhandled_input` returns when the shell is not visible in the tree. Shown Sanctum behaviour is unchanged.

**Tests:** `combat_camera/z_steps_through_levels_and_wraps`, `z_after_wheel_goes_to_next_level`, `z_in_focused_line_edit_types_letter`, `z_in_hidden_screen_does_nothing`, `z_while_locked_keeps_actor_centred`, `z_in_combat_with_hidden_sanctum_present`, and `board_camera.input/sanctum_z_cycle_unchanged`.
**Later QA fixes:** only a plain Z cycles (Shift allowed); Ctrl, Cmd (meta) and Alt+Z do nothing, so undo shortcuts never zoom. A second Z before the ease ends steps from the ease target. Test: `board_camera.zoom/modified_z_does_not_zoom`, `quick_second_z_steps_from_target` (both screens).
**Source:** Jeff, 2026-10-04 (match Sanctum); the builder (the level rule, and keeping Sanctum on its own Z)
**Date:** 2026-10-04

---

### 94. sanctum-zoom-on-the-shared-levels

**Q:** #93 kept Sanctum on its own Z because the shared rule would change Sanctum's behaviour. Jeff: the camera is one generic shared component for Sanctum, Combat and Stage.
**A:** Sanctum moves onto the shared zoom levels. Sanctum's feel changes where the rules below differ from its old index-based steps.

| Input | Sanctum after #94 |
|---|---|
| Levels | `zoom_levels` export on the Sanctum camera: 0.5, 1.0, 1.5, 2.0, 2.5. Range 0.5-2.5 comes from the levels. Start zoom 2.0 (`_DEFAULT_ZOOM`). |
| Z | Shared `BoardCamera` Z: the first level above the current zoom (or the ease target), wraps after 2.5. Eased. |
| Wheel | (**Superseded by #95**: Sanctum now uses the shared continuous wheel.) One notch up = the next level above, one notch down = the next level below. Clamped at 0.5 and 2.5, no wrap. Eased. `SanctumShell` reads the wheel event and calls the shared `BoardCamera.step_zoom_level(direction)`. |
| Pinch | Unchanged: immediate, clamped to 0.5-2.5, cancels a running ease. |
| Echo detail | The detail locks the camera with `manual_resume_delay` 0, so Z and the wheel are ignored (the shared gate). |

What changed in the old behaviour:
1. Steps are relative to the current zoom, not an index. After a pinch to 1.6, Z goes to 2.0 (the old index could jump elsewhere).
2. Steps ease instead of jumping.
3. There is no `_zoom_index`, so nothing can get out of step with the zoom.

**Screen tween versus the ease:** `SanctumShell._animate_camera_to` (the echo-detail focus and restore tween) now calls `camera.begin_screen_animation()` before the tween and `camera.end_screen_animation()` when it ends. `begin_screen_animation()` stops a running ease and blocks manual input until the end. So the ease and the tween never write the zoom in the same frame. The instant path (no tween) calls `camera.cancel_zoom_ease()`. The zoom saved before the detail opens is `camera.zoom_goal()` (the ease target), so closing returns to a real level, not a mid-ease value.

**Removed from SanctumShell:** `_zoom_levels`, `_zoom_index`, the Z branch in `_unhandled_input`, and `_toggle_zoom`. The visibility guard in `_unhandled_input` (#93) is kept as Jeff asked. **Superseded by #95:** the guard was removed with `_unhandled_input`. It is now redundant: a hidden Sanctum's camera is disabled, so the shared gate already rejects Z and the wheel.

**Tests:** `board_camera.zoom/sanctum_z_steps_levels_eased`, `sanctum_wheel_steps_one_level_clamped`, `sanctum_z_after_pinch_goes_to_next_level`, `sanctum_zoom_keys_ignored_in_echo_detail`, `sanctum_ease_does_not_fight_detail_tween`, `hidden_sanctum_takes_no_zoom_input`.
**Source:** Jeff, 2026-10-04
**Date:** 2026-10-04

---

### 95. one-wheel-rule-for-every-board-camera

**Q:** After #94, Sanctum's wheel stepped zoom levels and Combat's wheel was continuous. Should every board camera use one wheel rule?
**A:** Yes: Combat's rule (#85) everywhere. One notch is 1.1x, eased; notches during an ease build on the ease target; the zoom clamps to the camera's range; a `factor` of 0 or less is one notch. A `FREE` camera zooms toward the pointer; a locked camera zooms about the screen centre. Z keeps stepping the levels (#93). Pinch is unchanged.

Sanctum settings (`SanctumShell.tscn`): `wheel_zoom_step = 1.1`, `zoom_to_pointer = true`, range 0.5-2.5 from its levels, start 2.0. `SanctumShell` no longer reads the wheel; it has no `_unhandled_input` any more.

**Where the wheel is read (the generic rule):**
- `wheel_surface` set (Combat): in `_input`, before the GUI pass, only while the hovered control is `wheel_surface` (open board).
- `wheel_surface` not set (Sanctum): in `_unhandled_input`, after the GUI pass. A scroll area under the pointer takes the wheel first. A non-scrolling Control passes it on (`mouse_force_pass_scroll_events`, default true), so over open board the camera gets it. This is how Sanctum's wheel was routed before, so its panels keep scrolling.

I chose the second option for Sanctum because Sanctum has no single Control that is the hovered control over open board. Over the board the hovered control is a node inside the active overlay (for example `SanctumScreen/RootMargin/LayoutRoot`), and it changes with each overlay.

The echo detail stays locked (wheel and Z ignored, the shared gate). The detail tween hold stays. A hidden Sanctum takes no wheel: its camera is disabled, so the gate rejects it. The SanctumShell visibility guard (#93) went with its `_unhandled_input`, because nothing was left for it to guard.

**Tests:** `board_camera.zoom/sanctum_wheel_eases_continuous_and_clamps`, `sanctum_wheel_zooms_toward_pointer`, `sanctum_wheel_scrolls_panels_not_board` (the board view's party list and the notification body), `sanctum_wheel_then_z_goes_to_next_level`, `sanctum_zoom_keys_ignored_in_echo_detail`, `hidden_sanctum_takes_no_zoom_input`; `combat_camera/sanctum_wheel_uses_shared_rule`.
**Source:** Jeff, 2026-10-04 (one wheel rule); the builder (the routing rule)
**Date:** 2026-10-04

---

### 96. one-shared-board-pointer-tracker

**Q:** Combat tracked taps, drags and fingers in its own private fields. Stage and Sanctum need the same rules. Where should the code live?
**A:** In one script-only helper, `ui/shared/BoardPointerTracker.gd` (`RefCounted`). Combat uses it first (Story 3 phase B); Sanctum and Stage follow. The behaviour of Combat does not change. Jeff decided one helper for all three screens (Story 3 plan D2, D2b).

The helper owns: the per-pointer owner, the finger count, the 8 px tap-versus-drag threshold, the pinch rule (a second finger is never a tap or a drag), Space+press as a drag, the lost-release safety net (a finger-0 press clears stale state, #83) and `reset()`. It holds no screen code.

The screen wires it in four steps:
- `_input(event)`: `_pointer.note_touch(event)`. It counts every finger and never consumes.
- `_gui_input(event)`: `if _pointer.handle_event(event): accept_event()`.
- `_pointer.tap` goes to the screen's tap handler. The `tap` position is local to the screen, so the screen converts it with `get_global_transform_with_canvas() * pos`. `_pointer.drag_pan` goes to `camera.drag_pan`.
- The screen calls `_pointer.reset()` on focus loss, on hide and on a new encounter.

`accept_event()` has no test that can see it. The screen root has `mouse_filter` STOP, so Godot already consumes every pointer event that reaches it. A test with a node in `_unhandled_input` saw no event, whether the screen accepted it or not.

**Tests:** `board_pointer/*` (13, the helper alone); `combat_camera/tap_uses_viewport_point_when_screen_is_offset` (new); the 47 existing Combat camera tests pass unchanged except 5 reads of removed private fields, now read through the tracker (`finger_count()`, `is_pointer_down()`, `is_drag_active()`).
**Source:** Jeff (one helper, Story 3 plan D2/D2b); the builder (the API)
**Date:** 2026-10-04

---

### 97. sanctum-uses-the-shared-pointer-tracker

**Q:** Sanctum opened an echo detail on the press of a plain click and had no plain or one-finger drag pan. Should it use the shared tracker (#96)?
**A:** Yes (Story 3 plan D2b). This changes Sanctum feel on purpose:
- A plain mouse drag or a one-finger drag on open board pans the board 1:1.
- A tap opens or switches the detail on release, and only if the pointer moved under 8 px. A drag is never a tap.
- Taps keep their meaning: tap an echo opens the detail, tap another echo switches it, tap empty board closes it, tap a building opens the institutions panel, and placement mode still picks a cell.

**Feed.** `SanctumShell._input` feeds the tracker. The STOP chrome (`UILayer/Control`, `LayoutRoot`) takes every press before any board Control could, so a `_gui_input` would see nothing. The shell does not ask the viewport for the hovered control: a touch press arrives before the hover moves. It walks the visible chrome instead (`_classify_press`) and sorts a press into three kinds:

| Press lands on | Result |
|---|---|
| a button, field, slider, list or tree (as before) | starts nothing |
| a panel (`PanelContainer`, `Panel`, `ScrollContainer`, `ColorRect`) | may tap, never pans |
| open board | may tap and pan |

A control clipped out by its parent does not count. A press while a modal is open, on any snapshot other than `flow.sanctum`, or while the shell is hidden starts nothing. The hidden-shell rule is new: `_input` runs on hidden nodes, and a hidden Sanctum could open a detail from a click in Realm.

**Space+drag.** The camera keeps it (`space_drag_pan` stays true, and `BoardCamera._input` pans once, 1:1, through the STOP chrome). The shell never starts a gesture on a Space press, so there is one owner and no double pan. In practice the camera marks the press handled first, so the Space check in the shell is a safety net that no test can see.

**Detail lock.** `drag_pan` is ignored while the detail locks the camera (`manual_resume_delay` 0, or the focus tween), so a drag does nothing there. Taps still switch echoes and close the detail.

**Resets (`tracker.reset()`).** Focus loss (both notifications), the shell hidden, and any snapshot other than `flow.sanctum`. A `flow.sanctum` refresh never resets, because those arrive every second or two. The echo detail does not reset: it opens on a release, so no gesture is open then.

**Not changed.** Wheel, Z, pinch and the trackpad two-finger pan stay on the camera. Camera input on Sanctum sub-screens stays as it was (follow-up #24).

**Not testable.** `set_input_as_handled()` on the owner's release changes nothing a test can see, because `UILayer/Control` is STOP and already consumes the event. The call stays, as in Combat (#96).

**Tests:** `board_camera.pointer/*` (22, real `SanctumShell`, real input). No existing assertion changed.
**Source:** Jeff (D2b, 2026-10-04); the builder (the feed and the three press kinds)
**Date:** 2026-10-04

---

### 98. sanctum-tap-on-release-confirmed

**Q:** Decision #97 moved a Sanctum tap from the press to the release. Does that feel right in play?
**A:** Yes. Jeff played Sanctum and Combat after phases A-C and confirmed it. A tap acts on release, and only when the pointer moved under 8 px.
**Source:** Jeff, 2026-10-04
**Date:** 2026-10-04

---

### 99. echo-detail-panel-tap-closes-the-detail

**Q:** With the echo detail open, a tap on the body of the detail panel closes the detail. Is that right?
**A:** Yes, it stays. A panel counts as part of the board for taps (decision #97), and a tap on empty space or on the panel body closes the detail. This behaviour is older than Story 3. Jeff confirmed it stays as it is.
**Source:** Jeff, 2026-10-04
**Date:** 2026-10-04

---

### 100. stage-explore-on-the-shared-board-camera

**Q:** Stage Exploration had no camera: the Board node was the camera, moved by script. How does it use the shared `BoardCameraController`?
**A:** Same camera, same rules as Combat (Jeff, Story 3 plan D1-D11).

**Structure (`StageExploreScreen.tscn`).** `WorldLayer` (a `CanvasLayer`, `follow_viewport_enabled`) holds `BoardRoot`, which holds `Board` (with `BridgeLayer` and `GhostFootprintLayer`), `FogLayer`, `SituationLayer` and `PartyTokenLayer`, and a `BoardCamera` next to `BoardRoot`. Sibling order is unchanged: fog over the board, the party on top. The old per-frame copy of the board transform to the fog and situation layers is gone, because they share `BoardRoot`.

**Camera numbers (copied from Combat, not invented).** Min zoom by the board-fit formula (#70: 0.90 of the shorter viewport side over the longest board side). Stage uses Combat's clamp, floor 0.05 and ceiling 0.35 (Jeff, 2026-10-05); this supersedes the Stage row 0.08 / 0.30 in #70, default 1.3, max 2.2, `zoom_levels` 0.5/1/1.5/2/2.5, `manual_resume_delay` 3.0, `wheel_zoom_step` 1.1, `zoom_to_pointer` true, `wheel_surface` the screen root, `space_drag_pan` false. The constants are copied into `StageExploreScreen.gd`; sharing them is a follow-up (a change to the shared camera needs Jeff).

**Bounds.** In explore `BoardRoot` is at scale 1, centred on the world origin (`position = -visual rect centre`, where the rect is the painted board with its tile footprint). The camera bounds are that rect, with no pad.

**Preview (`flow.stage`) has no camera.** The camera is enabled only while the screen is visible and in explore mode. In preview `BoardRoot` itself is scaled and placed to fit the safe body (as the Board node was). Markers and the party token keep their screen size there: markers are scaled by 1 / board scale, the token by `set_token_scale`.

**Fade.** `modulate` on the screen does not reach the `WorldLayer`. The preview fade tween now also fades `BoardRoot`'s modulate, in parallel. A test steps that tween and checks both reach 1.

**Begin hand-over.** The Begin zoom tweens `BoardRoot` x3 as before and emits `cta.start`. The explore snapshot then resets `BoardRoot` to scale 1 on the origin and, on first entry, centres the camera on the party at zoom 1.3, FREE. First entry is every entry from preview and every new Stage instance (RealmShell rebuilds the screen after each combat), so a new Stage starts FREE at the default zoom, centred on the party (D8). Entering preview resets the pointer tracker and the first-entry flag.

**Live resize.** `set_layout` in explore refits the zoom floor and keeps the camera's world point and the player's zoom. `set_layout` does nothing to the camera when it is absent (the seam test builds the screen without a tree).

**Parked snapshots (D10).** A snapshot that moves nobody never moves the camera, so the player's pan and zoom survive it. The old snap to the party is gone.

**Tests:** `stage_camera/*` (34, real `FlowRuntime`, real `RealmShell`, real input); `realm_ui/target_minima_and_spatial_caps` rewritten (see the report).
**Source:** Jeff (D1-D11); the builder (structure, fade, hand-over)
**Date:** 2026-10-05

---

### 101. stage-advance-locks-the-party-and-follows-each-cell

**Q:** Advance used to scroll the board under a screen-locked token. What does the camera do now (D1)?
**A:** An Advance locks the camera on the party (`select("party")`). The lock stays after the walk, until the player taps away. A manual pan or pinch holds the follow for 3 s, as in Combat.

**Tween or lerp.** The camera's own follow lerp (5 per second) moves the camera. The travel tween no longer writes the camera or the board. It only sequences: for each walked cell it calls the party token (moves to that cell over the segment time), pushes the follow target (that cell's world position), then waits the segment time, then drops the ghost and spends one step diamond. Because the tween never writes the camera, there is no `begin_screen_animation()` and nothing fights the lerp.

**Per-segment target (superseded by #105).** This entry decided one follow target per destination cell. #105 replaced it: the target is the drawn token, every frame. The text below on the tween pushing a target per cell no longer holds.

**The party token** is in world space under `BoardRoot` and moves cell by cell. The bark bubble stays screen-space: `_process` re-anchors it to the token whenever the token or the camera moves.

**Tests:** `stage_camera/advance_locks_party_and_follows_the_drawn_token` (replaced the per-cell test, see #105), `lock_stays_after_the_walk`, `manual_pan_holds_then_follow_resumes`, `parked_refresh_during_walk_keeps_token_and_target`, `bark_anchor_tracks_party_on_screen`.
**Source:** Jeff (D1); the builder (tween only sequences)
**Date:** 2026-10-05

---

### 102. stage-tap-targets-and-card-lock

**Q:** What can the player tap on Stage, and what does a card do (D3, D5, D7, D11)?
**A:** Tap targets are the party and the revealed situations, found by cell. The party wins a shared cell. A tap on empty board calls `deselect()` (FREE). Any revealed situation can be tapped, resolved ones included (Jeff, 2026-10-05). `select_board_target(id)`: `""` and `"party"` mean the party, a revealed situation id means that situation, any other id does nothing. Every Stage echo card sends `""`, so any card locks the party (RealmShell forwards it to the screen; no `core/` change; real echo ids are follow-up #27). Tap, drag, wheel, pinch and Z work in explore only.

**Bars.** `ActionBar` and `StepBudgetRow` are `mouse_filter` STOP (before: the container default, PASS). Their gaps are hovered controls, so the wheel does not zoom there (D11), and a tap in a gap is not a board tap that would release the lock. Cost: a drag cannot start in a gap of those two bars.

**Kept (D7).** The Space guard stays on (the camera swallows Space while a button has focus) and Stage buttons keep their focus mode. Enter still presses Advance.

**Tests:** `stage_camera/tap_party_locks_and_follows`, `tap_revealed_situation_locks_and_follows`, `party_wins_a_shared_cell`, `tap_empty_board_releases_to_free`, `unknown_and_unrevealed_ids_are_ignored`, `echo_card_tap_locks_the_party`, `tap_resolved_situation_locks_and_follows`, `tap_uses_viewport_point_when_screen_is_offset`, `wheel_over_echo_bar_and_action_bar_does_not_zoom`, `tap_on_chrome_bar_gaps_keeps_the_lock`.
**Source:** Jeff (D3, D5, D7, D11); the builder (bar filter)
**Date:** 2026-10-05

---

### 103. stage-pointer-and-visibility-rules

**Q:** Which rules protect Stage input (shared with Combat #96 and Sanctum #97)?
**A:** The Stage root is a full-rect STOP Control, so `_gui_input` sees presses on open board and `_input` counts fingers. Both do nothing outside explore mode, and `_input` does nothing while the screen is hidden. `tracker.reset()` runs on focus loss (both notifications), on hide, and when preview is entered (which is how every new Stage entry starts). A hidden Stage disables its camera and hides its `WorldLayer` itself, because neither follows the Control. A hidden Stage takes no Z, wheel, tap or drag in either boot order against a Sanctum shell. A modal covers the board, so nothing reaches it while a modal is open.
**Not changed.** `_explore_spatial_rect` stays: the HUD geometry test reads it. Nothing in the camera path uses it now.
**Tests:** `stage_camera/focus_loss_resets_stuck_pointer`, `hide_resets_stuck_pointer`, `new_stage_entry_resets_stuck_pointer`, `hidden_stage_takes_no_input_in_both_boot_orders`, `hidden_screen_disables_camera_and_world`, `shell_swap_hands_viewport_to_shown_camera`, `combat_swap_and_new_stage_start_free`, `modal_blocks_board_input`.
**Source:** the builder
**Date:** 2026-10-05

---

### 104. echo-card-tap-is-a-release-not-a-press

**Q:** `EchoCardItem` emitted `card_pressed` on the mouse press. The Codex bot (PR #92, follow-up #17) says a drag that starts on a card, to scroll the echo bar, locks the camera on that card. Is that true, and what is the fix?
**A:** True, and worse. A probe in the real `RealmShell` (six cards, the bar overflowing) showed two defects. (1) The card locked the camera on the press (`mode` 1 right after the press). (2) The card had `mouse_filter` STOP, so the bar's `ScrollContainer` saw no event at all when a press started on a card (zero events; with PASS or in a gap it saw the full touch and mouse stream). A drag from a card could never scroll the bar. Scrolling itself cannot be measured in a headless run (the scroll value did not move even from a gap), so the tests check that the `ScrollContainer` receives the drag.

**Fix.**
- The card is `mouse_filter` PASS, so a drag that starts on it reaches the `ScrollContainer`.
- The card emits `card_pressed` when a left press and its release complete on the card, the pointer did not move 8 px or more, and the bar did not scroll between press and release. The check is `BoardPointerTracker` (the same 8 px rule and the same handling of the engine's touch twin of a mouse click, so one tap is one signal). The card does not feed finger counting and never counts Space as a "not a tap" key. I chose the shared tracker over a private copy of the rule because it already owns the threshold and the ownership rule; the card only adds two checks.
- A release outside the card is no tap (press on one card, release on another selects nothing).
- The bar's own `scroll_deadzone` is 8, the same number as the tracker's.

**`InitiativeRowItem` is not affected.** The Combat initiative rows sit in a `PanelContainer`/`VBoxContainer`, not in a `ScrollContainer`, so no scroll drag can start on a row. It still emits on press and accepts every event on purpose (the board root behind it must not see them). Not changed.

**Same pattern elsewhere.** `RealmCardItem.gd:33` emits `card_pressed` on press too. It is outside this change. Check it if its list scrolls.

**Follow-up #106.** The release-based tap exposed a second defect: the bar rebuilt every card on every snapshot, so a card that took a press could be freed before its release. #106 fixes that.

**Tests:** `combat_camera/card_tap_selects_on_release`, `card_drag_scrolls_the_bar_and_selects_nothing`, `card_press_and_release_on_different_cards_selects_nothing`, `card_tap_is_one_signal_with_emulated_twin`, `card_tap_after_the_bar_scrolled_selects_nothing`; `stage_camera/echo_card_drag_does_not_lock_the_party`.
**Source:** Codex bot review of PR #92, verified by probe; Jeff (fix now); the builder
**Date:** 2026-10-05

---

### 105. locked-follow-target-is-the-drawn-token

**Q:** The Codex bot (PR #92) says that when a locked actor moves, the camera target comes from the new snapshot's final cell while the token is drawn at its old or in-between position, so the camera runs ahead of the token. Is that true?
**A:** True. Probe, Combat, before the fix (one locked echo, a 5-cell move, zoom 1.3, normal speed): the camera was up to 207 world px (about 269 screen px) ahead of the drawn token, and it started moving during the telegraph delay while the token still stood at its old cell. Probe, Stage Advance (3 cells), before the fix: the camera trailed the token by up to 22 world px (29 screen px) with a per-cell target.

**New rule (Combat and Stage).** While a camera is locked on one actor (or the Stage party), the follow target is the DRAWN position of that token, in world space, set again every frame. At rest this equals the cell centre, so a resting lock is unchanged. The telegraph delay holds the token at its old cell, so the camera waits with it. The camera's own follow lerp (5 per second) is unchanged.
- Combat: `CombatTokenLayer.display_cell_position(actor_id)` gives the drawn position with the feet offset removed (so it compares with `map_to_local` of a cell). `CombatBoardScreen._process` pushes the target each frame while the camera is in `FOLLOW_ACTOR`. A dead actor still sends the camera to the party; `FOLLOW_PARTY` still follows the cell centroid; manual pan hold (3 s), screen-animation behaviour and objective modes are untouched.
- Stage: `_party_token_world()` (the `PartyTokenLayer` display position) replaces the per-cell push. `_process` pushes it each frame. The travel tween still moves the token one cell at a time and drops ghosts.

**Probe after the fix.** The camera never leads the token (worst lead 0.0 px in both scenes). The final offset at rest is 0.0 px. The telegraph delay does not move the camera. A per-frame target still needs the lerp: the camera now trails the token. Worst cases with the lerp unchanged, 5 cells along one iso axis: normal speed 0.36 s, 400 px (screen) from the centre; fast speed 0.20 s, 569 px; slow speed 0.72 s, 227 px. The other axis is half of that (284 px at fast speed). The view is 1280 x 720, so the token stays in view in every case. Stage walk (3 cells in 0.5 s): at most 73 screen px. So the lerp constant is NOT changed. A faster follow is only needed if the token must stay near the centre during a walk; the numbers do not show a need.

**Supersedes** the per-segment follow target in #101. The 5 per second follow lerp of #72 is unchanged.

**Tests:** `combat_camera/locked_follow_never_leads_the_drawn_token`, `telegraph_delay_does_not_move_the_camera`, `feet_offset_does_not_shift_a_locked_camera`; `stage_camera/advance_locks_party_and_follows_the_drawn_token`, `parked_refresh_during_walk_keeps_token_and_target`. The `CombatCameraSelectTests._step` helper now also advances the token layer (as SceneTree does), because the camera follows the drawn token.
**Source:** Codex bot review of PR #92, verified by probe; Jeff (fix now); the builder
**Date:** 2026-10-05

---

### 106. echo-bar-cards-survive-snapshots

**Q:** After #104 a tap needs a press and a release on the same card. `RealmShell._update_echo_bar` freed every card and built new ones on every snapshot. What happens to a tap when a snapshot arrives between its press and release?
**A:** It was lost. Probe (real `RealmShell`, six cards): press on a card, a snapshot, the old cards freed (what the end of the frame does), release: the camera stayed FREE (mode 0, no target). In Combat auto-play, snapshots arrive every 0.5, 1.5 or 3.0 s, so a normal tap of 100-150 ms could be lost. The next tap worked. (The tap was safe before #104 because the press alone selected.)

**Fix.** Cards now live across snapshots and are updated in place (`setup`, `setup_ally` or `setup_spirit` run again with the new data, so a card looks exactly like a rebuilt one):
- A card is matched by kind (plain, ally, spirit) and actor id. When the id is empty (Stage `party_preview`), it is matched by kind and position.
- New actors get new cards, gone actors lose theirs (removed from the bar at once), and the bar keeps the snapshot's order (`move_child`).
- A card that is mid-press keeps its pointer state across the update.
- A screen change still replaces the cards: Combat ids and Stage ids never match, and a snapshot type with no party removes every card.
- `EchoCardItem.slot_key` holds the key. RealmShell already used `instantiate()` and `add_child()` for the cards; the same pattern is kept and no new construction pattern is added.

**Not handled (Jeff, 2026-10-05).** Two actors with the same kind and id in one snapshot are not handled (the bar would gain a card per snapshot). No real data produces this; accepted as unlikely.

**Scroll.** Probe: with the bar scrolled to 300, a snapshot left it at 300 before the change (the old cards stay in the tree until the frame ends, so the content does not shrink) and leaves it at 300 now. The scroll test pins it; it could not be broken by the old rebuild in a headless run.

**Tests:** `combat_camera/card_tap_survives_a_snapshot_between_press_and_release` (same and changed snapshot), `card_tap_with_emulated_twin_survives_a_snapshot`, `snapshot_updates_cards_in_place`, `snapshot_adds_and_removes_cards_in_order`, `snapshot_keeps_the_bar_scroll`, `screen_change_replaces_the_cards`; `stage_camera/echo_card_tap_survives_a_stage_snapshot`.
**Source:** qa-verifier (probes P1, P1b); Jeff (keep cards across snapshots); the builder
**Date:** 2026-10-05

---

### 107. skill-mark-and-reveal-reach-fixed-in-its-own-pr

**Q:** A probe for follow-up #6 (stop-short, movement-model section 7.5) found that skill `actor.mark` and `actor.reveal` resolve as `actor.idle` at distance 2 or more in live combat. How is it fixed?
**A:** In its own PR, before the stop-short work (PR0). Option O1: `CombatActivationService.ACTION_RANGES` gains `actor.mark` and `actor.reveal`, both set to the new constant `SKILL_REACH` (3, in the same class). The mark offer gate and the reveal offer gate in `ActionCandidateGenerator` both read `ReachAuthority.SKILL_REACH`, so the offer and the reach cannot drift apart. The reveal gate is new: it gains `enemy_dist <= SKILL_REACH`. Jeff asked for the one constant after QA found the literal 3 in three places. Jeff chose O1 and reach 3 for both skills on 2026-10-06. Rejected: O2 (offer only when adjacent; the skill would be worse than the planned generic observe), O3 (move, then act; changes the goal contract).

**Cause.** Both skills are stationary candidates. They carry an empty fallback. The reach table listed no entry for them, so every other action had reach 1 (`CombatActivationService.gd` `ACTION_RANGES`, `DEFAULT_ACTION_RANGE`). Mark was offered within 3 cells and reveal at any distance. With a target at distance 2 or more, the planned action was invalid, no fallback existed, and `apply_live_activation` set `actor.idle` (`LiveMovementContextService.gd:418-421`).

**Probe (before the fix).** 8 Standing 3 combat fights, skills equipped on the roster: `actor.reveal` was selected 23 times and `actor.mark` 2 times. All 25 resolved `actor.idle`. `_reveal_used` is set only in the effect path (`ActorStateMachine.gd:1316`), so reveal could repeat.
**Probe (after the fix).** Same slices: reveal selected 2 times and mark 2 times, all resolved to the skill, 0 idle. Reveal is no longer selected at distance 11 to 16, because it is no longer offered there.

**Behaviour change to know.** Reveal is now offered only within 3 cells. Before, it was offered at any distance, and every far selection was wasted.

**Recorded values.** None moved. No fingerprint fixture equips skills. The 14 fingerprint suites pass.
**Tests:** new suite `skill_reach` (4 tests, production-shaped path through `FlowRuntime`): mark resolves at distance 2 and 3; reveal resolves at distance 3 and sets `_reveal_used`; reveal is not offered at distance 4; the mark effect sets `marked_by` and raises the ally melee bonus. On the old code, 3 of the 4 fail.
**Source:** Jeff (O1 and reach 3); sr-game-designer (section 12 of `followup-6-design.md`); mechanics-developer (probe B4 and the build)
**Date:** 2026-10-06

---

### 108. stop-short-benefit-after-a-short-route
**Rule.** `docs/movement-model.md` section 7.5: unused capacity is not banked. A short stop needs a cause and a benefit, or it reads as incompetence.
**Mechanism (option B).** After the move resolves, `CombatActivationService.activate` step 3a plays the benefit at the final cell when the winning option is the existing `conservative` route. The option, goal and intent contracts do not change. `StopShortService` holds the gates and veto reasons. A stop with no cause or no benefit is vetoed.
**Causes.** One registry. "Fear or low morale": fear from 20, or `broken` morale. Shaken morale does not count. It favours Guard only. "Identity": Calling family or vector, scaled by Standing. Directive, Keeper guidance, Bond and Vow add their own causes later, in V2-DIRECTIVE-002, V2-COMBAT-004, V2-BOND-002 and V2-VOW-002 (notes on those stories are still to be written).
**Scope.** Echoes only. Enemies keep every route they have today. New action `actor.observe` (reach 3): it marks the target (`mark_kind` observe) and counts as one turn in the ContributionLedger. Guard counts as a guard.
**Shipped OFF in PR1; ships ON from PR2 (Jeff, after the play test).** `data.actor.stop_short.enabled` is true, `cell_search.enabled` is true and the weight is 6.0. The debug command `stopshort on|off` takes effect at the next encounter start. PR2 added the prefix-cell search (window: route cost up to capacity minus 1, so 1, 2 and 3 cells at capacity 2, 3 and 4; the best legal prefix replaces the half-capacity `conservative` option). Both flags were first proved inert (sharded run with both false: no recorded value moved). Cause 1, `stop_short.enabled` true: the COMBAT, PURIFY_SHRINE, RECOVER, PROTECT and GUIDE_SPIRIT fingerprints and the GUIDE_SPIRIT (25 to 24 rounds) and PROTECT emotion traces moved; PURSUE and ENDURE did not. Cause 2, `cell_search.enabled` true: only the PURIFY_SHRINE fingerprint and emotion trace moved. This one switch carries two mechanisms: the wider window, and Hold's full-route test reading the primary route's cohesion; the move was not split by mechanism. Measured on 20 fights per cell: stops 8 (search off) to 11 (search on), Hold share 87.5 to 72.7 percent, per-Echo ceiling 5.9 percent (limit 25).
**Snapshot.** `last_actor_action.stop_short` is present on every actor step (`{}` when there is no stop). Actors gain `is_marked` and `mark_kind`. `PLAYER_SAFE_FIELDS` is unchanged.
**Text.** All words come from `data/shouts/stop_short_text.json` through `StopShortText`. First person for the Echo itself. The wording is a placeholder until Jeff approves it.
**Measured.** Weight is not the lever: about 800 of 931 eligible turns end at `no_benefit`. The 25 percent per-Echo ceiling holds on fights with 8 or more eligible turns. Details are in `followup-6-probe-results.md`, kept outside the commit.
**Not built (parked for the combat visual language story).** The Return route benefit and its marker, Hold links to allies, and the snapshot fields `anchor_actor_ids`, `return_cell` and `planned_end_cell`. A dotted remainder of the route was rejected: the game shows no intended location for any actor. Also: Range (weapons story), reposition and regroup goals in live combat (new story), a guard motion for every guard without the hop (new item).
**Tests:** suites `stop_short` (31), `stop_short_wiring` (30) and new `stop_short_search` (15); PR2 core and data diff is 246 lines added, 8 removed; `snapshot_contract`, `flow_transaction` (action count 77) and the fingerprint suites updated or unchanged.
**Source:** Jeff (decisions V1 to V44); sr-game-designer; mechanics-developer; qa-verifier
**Date:** 2026-10-09

---

### 109. stop-short-visible-tell
**Marker.** Drawn outside the Echo in a second pass. Guard: a half arc facing the nearest enemy, continuous, behind the HP bar. Hold: a thick full ring. Observe: four diagonal dashes, the dashed line and bold brackets on the target. Cream with a charcoal edge, no new hue. The HP bar draws on top.
**Word chip.** "Braces", "Holds" or "Watches" below the token, from zoom 0.8. No cause badge for Guard and Hold: the cause shows in the reason bubble on selection and in the bark. Observe keeps its badge.
**Motion.** A dip, then a hop (lift `clamp(22/zoom, 16, 28)` world units), a ripple at the landing and a marker pop. Guard adds two small shakes. Landing times at Normal: Guard 0.34 s, Hold 0.36 s, Observe 0.34 s.
**Rest pose.** For the whole guarding status: Guard leans away from the enemy; Hold shrinks to 0.85. The marker lasts as long as the pose. The pose returns in 0.12 s.
**Rules kept.** No hop for a selected Echo or at Fast. Ordinary guards, plain moves and skill marks look as before. The Cream settle diamond is off (the code stays until a later pass). Quiet counters are not built.
**Placeholder.** All shapes, motion and wording are placeholders for the final art pass (follow-up #16).
**Files:** `ui/screens/combat/CombatStopShortMotion.gd` (new, pure functions), `CombatTokenLayer.gd`, `CombatTokenPresentationState.gd`, `CombatTokenVisualConfig.gd`, `CombatBoardScreen.gd`. The draw code is not covered by any test.
**Source:** Jeff (play test and mockup review); sr-game-artist; game-feel-developer; ui-ux-designer
**Date:** 2026-10-09

---
