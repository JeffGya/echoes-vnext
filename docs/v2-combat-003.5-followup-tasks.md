# V2-COMBAT-003.5 — Spawned follow-up tasks

Suggestion chips created during the V2-COMBAT-003.5 orchestration session (2026-09-13 through
2026-09-23). Each can be started in a fresh worktree with one click from its chip, or started
manually by pasting the "Opening prompt" below into a new session. `task_id` is the internal
reference if you need to dismiss one later.

> **Corrected 2026-09-23 (Phase 6 combined verification):** item 1 below was already fixed and
> its task chip dismissed — kept here only as a record. Items 2-4's `ANSWERS.md` citations were
> wrong (those entry numbers don't exist there) and have been corrected to point at this story's
> own decision log, `docs/v2-combat-003.5-decisions.md`, where the actual record lives. Item 10's
> premise was found false by direct test and has been rewritten.

---

## 1. ~~Fix perceived_actors script error in MovementOptionService~~ — ALREADY FIXED, chip dismissed

**task_id:** `task_6206db50` (dismissed 2026-09-23)

Phase 6's combined verification (full suite log) found zero `Invalid access`/`perceived_actors`
script errors anywhere. This was fixed incidentally during the story (exact commit not traced);
kept as a record only, not an open item.

---

## 2. Review PURSUE reward payout after board-size increase

**task_id:** `task_0a287277`

**Why it came up:** V2-COMBAT-003.5 raised board size (`docs/v2-combat-003.5-decisions.md` entry #2); as a mechanical side effect, one PURSUE fixture resolves one round faster and pays more (Ase 55→64, Ekwan 7→8). Jeff: flag it, out of scope for that story (`docs/v2-combat-003.5-decisions.md` entry #4).

**Opening prompt:**
> In the Echoes vNext repo, story V2-COMBAT-003.5 raised combat board size (`data.combat.board`: base_cols/rows 12→18, max_cols/rows 22→28 — see `docs/v2-combat-003.5-decisions.md` entry #2). A side effect, confirmed by qa-verifier during that story's review: PURSUE mode's `fp_pursue` fixture in `tests/FlowFingerprintTests.gd` now resolves one round faster than before (5→4 rounds) because the bigger board gave the party more room to close on the quarry, and its reward payout moved from Ase 55/Ekwan 7 to Ase 64/Ekwan 8 as a direct consequence — same win condition (`all_enemies_defeated`), unchanged rank (S).
>
> Jeff wants this reviewed on its own, separately from V2-COMBAT-003.5 (see `docs/v2-combat-003.5-decisions.md` entry #4): is a reward payout that shifts as an unintended side effect of an unrelated board-size tuning change (rather than a deliberate balance decision) something the reward formula should be more insulated from? Investigate how PURSUE (and likely other objectives whose resolution speed is board-shape-sensitive) computes its Ase/Ekwan payout, whether "fights faster because the board is bigger" is a sound proxy for "performed better," and whether this warrants a design conversation with Jeff before deciding whether to change anything.

---

## 3. ~~Fix stale PURSUE comment and board-size fallback defaults~~ — DONE 2026-09-26

**task_id:** `task_d44dccca` (done 2026-09-26)

**Resolution:** `EncounterSetupService.gd` board fallbacks now match live config (18/18/28/28, PURSUE
`long_multiplier` 4.0); the PURSUE and GUIDE_SPIRIT comments name the config key instead of a literal
multiplier. The same stale 12/22 fallbacks were also updated in `tests/CombatRoundtripIntegrationTests.gd`,
`tools/TerrainRegionProbe.gd` and `tools/BoardSizeOptionsProbe.gd`. Kept as a record only.

**Why it came up:** Found while `EncounterSetupService.gd` was open for the board-size change; pre-existing (V2-STAGE-004-era), unrelated to V2-COMBAT-003.5's subject. Jeff: file separately (`docs/v2-combat-003.5-decisions.md` entry #5).

**Opening prompt:**
> In `core/combat/EncounterSetupService.gd` in the Echoes vNext repo, fix two small pre-existing documentation/fallback staleness issues surfaced during V2-COMBAT-003.5's review (see `docs/v2-combat-003.5-decisions.md` entry #5), unrelated to that story's actual subject:
>
> 1. Around line 334, a comment reads `# V2-STAGE-004 P3b: PURSUE board is 2x one dimension` — but the actual configured value in `data/balance.json` (`data.combat.board.long_multiplier` for PURSUE) is 4.0, and the code's own default at line 336 is 2.0 (which never fires since the config always provides a real value). Correct the comment to state the true multiplier, or make it generic enough not to go stale again when the config value is tuned (e.g. reference the config key instead of a literal number).
> 2. Around lines 327-331, the function's fallback defaults for `base_cols`/`base_rows`/`max_cols`/`max_rows` still read 12/12/22/22 — stale since V2-COMBAT-003.5 raised the live config to 18/18/28/28 (`docs/v2-combat-003.5-decisions.md` entry #2). These fallbacks only fire if `data.combat.board` were ever missing from `balance.json`, so there's no live behavior bug today, but they'd silently regenerate the OLD board size if that ever happened. Update them to match the current live values, or reconsider whether hardcoded fallbacks make sense here at all versus failing loudly if the config block is missing.
>
> Run the compile check and relevant filtered test suites (`tests combat_terrain`, `tests combat_baseline`) after any change to confirm nothing regresses.

---

## 4. Check if speed_bonus_threshold needs to scale with board size

**task_id:** `task_1868ffd0`

**Why it came up:** During the fingerprint re-baseline, a PROTECT fixture crossed the fixed 5-round `speed_bonus_threshold` downward purely because of the bigger board (losing its speed bonus: rank S→A). Raises the question of whether this threshold, and grading generally, was tuned against the old board pacing — a live-play design question, not just a test-fixture quirk. Explicitly out of scope for V2-COMBAT-003.5 (no rebalancing).

**Opening prompt:**
> In the Echoes vNext repo, `core/economy/RewardCalc.gd:80-82` pays a speed bonus (better Ase/Ekwan payout, higher rank grade) only when `round_ended < speed_bonus_threshold` (currently 5). Story V2-COMBAT-003.5 raised combat board size (`data.combat.board`: base_cols/rows 12→18, max_cols/rows 22→28 — `docs/v2-combat-003.5-decisions.md` entry #2), which changes how many rounds a typical fight takes to resolve. During that story's fingerprint re-baseline, a PROTECT test fixture crossed the threshold DOWNWARD (4→5 rounds, losing its speed bonus: rank S→A, Ase 59→50) purely because the bigger board changed pathing — a mechanical side effect, not a balance decision.
>
> Investigate: was `speed_bonus_threshold` (and any other round-count-based grading threshold in `RewardCalc.gd` or elsewhere) tuned against the old ~12x12 board pacing? If board size now routinely shifts real fights across that threshold in either direction, grade/reward distribution across live play may have shifted unintentionally, not just in this one test fixture. Determine whether the threshold should scale with board size (or with the objective's own expected-duration signature), stay fixed, or whether this is a non-issue in practice — and bring findings to Jeff for a decision, since this is a design/balance number, not something to change unilaterally (V2-COMBAT-003.5 explicitly excluded rebalancing combat/economy from its scope).

---

## 5. Add pronoun substitution to GuidanceContribution reason text

**task_id:** `task_8b7887b3`

**Why it came up:** Found while adding a new line to `GuidanceContribution._REASON_TEXT` for the movement_style work (decision #22). All 20 lines in that table always render she/her, even for male Echoes, because the table's output skips the pronoun substitution step `ConversationService.gd` already uses for dialogue. Jeff: file separately, pre-existing, affects the whole table (decision #24).

**Opening prompt:**
> In the Echoes vNext Godot/GDScript repo, `core/actors/behaviors/GuidanceContribution.gd`'s `_REASON_TEXT` dictionary (around line 121) holds short narration lines explaining why an Echo responded to Keeper guidance the way she did ("her vow holds her", "she will not leave the one she is bound to", "another already told her where to stand", "she reads it the way you do", plus a fifth line added by V2-COMBAT-003.5: "she made the only right move" for the movement_style source). These lines flow straight into `_bark_line` (`ActorStateMachine.gd:945`) with no pronoun substitution step.
>
> Compare this to `core/realms/ConversationService.gd:138`, which calls `_substitute_pronouns(response_text, echo_gender)` (defined at line 699) before showing dialogue text. That function exists and works — it just isn't used for this table.
>
> Fix: route `_reason_text()`'s output (or its caller) through the same `_substitute_pronouns` pattern, so a male Echo's guidance-reason bark doesn't say "she"/"her". Check `_substitute_pronouns`'s signature and canonical-form convention (per project lesson: author text in one canonical pronoun form, substitute for other genders at runtime) before wiring it in, and confirm the Echo's gender is actually available at the call site in `ActorStateMachine.gd` or wherever `GuidanceContribution.resolve()` is called from. Add a test proving a male Echo's guidance bark no longer contains "she"/"her".

---

## 6. Design a real "stop and hold" movement behavior

**task_id:** `task_afaaec2e`

**Why it came up:** `docs/movement-model.md` §7.5 already commits to Echoes stopping early on purpose and doing something meaningful (guard, observe, mark) rather than silently banking unused movement capacity. This doesn't exist yet. A V2-COMBAT-003.5 fix (the movement commitment scoring fix, Phase 3c) just removed an accidental, wrong-reason stand-in for it, so this is worth its own story before it's forgotten.

**Opening prompt:**
> In the Echoes vNext repo, `docs/movement-model.md` §7.5 ("Unused capacity") is an existing V1 design decision: "Unused capacity is not banked by default. A careful Echo should stop early because the destination is tactically better, then do something meaningful: observe, guard, mark, stabilize, maintain desired range, preserve a formation, keep a return route, prepare an intercept. Stopping early without a benefit reads as incompetence, not caution."
>
> No such mechanism exists yet in `core/actors/behaviors/` or `core/movement/` (grep for `hold_formation` shows a directive-driven score reduction exists, but no generic "stop and do something with the leftover capacity" behavior).
>
> Context: a V2-COMBAT-003.5 fix (movement commitment scoring, Phase 3c) just removed a scoring bug that was accidentally producing some actors stopping short of full movement — for the wrong, illegible reason (a unit-mismatch in the scoring formula, not real caution). After that fix, every actor now visibly moves its full capacity every turn unless something specific stops it (hostile control, a directive). §7.5's documented intent — genuine, visible, attributable restraint — still has no real implementation.
>
> Design and implement §7.5's "stop and do something meaningful" mechanism: when an Echo's route scoring favors stopping before spending full capacity, that decision should be tied to a legible cause (fear, a bond, a vow, a directive, an identity trait) and should produce a visible, meaningful action with the remaining capacity/turn (guard, observe, mark a target, hold a formation position) rather than simply banking unused movement silently. Read `docs/movement-model.md` §7 in full, `core/actors/behaviors/BehaviorArbiter.gd`'s `_spatial_utility()` and `_score()`, and `core/movement/MovementOptionService.gd` before designing anything.

---

## 7. Fix commitment/distance unit mismatch in movement scoring

**task_id:** `task_311bcc74`

**Why it came up:** Surfaced by qa-verifier during Phase 3c's final review of the movement-crawl fix (decision #28). The fix's `commitment_progress_ratio` term divides move cost by distance — equal today only because terrain cost is uniform. Jeff chose to track this separately rather than fix it now (decision #30).

**Opening prompt:**
> In the Echoes vNext Godot/GDScript repo, `core/actors/behaviors/BehaviorArbiter.gd`'s `_spatial_utility()` computes a `commitment` term as `commitment_progress_ratio` (added in V2-COMBAT-003.5 Phase 3c to fix a movement-crawl bug — see `docs/v2-combat-003.5-decisions.md` entry #28). This term divides a movement-cost value by `progress_origin_distance` (raw Chebyshev distance in cells, from `core/movement/MovementOptionService.gd`'s `_build_option()`).
>
> qa-verifier flagged during Phase 3c's final review: this mixes units. The numerator is movement cost (movement points spent), the denominator is distance (cells). They are numerically equal today ONLY because the live combat path uses uniform terrain cost (every cell costs 1 point to cross) and 8-way movement. The day non-uniform terrain cost is authored (e.g. difficult terrain costing 2 points/cell) or a hostile-control surcharge is added to cost, this term's meaning silently breaks — it will no longer represent "progress toward the goal, distance-normalized," which was the whole point of the Phase 3c fix.
>
> Investigate: should `commitment_progress_ratio` divide by actual movement cost instead of raw distance (so both terms share cost units), or does it need a different normalization entirely? Read `BehaviorArbiter.gd`'s `_spatial_utility()`, `MovementOptionService.gd`'s `_build_option()` and `progress_origin_distance`, and `docs/v2-combat-003.5-decisions.md` entries #28 and #30 for full context on why this term exists. Confirm whether any terrain-cost variance or hostile-control cost surcharge exists in the codebase today (if none does yet, this is a latent-but-real defect, not an active one). Propose a fix, get it feasibility-checked, then implement and add a test that would have caught this (e.g. a synthetic non-uniform-cost scenario). Run the compile check and the `movement_arbiter` test suite to confirm no regression.

---

## 8. Fix silent stand-still when an Echo has no reachable path

**task_id:** `task_c8dfaa47`

**Why it came up:** Found while diagnosing the PURSUE/ENDURE win-to-loss regression (decisions #32-34). Not the cause of that regression — confirmed pre-existing, exposed by longer fights, not caused by V2-COMBAT-003.5.

**Opening prompt:**
> In the Echoes vNext Godot/GDScript repo, `core/movement/MovementOptionService.gd`'s `generate_options()` can return `{valid: true, options: []}` when every cell of a movement goal's region is genuinely unreachable from the actor's origin (verified by direct shortest-path check under both the strict and authoritative-only walkable graph). When this happens, `core/movement/LiveMovementContextService.gd`'s `_movement_live_options()` falls back to `goal.legacy.stationary.actor_idle` with no rejection logged — the Echo silently stands still.
>
> This defeats `_movement_live_options()`'s own docstring guarantee that "a rejected goal is LOGGED, never dropped in silence." It was found during a V2-COMBAT-003.5 diagnosis (see `docs/v2-combat-003.5-decisions.md` entries #32-34): in the PURSUE fixture fight (seed 12346), from round 6 onward, 3 of 5 Echoes stand still while a fleeing quarry walks away, because their goal region became unreachable on that board — and nothing announces why. This reproduces identically on the pre-Phase-3c code path too, so it predates V2-COMBAT-003.5 and was only exposed by that story's longer fights, not caused by it.
>
> Investigate: is a `{valid: true, options: []}` result meant to be a distinct case from `{valid: false, ...}` (a real rejection) in `generate_options()`'s contract, or should an empty options array on a valid goal also trigger the rejection-logging path? Read `MovementOptionService.gd`'s `generate_options()` return contract and `LiveMovementContextService.gd`'s `_movement_live_options()` call site and its rejection-logging code. Fix so a genuinely unreachable goal is always logged, never silently swallowed into idle. Add a test proving an unreachable-goal scenario produces a logged rejection. Run the compile check and the `movement_arbiter`/`live_movement` filtered test suites to confirm no regression.

---

## 9. Review planning-graph narrowing from perceived_planning_cells intersection

**task_id:** `task_e06782cb`

**Why it came up:** Found while diagnosing the same PURSUE/ENDURE regression (decisions #32-34). Confirmed not the cause in the fixture tested (perceived and authoritative walkable sets happened to be identical there), but flagged as a risk on boards with limited perception.

**Opening prompt:**
> In the Echoes vNext Godot/GDScript repo, V2-COMBAT-003.5's Phase 3c live-wiring change (`core/movement/LiveMovementContextService.gd` now calling `MovementOptionService.generate_options()`) introduced a semantic narrowing of the movement-planning graph. The old path's `_movement_planning_walkable()` used `authoritative_walkable` only. The new path's `MovementOptionService._planning_walkable()` intersects `authoritative_walkable ∩ perceived_planning_cells`.
>
> This was found during a diagnosis of a separate regression (see `docs/v2-combat-003.5-decisions.md` entries #32-34) and confirmed NOT to be the cause of that regression — in the fixture tested (PURSUE, seed 12346), `perceived_planning_cells` happened to equal `authoritative_walkable` exactly (both 279 cells), so the intersection was a no-op there. But on a board where an actor's perception is genuinely limited, this intersection could silently reduce or eliminate viable movement options in a way the old code never did.
>
> Investigate: is including `perceived_planning_cells` in the planning graph an intentional design choice (Echoes should only plan routes through cells they can perceive), and if so, is a silent option-starvation risk acceptable, or does it need the same rejection-logging treatment as the sibling "silent stand-still" issue (task #8 above, `task_c8dfaa47`)? Read `MovementOptionService.gd`'s `_planning_walkable()` and `generate_options()`, `LiveMovementContextService.gd`'s old `_movement_planning_walkable()` (check git history/diff around the Phase 3c wiring commit for the pre-change version), and how `perceived_planning_cells` is computed and populated. Determine whether any current board/perception configuration can produce a meaningfully different result between the two graphs, and if so, whether this narrowing should be reverted, kept, or need additional logging. Report findings and a recommendation; only make code changes if the investigation finds a real defect, not just a theoretical one.

---

## 10. Same-`class_origin` Echoes still get identical vector_scores at Standing 1

**task_id:** `task_9a58ca1c`

**Corrected 2026-09-23 (Phase 6 combined verification):** this task's original premise — that
only 4 of 10 identity-vector origins are ever summon-able — is **false**. Directly tested by
summoning 200 Echoes: all 10 origins occurred (14-28 times each). `EchoFactory.gd:76-78`'s
4-entry literal (`protector`, `vanguard`, `seeker`, `pillar`) is only a FALLBACK used if
`data.summoning.class_origin_weights` is missing from `balance.json` — the real table has had
all 10 vectors since before this story (`git blame` shows 2026-04-26). The narrower, still-real
concern below is what's actually left open.

**Why it came up:** Found while refining V2-COMBAT-003.5's movement-style fix (decisions #33-36). Jeff required "2 new Echoes should never be the same" (decision #36) — two Echoes who happen to roll the SAME `class_origin` (out of the real 10 available) still get byte-identical `vector_scores` at Standing 1, since `archetype_init` scores by origin, not by individual Echo.

**Opening prompt:**
> In the Echoes vNext Godot/GDScript repo, `data/balance.json`'s `data.summoning.class_origin_weights` lists all 10 identity-vector origins (protector, vanguard, seeker, pillar, strategist, skeptic, devoted, opportunist, mediator, nurturer) — confirmed live and reachable, NOT limited to 4 (a prior version of this task wrongly claimed only 4 were reachable; `core/sanctum/EchoFactory.gd:76-78`'s 4-entry literal is a fallback for a missing config block only, never hit in production).
>
> The real, still-open gap: two Echoes who happen to roll the SAME `class_origin` get byte-identical `vector_scores` from `data.vectors.archetype_init`, so at Standing 1 they are mechanically indistinguishable in anything vector-driven (movement style, dominant-vector behavior, etc.) until lived experience differentiates them. Jeff explicitly required "2 new Echoes should never be the same" (decision #36). That story's fix (a `trait_nudge` reweight, decisions #35-36) works around this gap without closing it — traits still differentiate same-origin Echoes, but their vector identity itself stays collided.
>
> Investigate: should `archetype_init` itself vary per-Echo within a shared origin (e.g. a small deterministic per-Echo variance seeded off the Echo's own id, layered on top of the origin's base scores), or is the `trait_nudge` workaround judged sufficient and this should be closed as won't-fix? Read `docs/movement-model.md` §10.4 and any GDD sections on Echo identity/summoning before proposing a mechanism. If a fix is warranted, propose it to `mid-game-designer`/`sr-game-designer` (a design call, not a unilateral number pick) before implementing. This interacts with `GridService.dominant_key()`'s tiebreak order too (a related 4-vector-only gap, unrelated to the origin-roll question — flagged in `tests/CombatBaselineTests.gd:275-279`) — check whether that's worth fixing in the same pass. **Note (2026-09-22): Phase 5 unified the three duplicate `_dominant_key()` copies into one shared `GridService.dominant_key()` — the tiebreak-order gap itself (only 4 of 10 vectors named) is unchanged, but the function is no longer duplicated across `GridService.gd`/`CombatState.gd`/`ShrineService.gd`.**

---

## 11. BehaviorArbiter.gd has grown past its file-size guard

**task_id:** `task_ef33f74e`

**Why it came up:** Found during V2-COMBAT-003.5 Phase 5 recon (2026-09-22). The file was ~1,877 code lines at the Phase 3c snapshot; it is now 2,850 lines, well past the project's own ~1,000-line soft guard.

**Opening prompt:**
> In the Echoes vNext Godot/GDScript repo, `core/actors/behaviors/BehaviorArbiter.gd` is now 2,850 lines (measured during V2-COMBAT-003.5 Phase 5 recon, 2026-09-22). The project's own convention (see prior story plans, e.g. `docs/v2-combat-003.5-plan-snapshot.md`) treats this file's growth as guarded, with a soft target of ~1,000 code lines, on the reasoning that new scoring/behavior logic should get its own bounded file (the precedent set by `DecisionTrace.gd`, `GuidanceContribution.gd`, and `MovementStyleService.gd`, all of which extend `BehaviorArbiter`'s output without growing the file itself). It was ~1,877 lines before V2-COMBAT-003.5's Phase 3c work (which itself mostly avoided growing it further, per decision #18 in `docs/v2-combat-003.5-decisions.md`), but has since crossed 2,850.
>
> Investigate: what has been added directly into `BehaviorArbiter.gd` across recent stories (git blame / git log on the file) that could reasonably have been extracted into its own bounded service, following the `MovementStyleService.gd`-style pattern (a pure function/service that `BehaviorArbiter` calls, rather than logic embedded in `_score()` or its neighbors)? Identify 2-4 concrete extraction candidates with a rough line-count estimate for each, and propose a plan for extracting them (a design pass by `sr-game-designer`/`mechanics-developer` jointly, matching how `MovementStyleService.gd` was designed before V2-COMBAT-003.5 built it). Do not extract anything yet — this is a scoping/investigation task; bring findings back for a scope decision before any code moves, since this is a structural refactor that could touch scoring behavior if done carelessly (the `directive_bonus` flat-additive-outside-brackets invariant, and probably others, must survive any extraction unchanged).

---

## 12. Fix _read_field_cooldown's identical ordering bug

**task_id:** `task_3e1b8703`

**Why it came up:** Phase 5 fixed `_withdraw_cooldown`'s decrement-before-check ordering bug (it never blocked anything). `_read_field_cooldown` has the exact same shape and was deliberately left alone as out of scope at the time — found again during Phase 6 verification, still untracked anywhere in the repo.

**Opening prompt:**
> In the Echoes vNext Godot/GDScript repo, `core/actors/ActorStateMachine.gd`'s `_read_field_cooldown` (currently ~line 251-253, comment at ~line 260 calls it "already-flagged") is decremented unconditionally at the START of `advance_turn()`, before `BehaviorArbiter.gd`'s own check of it later in the same call (~line 1881 as of this writing, may have shifted). This is the exact same ordering bug `_withdraw_cooldown` had — fixed in V2-COMBAT-003.5 Phase 5 (`docs/v2-combat-003.5-decisions.md`, the mechanical-fixes batch) by moving its decrement to the end of the turn instead of the start.
>
> `_read_field_cooldown`'s fix was deliberately deferred at the time ("out of scope for this phase, leave it alone") but was never actually filed anywhere as a follow-up — Phase 6's combined verification (2026-09-23) found it again and confirmed no document in the repo tracks it.
>
> Fix it the same way `_withdraw_cooldown` was fixed: move the decrement from the start of `advance_turn()` to the end of the turn (inside `_update_passive_state()` or wherever the `_withdraw_cooldown` fix landed — read that fix's diff/commit for the exact pattern to mirror). Add a test proving the cooldown now actually blocks for at least one turn after it's set, matching the test added for `_withdraw_cooldown` (likely in `tests/CooldownTests.gd`). Run the compile check and relevant filtered suites (`cooldown`, `actor`, `behavior_arbiter`) to confirm no regression.

---

## 13. Hostile-Claimant fights can reuse an earlier fight's encounter_id

**task_id:** `task_d9eb5743`

**Why it came up:** Found during Phase 6 combined verification (2026-09-23), traced in code, not yet reproduced in play. Pre-existing (predates this story), made consequential by this story's board-variety work (decisions #1-3) — previously all stage encounters shared one board anyway, so an id collision was invisible.

**Opening prompt:**
> In the Echoes vNext Godot/GDScript repo, `core/runtime/controllers/ContactController.gd:663` transitions into ENCOUNTER state (a hostile Claimant fight) without setting `flow_ctx.encounter_id`. Nothing resets `encounter_id` after a fight ends — the only places that assign it are `core/runtime/controllers/VentureController.gd:258` and `:536`, onboarding, and the keeper intro flow.
>
> This means: if the party fights, say, `sit.3` in a stage, and later a Claimant turns hostile in that same stage, the Claimant fight inherits the leftover `encounter_id` from the earlier fight (e.g. `...sit.3`). Since `encounter_id` seeds terrain and spawn generation, the Claimant fight would get the SAME terrain and spawn cells as the earlier fight if both are COMBAT-type encounters. It would also silently skip its own ally-recruit roll, since `RecruitmentConsequenceService.gd:101` runs that roll once per `encounter_id` — and the id would already be "used."
>
> Investigate: confirm this reproduces in an actual play session (or a targeted test/probe) — a Claimant-turned-hostile fight in a stage that already had a prior fight should show terrain/spawn cells matching that prior fight, and the ally-recruit roll should not fire. If confirmed, fix by giving the Claimant-hostile transition its own real `encounter_id` (matching the pattern `VentureController.gd` uses), scoped appropriately so it doesn't collide with other fights in the same stage. Add a test. Run the compile check and relevant filtered suites (`contact`, `combat_terrain`, `recruit`) to confirm no regression.

---

## 14. GUIDE_SPIRIT/PURSUE board-stretch override ignores per-virtue terrain signature (compact board on low-plateau-count virtues)

**task_id:** `task_ashen_hallow_board`

**Why it came up:** Found during Jeff's Phase 8 in-game playtest of V2-COMBAT-003.5 (2026-09-26). Pre-existing (V2-STAGE-004-era board-stretch mechanism), unrelated to this story's GUIDE_SPIRIT escort-yield subject. Jeff: file as follow-up, do not fix now.

**Opening prompt:**
> In the Echoes vNext Godot/GDScript repo, GUIDE_SPIRIT and PURSUE combat boards are meant to stretch 5x (GUIDE_SPIRIT) or 4x (PURSUE) on one randomly-chosen axis — `core/combat/EncounterSetupService.gd` around lines 334-362, config at `data/balance.json` (`data.combat.board.guide_spirit_override.long_multiplier` / `pursue_override.long_multiplier`). This outer-bounds stretch is real (confirmed: a GUIDE_SPIRIT board on realm.01 spawned actors at row 65+ on an 18-col board), but the actual walkable terrain that fills those bounds is generated independently by `StageTerrain.generate()` (same file, ~line 325-360), whose plateau count and plateau width/height come **only** from the realm's virtue-specific terrain signature (`data/balance.json`, `data.combat.terrain_signatures.<virtue>`) — with no scaling relative to the stretched board dimension.
>
> Confirmed live in play: realm.01 ("Ashen Hallow"), virtue `courage`, has `plateau_count_min/max: 2/3` and `plateau_w_max: 16, plateau_h_max: 14` (`data/balance.json` ~line 3156-3167). On a courage GUIDE_SPIRIT board stretched to roughly 18 cols x 90 rows, only 2-3 small plateaus (each at most ~16x14) get placed at random positions across that whole span — they tend to land clustered together by chance, producing a small, connected walkable patch with most of the nominal board empty void. Jeff observed this directly: the board "looked compact in both directions, not stretched." By contrast, realm.02 ("wisdom" virtue, `plateau_count_min/max: 5/6`, richer island setup) filled a stretched board correctly and read as genuinely large.
>
> Courage's terrain signature was already flagged once before as under-tuned for anything but a small square board (`docs/v2-combat-003.5-decisions.md` entry — the earlier island-generation fix that raised base board size from 12x12 to 18x18 specifically to give courage boards any islands at all — 0 per 50 boards at 12x12).
>
> Investigate and fix: either (a) scale plateau count and/or plateau w/h max proportionally to the stretched axis when GUIDE_SPIRIT/PURSUE's board-stretch override is active, or (b) give GUIDE_SPIRIT/PURSUE their own plateau-count/size override per virtue (similar to how the board-bounds stretch already has its own override block), or (c) another approach that ensures every virtue's terrain signature fills a stretched board reasonably, not just wisdom's. This is a design/balance question as much as a code fix — confirm the intended fill density with Jeff (or sr-game-designer) before picking numbers. Add a regression probe (e.g. measure walkable-cell coverage as a fraction of board area across several virtues on a stretched GUIDE_SPIRIT board) so a future board-size or virtue-signature change doesn't silently reintroduce this. Run the compile check and relevant filtered suites (`combat_terrain`, `guide_spirit`) after any change.

---

## 15. Camera does not handle very large (stretched) GUIDE_SPIRIT/PURSUE boards well

**task_id:** `task_large_board_camera`

**Why it came up:** Found during Jeff's Phase 8 in-game playtest of V2-COMBAT-003.5 (2026-09-26), while testing GUIDE_SPIRIT escort mode on a genuinely large stretched board (realm.02, escort mode, board stretched to include a spawn at col 98). Pre-existing UI/camera behavior, unrelated to this story's own subject. Jeff: file as follow-up, out of scope.

**Opening prompt:**
> In the Echoes vNext Godot/GDScript repo, GUIDE_SPIRIT and PURSUE combat boards can legitimately stretch 5x/4x on one axis (see follow-up task #14 and `core/combat/EncounterSetupService.gd` ~lines 334-362), producing boards up to roughly 90-100 cells long on the stretched axis. Jeff found during playtesting that the combat camera does not handle a board this large well — investigate the actual symptom (e.g. camera zoom/bounds clamped to a smaller assumed max board size, follow behavior breaking down, or visual/readability issues at extreme zoom-out) in whatever script owns combat camera bounds/follow (likely under `ui/screens/combat/` or a `CombatCamera`-named script — locate it first). Reproduce using the debug console: `combat_objective guide_spirit escort nojoin`, then enter a combat encounter on a realm whose virtue produces a well-filled stretched board (e.g. wisdom), and observe camera behavior as the spirit escort/party traverses the long axis. Propose a fix scoped to camera-only (do not touch board generation, which is task #14's subject). This is likely a design/feel question (how should the camera behave on an extreme-aspect-ratio board) as much as a code fix — loop in game-feel-developer.
