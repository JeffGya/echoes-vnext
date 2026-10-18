# V2-DIRECTIVE-002 — Follow-ups

Findings from phase A that are not part of phase A. Each item names its source and its owner today.
Jeff decides scope. Nothing here is fixed unless it says so.

## Contact window (screenshot review, 2026-10-11)

**Decision (Jeff, 2026-10-11, D-22): these are a separate story for later, not part of V2-DIRECTIVE-002. Pick them up another time.** A candidate title: "Contact window: readable Echo cards". Nothing is fixed. No Notion story exists yet; create one only when Jeff asks.

Source: the hand-built fixture screenshot of the Contact window picker (ui/overlays/realm/ContactModal). All four are old. None comes from this story. Owner: not assigned.

| # | Finding | Where |
|---|---|---|
| 1 | Raw calling ids ("onyamesu", "okomfo", "aduro", "sum_okwanfo") show on the Echo cards. This breaks "no IDs in player-facing display". | `ui/overlays/realm/ContactModal.gd` (card `calling` field) |
| 2 | With four Echoes, three cards fit in a row. The fourth card falls below the scroll fold and is cut off. | `ui/overlays/realm/ContactModal.tscn` |
| 3 | The bid badge is a tiny diamond with no text. Colour is the only carrier of the alignment versus fear difference (accessibility rule: colour is never the only meaning). A grey "no bid" badge is not visible. | `ContactModal.gd` `_bid_badge_text`, `_bid_badge_color` |
| 4 | "Hear Them Out" is greyed out until a card is picked and has weak contrast. Probably intended. | `ContactModal.tscn` |

## Phase A QA nits (2026-10-11)

Owner: phase B+C, which edits the same guard.

- `DirectiveService.validate_entry_schema` skips keys with `begins_with("_comment")`. A real key such as `_commentary_x` would be skipped silently. Use `_comment_` or an exact match.
- Guard log text says "is not a array". Use "is not of kind %s".
- The F3 test comment hard-codes "177 .gd files". The number goes stale.
- `ConfigService.get_balance()` returns a deep copy. Phase A added one more call per snapshot in `SanctumSnapshotBuilder` and `FlowStageState`. Cost only.
- The fallback `_REGISTRY` entries in `DirectiveService` have no `contact_effects`. With an empty config the fallback gives Scout no bid boost. Production always has config.

## Open items for Jeff

- **Picker wording (D-18).** Config `description` holds today's picker text for now. Rewrite both lines in the project voice before phase B+C. Notes from the review: "Do not give more than the run asks of you" reads as a hard limit; "Something in this realm is waiting to be found" promises a sure find while the pro says "Higher chance"; both lines are mythic on a routine choice; aim for a short spoken order to people (about 15 words or fewer), no jargon such as "intel", intent and not result, no repeat of pros and cons.
- **`witness_resonance_bonus` (D-16).** Value 0.1 is PROPOSED DEFAULT. It has no reader yet. Phase B+C wires it: +0.1 on the turn resonance score of every conversation under Seek Signs. The key name says "witness" but the effect is broad. Renaming it is allowed under the AGENTS.md exception (no reader exists) and needs Jeff's yes.
- **`encounter_approach.directive_id`.** Phase A writes the right Directive id. Nothing reads the field yet, so players cannot see it.
- **UI per-id label and colour.** `StageExploreScreen.gd` `_label_for_directive` and `DirectiveBadge.gd` match by id. A third Directive shows an empty label there. Phase B+C frontend step reads label and colour from the Directive entry or the theme.
- **Seek Signs friction** (ANSWERS #46: 4 divergences in 535 turns). Players may always pick Scout Carefully. It needs payoffs only Seek Signs gives.
- **Known red test** `movement_arbiter/avoid_overcommit_stays_proportionate` (pace-reward follow-up #11, v2-combat-003.5 decisions #29/#38). Not part of this story.

## Found in the numbers step (2026-10-12), not fixed
- `core/realms/ConversationService.gd:297`: NPC morale `<= 20` in the emotional fit, plus bonuses 0.2 and 0.1 at `:291` and `:299`. These are hard-coded tunables next to the ones moved for ANSWERS #83. Not in design 10.1. Decide: join the config sweep or stay a follow-up.
- `DirectiveService._REGISTRY` fallback (`DirectiveService.gd:61,81`) still holds the OLD picker text. It shows only when the config registry is empty.
- `stages.party_return_fear_threshold` (60) and `stages.cautious_advance_fear_threshold` (50) already sit in config. They were not touched.

## Found in slice S2e (2026-10-13), for the designer and Jeff
- Under Scout, a calm party cannot change the first plan with today's numbers (opus, S2e). Commitment depth is always 2 (D-50). Scout's weights have no tie that a category bend breaks. The exposure price rounds per cell; the Scout tolerance stays between 0.18 and 0.42, so a cell with exposure 0.67 always costs 3 (rounding boundary at tolerance 0.4375). So Scout naming can name only fear or morale. Design contrasts S1 and P1 cannot occur under Scout. Question for `mid-game-designer` and Jeff: change the `exposure_tolerance` bound or the price rounding so that a Scout lean can change a route? Test P1 was built on Seek.
- `StagePartyStance.build` raises the `builds` counter. When S3 calls naming inside `advance_turn`, `traversal/one_stance_per_advance` counts the dry runs too. S3 must separate Advance builds from dry-run builds.
- A frontier target pays the reachable region twice (`select_frontier` builds its own region; D-51 gives it no new argument). Cost is small (15 to 22 ms).
- Stale rows in `backend-plan.md`: the S2c "Files" row names `select_frontier`; the "Fingerprints that move" row mentions `route_character` (deferred, D-51). FIXED (QA package C, 2026-10-13).

## Found in slice S3 attribution (2026-10-13), for Jeff (opus review)
- F1 Exposure pause exemptions: no pause on the first step of an Advance (supports design 9, no soft-lock) and no pause before the target cell (the builder's own rule; no design text supports it; inconsistent: in `gen100_scout` the party paused one cell before the hostile target, but not on the target cell). Options: keep; exempt the whole route when the target is the exposure source; remove the exemption and re-record `p5_tier1_hard_stops_on_arrival` and `fog_light_bias_seek_engages`.
- F2 `spotted_ahead` stops every Directive (design 3a, movement model 11.7), but the code ignores `reveal_stop_kinds` for it. The `spotted_ahead` entries in `directive_profile.<id>.reveal_stop_kinds` do nothing; a data-only Directive cannot switch it off. Decide which source is authoritative: the list, or rule 11.7 (then remove the list entries).
- F3 D-36 text defines `arrived_at` as 'walked into a situation'; design 3a defines it as 'target reached'. The code follows 3a. D-36 needs a correction in the decisions doc.
- F4 Party width for the noise filter is the mean `interpretation_width` (design does not say mean, min or max).
- F5 The terrain cause is forced when a detour is refused on ANY leg and no Echo is named; naming is first-plan only (D-46). One `travel_why` can mix legs and replace a correct first-plan cause. Limit to the first leg?
- F6 (defect in S3) The `presentation` snapshot key copies `stages.presentation` with its `_comment` string: developer text reaches the UI payload, and the stage fingerprint depends on comment wording. Fix: strip `_comment*` keys in the builder or in `get_stage_presentation_cfg`. The hash moves once more.
- F7 The shared reason `interrupted` now means both 'entered a situation' and 'a stop kind fired'. The player kind still tells them apart.

## Found in slice S3b (2026-10-13), assumptions to confirm with Jeff
- F1 reading: 'the target is the exposure source' means the pause leaves out the target hostile only. A party that walks to hostile A still pauses near hostile B. (Alternative: no pause at all on a route to a hostile target; no fixture differs, gen100 has one hostile.)
- Under F1 a party now pauses before a NON-hostile target that lies in a hostile's zone (Scout before the loot at 2,0 in `fog_light_bias_seek_engages`). Alternative: keep every target cell exempt.
- `fog_light_bias_seek_engages`: the test read changed (null pending id read as empty); assertions unchanged. A test-read change, not a re-record.
- F2 effect: a Directive with no profile (empty list) never stops on an objective or hostile reveal. Alternative: a safe fallback that keeps `spotted_ahead` on.
- `data/balance.json` comment on `stages.party_stance.stop` and `directive_profile` should say the list also controls `spotted_ahead` (mid-game-designer edit). FIXED (QA package C, 2026-10-13).

## Found in slice S4b (2026-10-13)
- Numbers question for `mid-game-designer` and Jeff: with the shipped numbers (`apply_threshold` 0.45, judgment weight 1.0, fear weight 0.6) suppression releases at fear 10 when the width is above about 0.49. A real rank-6 Echo with xp_total 40 and no bonds has width 0.489 and stays silent; one with xp_total 1000 bids. The design example '0.6 bids' holds only for an Echo with high xp.
- Existing gap: `EchoActor.from_echo` does not copy `storyweight`; `derive_expression` falls back to `xp_total`, so stage and combat Judgment use `xp_total`.
- Behaviour change to test in play (design 6a row 11): a frightened wise Echo whose Calling is suppressed now bids 'reactive' (before: silent). Probe: Scout Carefully contact, rank-6 `aduro` Echo at fear 60, expect the 'Reacting from fear' card.

## Found in slice S5 (2026-10-13)
- The plan rule 'carry only when `locked` is true' has no effect: `_lock_map_if_needed` runs before `_reset_session_state`, so `locked` is always true there. The carry rule uses `party_state` instead (proposed lifetime table in the S5 report; Jeff approves).
- The comment at `FlowStageExploreState.gd:91-94` says party_pos is reset 'only when the stage first locks'; the code keeps `party_pos` and `turn_count` always. The comment looks wrong, not the code. FIXED (QA package C, 2026-10-13).
- An encounter retreat (`FlowRuntime._handle_encounter_retreat`) does not set `escaped`, so after a retreat and a later entry the old journey entry still shows.
- `ally_contact`, `target_situation_id` and other durable keys are repaired in `SaveService` but are not in the reset key list, so every `enter()` drops them (`DebugController.gd:303` already notes it).
- If the Directive changes inside a stage, a carried `last_effective_steps` can exceed the new `step_budget` (possible since S3).
- Exception E1 to the AGENTS.md save rules: a malformed `last_effective_steps` is erased, not defaulted; an absent key is its valid empty state. No field removed from the schema.
- C1 field `leg_start_length` (-1 = no leg) is saved and repaired; nothing writes it yet (C1 is built later, D-48).

## Found in QA package A (2026-10-13)
- The counterfactual first plan can differ from the real walk for the same party. In the QA case the plan path has 3,4 where the real walk has 3,5. This looks like QA note N1: the naming plan does not model the exposure pause and the reveal stops. The naming compares two plans; if the base plan is not the real walk, a name can be wrong. Not fixed (D-54 did not select N1). Decide later: make the base plan equal the real result (S1a keeps `last_result`).
- A profile-less Directive has no candidates. A shaken party loses a step, but no Echo can be named for the loss. The cause is 'directive' or 'party'.
- `steadied` is a fallback label: it covers every named Echo where no single class changes the plan (party mean, party size, bond edges, or a mix). It is not proof that only the mean moved.
- The `counterfactual` comment in `data/balance.json` still says 'at most 9' and names `replan_cap_per_effective_step` (package B and C own it). FIXED (QA package C, 2026-10-13).

## Found in QA package D (2026-10-13)
- Correction to QA note N1: the model plan and the real walk differ in the QA case because of equal-cost route ties under per-step replanning (diagonal ties near an exposure source), not because the model skips pauses or reveal stops. All 24 drops in the probe were route ties; none came from a walk that stopped early.
- Fallback rate in the probe: 24 of 185 proposed names (13.0%), 24 of 369 Advances (6.5%); all on Advance 0 of boards with a hostile near the start. Test boards, not real maps.
- Open choice for Jeff: accept the drop rate, or make the model use the live per-step route tie rule so the ties match (a model change; not option 3).

## Found in QA package E (2026-10-13)
- Speed after package E (M2 Mac, headless, 576 Advances before and after, outputs byte-identical): naming mean 70 to 101 ms before, 8 to 34 ms after; the whole dispatch with 5 Echoes 338 ms (Scout) and 484 ms (Seek) before, 169 ms and 228 ms after. Target met (D-55).
- Remaining cost: each step after the first still builds a full reachable region in `find_explore_target` and runs two route searches (owner: V2-INFRA-010).
- The snapshot rebuild costs about 60 ms per dispatch, about a third of the new Advance cost. No story owns it. Decide: V2-INFRA-010 takes it, or a new story.
- One isolated naming maximum is 220 ms (5 Echoes, Scout), probably a terrain-cause Advance where `_only_way` runs one path search per path cell. Not measured apart.
- The `_data_subtree` check `get_script() == ConfigService` keeps test subclasses that override `get_balance()` working (LESSONS #35). Do not remove it.
- The new equivalence test `traversal/shared_region_same_naming_and_frontier` costs about 4.5 s of suite time.

## Found in PR 107 review (2026-10-16)
- `ConversationRepairTests._restore_save` (`tests/ConversationRepairTests.gd:64`) restores only the primary save file. Boot and dispatch can leave `.pending_*`, `.tmp` and `.bak*` files beside it (AGENTS.md lines 151-158). Seven callers in that suite use it. `StageExploreP5Tests` and `UnifiedResolveTests` have their own primary-only helpers. Risk is low: each process has its own save folder. Fix: call `TestSaveHarness.remove_save_artifacts` inside the helpers. This is a separate story. `ContactBidScalingTests` is already fixed at its own call site (commit 9776aac).

## Found in phase D slice 1 and 2 (2026-10-16)
- Stale numbers in `scripts/run-tests-sharded.sh` comments: line ~21 says shard4 has "~16 sibling suites" (it has 19); line ~24 and `AGENTS.md` ~242 say "~124" suites (the count is 132); line ~93 says shard1 and shard7 are "the two smallest shards" (shard7 has 3 suites, shard1 has 9, shard8 has 10).
- Shard 8 now holds `fingerprint_seek` (about 3 minutes). Its alarm is 700 s. A timed sharded run must read shard 8's `elapsed_secs`. If it nears 700 s, add an alarm override or move the suite.
- The "Names that look right and are WRONG" paragraph in `AGENTS.md` lists fingerprint modes and does not mention `fingerprint_seek`.

## Found in phase D final QA and docs pass (2026-10-18), for Jeff
Nothing here is fixed. Jeff decides scope.

- **Divergence check, four Directive parts.** The check removes the Directive acceptance part and the Directive stop bias from the Echo's own judgment. The four other `directive_*` spatial parts still count as the Echo's own judgment: `objective_advance`, `avoid_overcommit`, `ally_protection`, `threat_interception` (`spatial_utility.directive_*_weight`). Decide: remove them too, or keep.
- **Resolve screen, pre-fight fear.** The real pre-fight fear is not saved. The resolve screen's `pre_status` uses the Echo's base fear (`status_from(pre_morale, 0, fear_base)` in `EncounterSnapshotBuilder`). The pre-fight chip can differ from the real state at fight start.
- **Two Echo gates.** Slice 7 (style growth) uses the faction-only gate (`faction == "echo"`). Slices 5 and 6 use `EmotionStatusLean.is_echo` (faction and kind). A temporary ally gets style growth and no lean or steps. Decide: one gate (rule D-87).
- **Probe output.** The `STOPRATE_SUMMARY` and `STOPCAUSE` lines of `tools/SpatialTermProbe.gd` did not appear in the output of the D-90 run (only the per-Echo lines). Who stops (Directive, fear or identity) is not measured.
- **Stop-rate reference.** The 25 percent reference (stop-short decision #108) is not a config key. The probe prints rates and checks no ceiling (`echoes_above_ceiling=n/a`).
- **Raw fear and morale readers left (options C6 and C7, deferred by Jeff, D-89 Q5).** Style alignment (`style_inputs`) and the action-layer fear factor (with `morale_action_muls`) still read raw fear and morale. They are a second reading of the same systems (D-87). They need their own story.
- **Known red test** `movement_arbiter/avoid_overcommit_stays_proportionate` (`tests/MovementArbitrationTests.gd:41`, :835) has no owner. It was red before phase D.
- **Stale comments in `scripts/run-tests-sharded.sh`** (see the slice 1 and 2 item above). The count of suites is now 133. The suites `felt_state` (shard 1) and `fingerprint_seek` (shard 8) are in the shard map since commit 32a55b0.
- **`ConversationService.gd:591-595`** keeps a status-to-band literal (`_emotional_fit_band`): a second table of the ten statuses beside `EmotionService.STATUS_LADDER`.
- **Dead text.** `data/shouts/stop_short_text.json` keeps `cause_clause.morale`. No cause row uses it (`StopShortService.CAUSE_ROWS` has fear, identity, directive). Low morale now acts through the fear row (the afraid part of the status).
- **Composure for slice 6 is one activation old.** The profile is built before the activation's composure exists; `LiveMovementContextService._with_state_steps` reads `actor["_composure"]` from the previous activation (default `felt_state.steps.composure_default`). A fresh Echo uses the default.
- **`felt_state.ranges`.** The validator limits in `felt_state.ranges` (lean, steps, step counts) are PROPOSED DEFAULT and Jeff has not reviewed them. They decide which config values the validator accepts.
- **Stale test comment.** The doc comment above `_t_stage_bound_not_read_in_combat` (`tests/MovementArbitrationTests.gd:1933`) says "Combat code may read only the two shared ramp keys of the stage block". No ramp key exists any more. The test scans for `directive_profile`, `lean_strength` and `leans`. (Docs pass cannot edit tests.)
- **Exposure choices are rare** (D-80: 1 to 2 percent of Echo decisions in the 7 fixed fights). Watch note on V2-STAGE-010 exists (D-85). Overlap with V2-COMBAT-004 slices 004B and 004D is for Jeff to settle.
