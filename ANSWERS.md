# ANSWERS.md — Project Q&A Log

> Source of truth for design decisions and clarifications. Agents: check here FIRST before
> asking the user. Keep entries brief — question ≤ 1 sentence, answer ≤ 5 sentences.

## Overview

| # | Slug | Topic | Date |
|---|------|-------|------|
| 1 | prog011-story-scope | V2-PROG-011 is backend-only: save fields + stage machine + snapshot data, no UI | 2026-06-26 |
| 2 | prog011-confidence-field | Confidence = stored int score (rises/falls) + derived inputs; not displayed directly | 2026-06-26 |
| 3 | prog011-service-boundary | Recognition state lives in CallingService — no new service | 2026-06-26 |
| 4 | prog011-ui-expression | Recognition is ephemeral — expressed via barks and keeper nudges, no visible meter | 2026-06-26 |
| 5 | prog011-bark-home | Recognition bark wiring goes into a non-done SANCTUM story (SANCTUM-004 or SANCTUM-005) | 2026-06-26 |
| 6 | prog011-nudge-home | Keeper nudge for recognition goes into V2-CONTINUITY-002 | 2026-06-26 |
| 7 | pursue-camera | PURSUE combat board needs Camera2D with auto-follow + player pan/zoom override | 2026-06-28 |
| 8 | pursue-board-size | PURSUE board is 2× one dimension (randomized wide or tall per seed), organic terrain | 2026-06-28 |
| 9 | pursue-enemy-spawn | PURSUE spawns quarry only — no regular enemy group | 2026-06-28 |
| 10 | pursue-quarry-visual | Quarry gets an icon or shape overlay to distinguish it from regular enemy tokens | 2026-06-28 |
| 11 | pursue-escape-condition | Defeat = quarry reaches board edge OR window_turns expires — both tracks active | 2026-06-28 |
| 12 | guide-spirit-joins-fully-active | Escort spirit that joins battle is a fully active ally, not passive | 2026-07-04 |
| 13 | spirit-escort-destination-random-edge | Escort destination is a seeded random walkable edge cell, distance-guarded | 2026-07-04 |
| 14 | spirit-escort-gated-movement | Escort spirit only advances toward destination while echo is nearby | 2026-07-04 |
| 15 | spirit-barks-key-moments | Spirit barks fire at 4 key moments via new spirit_barks.json data | 2026-07-04 |
| 16 | guide-spirit-pursue-gen-pools | GUIDE_SPIRIT and PURSUE both join stage-generation objective pools | 2026-07-04 |
| 17 | guide-spirit-skittish-protect | Spirit flees when threatened and unescorted, unlike static PROTECT totem | 2026-07-04 |
| 18 | guide-spirit-long-board | GUIDE_SPIRIT reuses PURSUE's board-override mechanism with a longer multiplier | 2026-07-04 |
| 19 | p5-travel-beat-all-layers | Phase 5 ships all four explore-travel-beat layers: progress bar, proximity flash, echo barks, Anansi snippets | 2026-07-06 |
| 20 | p5-hud-component-upgrades | Phase 5 upgrades directive text and combat objective text to authored DirectiveBadge + ObjectiveBanner components | 2026-07-06 |
| 21 | p5-choice-ui-engagement-popup | Obstacle/structure choice branches are picked on the arrival/engagement popup, not a dedicated overlay | 2026-07-06 |
| 22 | p5-polish-and-phase-order | Ghost footprint, combat-entry beat, and accessibility pass all ship in P5; Phase 4 comes after and closes the story | 2026-07-06 |
| 23 | p4-contact-outcome-states | Contact outcomes are role-agnostic good/partial/failed; failed vs abandoned Charge distinction; seam sites in FlowRuntime | 2026-07-11 |
| 24 | p4-ally-build-mirror-spirit | Temp ally is built like the joined spirit: ally_def_id template, completion-scaled level, damage dampener | 2026-07-11 |
| 25 | p4-ally-death-exclude-knock | Ally excluded from all_echoes_dead (party wipe = defeat); its death applies a small party morale/fear knock | 2026-07-11 |
| 26 | p4-charge-pressure-moderate | Failed non-objective Charge sets hostile_charge_sit_id → ENDURE +1 wave_size / PROTECT +1 duration_turns, consumed once | 2026-07-11 |
| 27 | p4-ally-echobar-plain-card | Temp ally shows in EchoBar as a plain party card (auto via faction=="echo"); no distinct slot in P4 | 2026-07-11 |
| 28 | p4-recruit-mechanic | Surviving temp ally can be recruited as a roster Echo via an earned chance (base 0, cap 75), additive conversation+combat+fit formula | 2026-07-11 |
| 29 | p4-recruit-agency-offer | Successful roll earns an OFFER; Keeper accepts/declines on Resolve (Guidance over Control), not auto-join | 2026-07-11 |
| 30 | p4-recruit-companion-identity | Recruited ally = full Echo, fresh Standing 1, but keeps a durable "companion" origin + bond-integration debuff (harder/antagonistic) | 2026-07-11 |
| 31 | p4-recruit-gate-survival-victory | Recruitment gated on ally alive AND encounter won (not survival alone) | 2026-07-11 |
| 32 | p4-contribution-ledger-tier-split | Tier 1 (offensive: damage/kills, both factions) generalizes echo_action_logs in P4; Tier 2 (support attribution, ~9 sites) is its own parallel story | 2026-07-12 |
| 33 | p4-ships-complete-ui | P5 already shipped, so P4 authors its own complete UI; ally visual line = Mist Blue + ⊕ Odo Nnyew glyph (ally badge, board ring, Companion tag, recruit-offer panel, seam cues) | 2026-07-12 |
| 34 | p4-companion-invite-sanctum-event | Recruit offer moved OFF Resolve → durable sanctum.companion_invite event on Sanctum entry; no-stack (one max); persists until decided | 2026-07-15 |
| 35 | p4-guide-spirit-routing-fix | guide_spirit added to SituationResolutionService._ASYNC_OBJ_TYPES (pre-existing Phase 3c soft-lock); folded into the P4 PR | 2026-07-15 |

---

## Entries

### 1. prog011-story-scope

**Q:** Is V2-PROG-011 a pure data scaffold or does it include stage machine logic?
**A:** Backend only — no downstream stories are currently Ready, so the full stage machine is in scope. This story delivers: save schema additions, CallingService stage machine methods, and snapshot fields as raw data. No UI, no bark wiring, no keeper nudge surface. See `core/progression/CallingService.gd` for the service that owns this.
**Source:** Jeff, 2026-06-26
**Date:** 2026-06-26

---

### 2. prog011-confidence-field

**Q:** What data type and meaning does the "confidence" field in V2-PROG-011's DoD refer to?
**A:** A stored integer score (no fixed max defined yet) that can rise and fall over time. At runtime, confidence is derived by combining the stored base score with existing echo fields: standing, dominant_vector, morale, and calling alignment. It is never surfaced directly in the UI — the player experiences it ephemerally through barks and keeper suggestions. Pattern matches `emotion` and `vector_scores` on the echo dict.
**Source:** Jeff, 2026-06-26
**Date:** 2026-06-26

---

### 3. prog011-service-boundary

**Q:** Should recognition state mutations live in CallingService or a new RecognitionService?
**A:** Extend CallingService. Recognition is part of the calling arc (post-S9), so it belongs alongside S3/S6/S9 calling logic. No new service file is introduced by this story.
**Source:** Jeff, 2026-06-26
**Date:** 2026-06-26

---

### 4. prog011-ui-expression

**Q:** Does V2-PROG-011 include any UI surface for recognition state?
**A:** No. Recognition state is intentionally ephemeral — the player experiences it through barks and keeper suggestions, not a visible meter or widget. Snapshot fields carry the data as raw values for other systems to consume, but no UI component renders them directly in this story.
**Source:** Jeff, 2026-06-26
**Date:** 2026-06-26

---

### 5. prog011-bark-home

**Q:** Which existing non-done story absorbs recognition bark wiring for combat/encounter contexts?
**A:** A non-done SANCTUM story — V2-SANCTUM-004 (sanctum pulse layer) or V2-SANCTUM-005 (incident framework). V2-VOICE-001 is Done and cannot absorb it. Confirm the specific story when SANCTUM-004 or SANCTUM-005 are prepped.
**Source:** Jeff, 2026-06-26
**Date:** 2026-06-26

---

### 7. pursue-camera

**Q:** Does the PURSUE combat board need a camera with panning and zooming?
**A:** Yes. `CombatBoardScreen` needs a `Camera2D` that auto-follows the quarry (the primary focus actor). The player can override with manual pan and zoom. This infrastructure did not exist before Phase 3b and is new scope. Other modes (GUIDE_SPIRIT) may reuse it later.
**Source:** Jeff, 2026-06-28
**Date:** 2026-06-28

---

### 8. pursue-board-size

**Q:** What board dimensions should PURSUE use?
**A:** 2× the standard board in one dimension, randomized per realm seed (sometimes wide — 2× cols, sometimes tall — 2× rows). Terrain is generated by the existing `StageTerrain` rules (plateaus + bridges + stragglers) so it stays organic. Standard board is 12×12 base + 1 per completion; PURSUE doubles whichever dimension is chosen.
**Source:** Jeff, 2026-06-28
**Date:** 2026-06-28

---

### 9. pursue-enemy-spawn

**Q:** Should regular enemies spawn alongside the quarry in PURSUE mode?
**A:** No. The quarry is the only adversarial actor. `FlowEncounterState.enter()` must skip the regular `enemy_actors` build for PURSUE. Quarry escorts ("quarry that calls escorts") are explicitly deferred to a later story.
**Source:** Jeff, 2026-06-28
**Date:** 2026-06-28

---

### 10. pursue-quarry-visual

**Q:** How should the quarry be visually distinct from regular enemy tokens on the combat board?
**A:** The quarry gets an icon or shape overlay on its token (e.g. a footprint or directional arrow) so it is immediately identifiable. The base token colour/shape can stay the same; the overlay is the differentiator. Exact asset to be designed; `CombatTokenLayer` renders it gated on `actor.is_quarry == true`.
**Source:** Jeff, 2026-06-28
**Date:** 2026-06-28

---

### 11. pursue-escape-condition

**Q:** What are the defeat conditions for PURSUE mode?
**A:** Both tracks are active simultaneously — whichever fires first: (1) quarry's `grid_pos` reaches any board edge → `quarry_escaped = true`; (2) `round_counter >= window_turns` and quarry still uncontained → `window_expired`. Both are already implemented in `CombatState.check_end_condition()`. Win = `contain_counter >= contain_rounds` (consecutive adjacency) or quarry killed.
**Source:** Jeff, 2026-06-28
**Date:** 2026-06-28

---

### 6. prog011-nudge-home

**Q:** Which existing non-done story absorbs the sanctum keeper nudge for recognition state?
**A:** V2-CONTINUITY-002 ("Add mythic recognition scaffolding as a fallible multi-step pipeline") absorbs the keeper nudge. It is the house-side sister story to V2-PROG-011 and is the right home for sanctum-facing recognition expression.
**Source:** Jeff, 2026-06-26
**Date:** 2026-06-26

---

### 12. guide-spirit-joins-fully-active

**Q:** When the escort spirit rolls its 50% joins-battle chance, does it actively fight?
**A:** Yes — fully active ally in Phase 3c: faction "echo", routed to BehaviorArbiter, appended to END of initiative order, melee damage ×0.75 via `_spirit_damage_mul` in CombatService._resolve_melee (mirrors PROTECT's `_double_damage_mult` pattern). Supersedes the "Later" deferral in docs/combat-modes-distinctiveness.md for this piece. Move intents for is_spirit actors are suppressed — destination movement stays with the escort-gated _end_round step.
**Source:** Jeff, 2026-07-04
**Date:** 2026-07-04

---

### 13. spirit-escort-destination-random-edge

**Q:** Where is the escort destination seeded?
**A:** A seeded random walkable edge cell on ANY board edge (namespace `combat.spirit_destination.<encounter_id>`), guarded by a tunable `destination_min_distance` (default 6) from the spirit spawn.
**Source:** Jeff, 2026-07-04
**Date:** 2026-07-04

---

### 14. spirit-escort-gated-movement

**Q:** Does the escort spirit keep walking once triggered, or only while escorted?
**A:** Escort-gated — after first echo adjacency starts the escort, the spirit steps 1 cell/round toward the destination ONLY on rounds where a living echo is within `escort_radius` (Chebyshev, default 2, tunable); otherwise it stops and waits. Mirrors the RECOVER hold-adjacency pattern.
**Source:** Jeff, 2026-07-04
**Date:** 2026-07-04

---

### 15. spirit-barks-key-moments

**Q:** When does the spirit bark and how much content ships in 3c?
**A:** Key moments — new `data/bark/spirit_barks.json` with 4 moments (first_adjacency, escort_start, guide_win, spirit_killed), ≥3 variants each, deterministic variation_key selection, displayed via the existing BarkPopupLayer pipeline. Spirit name drawn from `NameBank.build_full_name(gender, rng)` on namespace `combat.spirit_name.<encounter_id>`.
**Source:** Jeff, 2026-07-04
**Date:** 2026-07-04

---

### 16. guide-spirit-pursue-gen-pools

**Q:** Should guide_spirit and pursue enter the stage-generation objective pools?
**A:** Yes, both — appended (append-only, no reorder) to both realms' `objective_pool` in realms.json and the foundation pool in balance.json. Already-generated saved stages keep their objectives; only new stages roll the new types.
**Source:** Jeff, 2026-07-04
**Date:** 2026-07-04

---

### 17. guide-spirit-skittish-protect

**Q:** How does GUIDE_SPIRIT protect-in-place differ from PROTECT?
**A:** The spirit is skittish — when an enemy ends the round within `skittish_radius` (default 3) of the spirit AND no echo is adjacent to it, the spirit flees 1 walkable cell away from the nearest enemy (deterministic away-step, stable tiebreak, no RNG). Protecting means keeping an echo beside it to keep it calm — distinct from PROTECT's static totem + theft mechanics.
**Source:** Jeff, 2026-07-04
**Date:** 2026-07-04

---

### 18. guide-spirit-long-board

**Q:** What board does GUIDE_SPIRIT use?
**A:** Long board for BOTH variants via the PURSUE override mechanism but longer — `data.combat.board.guide_spirit_override.long_multiplier: 5.0` (PURSUE is 4.0), one dimension randomised wide-or-tall per encounter seed, applied post-clamp.
**Source:** Jeff, 2026-07-04
**Date:** 2026-07-04

---

### 19. p5-travel-beat-all-layers

**Q:** How much of the four-layer explore travel beat ships in Phase 5?
**A:** All four — StepProgressBar (kente segments + text fraction), proximity-reveal flash on markers, echo travel barks (wire ShoutBank's existing journey.json context into a new `travel_bark` snapshot field), and Anansi travel snippets (new `data/stages/anansi_travel_snippets.json` + `travel_snippet` field, loader mirrors `_load_spirit_barks`). Max one bark + one snippet per Advance, deterministic variation-key selection.
**Source:** Jeff, 2026-07-06
**Date:** 2026-07-06

---

### 20. p5-hud-component-upgrades

**Q:** Upgrade the plain directive text and combat objective text to authored components?
**A:** Yes, both — DirectiveBadge (.tscn glyph + left-edge tint: Mist Blue Scout / Akan Gold Seek, fed by a new composite `directive {id, label}` snapshot field) and ObjectiveBanner (compact ~85% opacity panel, ≤48dp, per-mode layouts for all SEVEN modes incl. GUIDE_SPIRIT; banner shows the instruction, the EchoBar spirit slot keeps health/progress — no duplication).
**Source:** Jeff, 2026-07-06
**Date:** 2026-07-06

---

### 21. p5-choice-ui-engagement-popup

**Q:** Where does the player pick obstacle/structure choice branches?
**A:** On the arrival/engagement popup — the two authored choice CTAs replace plain Engage for those types, dispatch `stage.resolve_situation_choice`, and the outcome flows through the normal ResolveScreen overlay. Supersedes §H's dedicated overlay panels (already superseded by the P1 unified resolve surface). Requires `situation_pending.choices[]` in the snapshot.
**Source:** Jeff, 2026-07-06
**Date:** 2026-07-06

---

### 22. p5-polish-and-phase-order

**Q:** Do the ghost footprint, combat-entry beat, and accessibility pass ship in P5, and where does Phase 4 sit?
**A:** All three ship (party ghost-footprint trace, 200ms explore→combat transition beat, accessibility verification: 48dp targets, text alongside color, shape-not-color, ≥4.5:1 contrast). Phase order: P5 ships FIRST; Phase 4 (conversation-combat seams) comes AFTER and closes V2-STAGE-004.
**Source:** Jeff, 2026-07-06
**Date:** 2026-07-06

---

### 23. p4-contact-outcome-states

**Q:** What outcome values drive the three Phase 4 seams, and how is a failed Charge told apart from an abandoned one?
**A:** `ConversationService.resolve_outcome()` returns role-agnostic `"good"`/`"partial"`/`"failed"` (`core/realms/ConversationService.gd:352-368`), carried on `contact["outcome"]` and branched in `_apply_contact_outcome()` (`core/runtime/FlowRuntime.gd:6804`; charge :6881, claimant :6914, temporary_ally :6930). FAILED resolves an outcome; ABANDONED = `stage.disengage_contact` never resolves one and leaves the situation re-engageable. A failed **objective** Charge already abandons the stage → RESOLVE `stage_abandoned_charge_fled` (:6891-6912), so the pressure seam only applies to a failed **non-objective** Charge. The claimant stub already logs `stage.claimant.hostile` with a comment that P4 wires the combat (:6914-6928).
**Source:** codebase (interview research, 2026-07-11)
**Date:** 2026-07-11

---

### 24. p4-ally-build-mirror-spirit

**Q:** How strong is an auto-joined Temporary Ally and how is its combat actor built?
**A:** Mirror the Phase 3c joined spirit: build via `EnemyActor.from_definition` with `faction:"echo"` from a new `ally_def_id` enemy template, level-scaled by realm completion like other objective actors, and apply a damage dampener paralleling `_spirit_damage_mul` (0.75) so it helps without trivializing the fight. ContactModel has no combat stats, so the template is the source of stats. New `core/actors/ContactActorBuilder.gd` (~40 lines) does the contact→actor conversion; injection is pre-initiative in `FlowEncounterState.enter()` (precedent `FlowEncounterState.gd:624-657,794`).
**Source:** Jeff, 2026-07-11
**Date:** 2026-07-11

---

### 25. p4-ally-death-exclude-knock

**Q:** How do the ally's death and the party-wipe check behave while the ally is present?
**A:** Exclude the ally from the `all_echoes_dead` check (party wipe = defeat even if the ally survives), mirroring the spirit's `is_spirit` exclusion (`core/combat/CombatState.gd:242-248`) — via an ally flag, NOT by reusing `is_spirit`. The ally's death applies a small party morale/fear knock (thematic loss) but never fails the battle on its own. GDD-aligned: an allied NPC is not an inert payload.
**Source:** Jeff, 2026-07-11
**Date:** 2026-07-11

---

### 26. p4-charge-pressure-moderate

**Q:** How much does a failed Charge raise protect/endure pressure, and on which failure?
**A:** Only a failed **non-objective** Charge sets `hostile_charge_sit_id` (objective-charge failure abandons the stage; disengage is re-engageable — neither qualifies). Moderate bump, consumed once by the stage's objective combat if it is protect/endure: ENDURE +1 `wave_size`, PROTECT +1 `duration_turns`. Injected in `_build_objective_params` (`core/state/flow/states/venture/FlowEncounterState.gd:~955-996`), paralleling the `surprise_fear:12` encounter-start modifier precedent. Exact JSON values via balance config.
**Source:** Jeff, 2026-07-11
**Date:** 2026-07-11

---

### 27. p4-ally-echobar-plain-card

**Q:** Does the Temporary Ally get a distinct EchoBar slot like the spirit, or a plain card?
**A:** Plain party card in P4 — an echo-faction ally appears automatically because the EchoBar filters purely on `faction=="echo"` (`ui/shells/RealmShell.gd:59`), no party-membership check and no wiring needed. A distinct "ally slot" (the spirit uses `EchoCardItem.setup_spirit` gold badge) is deferred; do NOT set `is_spirit` on the ally (single spirit slot, wrong semantics).
**Source:** Jeff, 2026-07-11 (default confirmed; backend-first)
**Date:** 2026-07-11
**Superseded by:** [[p4-ships-complete-ui]] — P5 already shipped, so P4 authors complete UI now: the ally gets a distinct **⊕ ALLY** Mist-Blue badge (new `setup_ally`, mirrors `setup_spirit`) + a board-token ring, NOT a plain card. (Still do not reuse `is_spirit`.)

---

### 28. p4-recruit-mechanic

**Q:** How does a surviving Temporary Ally become a permanent Sanctum Echo?
**A:** New "Earned Return" mechanic (designed via game-mechanics-designer + systems-story-designer): if a temporary_ally/good ally survives combat AND the encounter is won ([[p4-recruit-gate-survival-victory]]), compute an EARNED recruit chance — base **0**, clamped **[0,75]**, never guaranteed — as an additive sum of three `balance.json`-tunable components: `conversation_pts` (0–30, how deep into "good" the talk landed + calling-aligned resonance), `combat_pts` (0–35, survival + contribution: damage/guarding/rounds-alive/remaining-HP), `fit_pts` (0–30, party fit: contact vp/vs→10-domain vector similarity, archetype compatibility incl. rival-archetype penalty via SocialGraphService, derived-stat closeness; fit weight kept ≤ combat weight to avoid roster homogeneity). One seeded append-only draw (`combat.<encounter_id>.ally_recruit`), computed once at resolution and persisted (no re-roll on Continue). Snapshot exposes the chance + component breakdown for readability. On success → an OFFER ([[p4-recruit-agency-offer]]); on accept → `promote_ally_to_echo()` builder (NOT EchoFactory — immutable RNG order, Lesson #5) mints a roster echo from the ally's archetype/stats + contact virtue profile ([[p4-recruit-companion-identity]]).
**Source:** Jeff + game-mechanics-designer + systems-story-designer, 2026-07-11
**Date:** 2026-07-11

---

### 29. p4-recruit-agency-offer

**Q:** On a successful recruit roll, does the ally auto-join or is it an offer?
**A:** Earn-the-offer, then accept/decline — a successful roll means the ally is WILLING to stay; the Keeper accepts or declines on the Resolve surface (fits "Guidance over Control", respects roster/summon economy). Adds a durable offer record on save + an accept/decline action + minimal Resolve UI (backend-first; UI can be minimal in P4, richer in a later pass). Not auto-join.
**Source:** Jeff, 2026-07-11
**Date:** 2026-07-11

---

### 30. p4-recruit-companion-identity

**Q:** What does a recruited ally become, and how does it differ from a summoned Echo?
**A:** A **full Echo** using all Echo systems (calling, storyweight, bonds), minted fresh at **Standing 1 / Step 0** with stats re-derived at baseline (the battle template was for that one fight). BUT it keeps a durable **"companion" origin marker** (e.g. `origin:"recruited_ally"`) and integrates **harder**: its initial bonds toward existing roster echoes are seeded with a debuff / more-antagonistic bias via SocialGraphService, so it feels properly different from a summon and adds social friction (rivalry) rather than homogeneity. Any UI tag for the companion origin is deferred (backend carries the marker).
**Source:** Jeff, 2026-07-11
**Date:** 2026-07-11

---

### 31. p4-recruit-gate-survival-victory

**Q:** What combat outcome gates recruitment?
**A:** Ally must be **alive at battle end AND the encounter resolved as a victory** (not survival alone) — an ally only follows the house home from a battle won together; blocks recruiting off a retreat/defeat. Dead ally or non-victory → chance stays 0, no roll.
**Source:** Jeff, 2026-07-11
**Date:** 2026-07-11

---

### 32. p4-contribution-ledger-tier-split

**Q:** How much per-actor combat-contribution tracking do we build, given it isn't currently tracked?
**A:** Split by cost (mutation-site count): **Tier 1 (offensive)** — `damage_dealt`/`damage_taken`/`kills` — is a ~1-site change because it piggybacks the **existing** `EncounterContext.echo_action_logs` accumulator (`core/state/encounter/EncounterContext.gd:48`) at the single melee choke (`FlowRuntime._resolve_next_actor:1766`); Phase 4 generalizes that accumulator to **both factions** and projects it into the final snapshot (reused by the recruit formula now; MVP barks / storyweight / bonds later). **Tier 2 (support attribution)** — guards/morale/fear applied to allies — is ~9 scattered inline sites with no shared mutator, so it is carved out as its own story `V2-COMBAT-00x — Combat Contribution: Support Attribution` (task_09603c7e), to run in a parallel instance and rebase after the P4 PR merges.
**Source:** Jeff + codebase scope research, 2026-07-12
**Date:** 2026-07-12

---

### 33. p4-ships-complete-ui

**Q:** Does Phase 4 ship its own UI/UX, or defer it to a later polish pass?
**A:** Ships complete now — P5 (the UI/UX surface pass) already merged, so there is no downstream UI phase to absorb P4's surfaces. The **ally visual line** = **Mist Blue `#7AB5C8`** + the **⊕ Odo Nnyew Fie Kwan** Adinkra glyph ("love never loses its way" — bond/loyalty), distinct from spirit gold and enemy red. Authored surfaces (structure in `.tscn`, `.gd` sets values — Lessons #2/#5/#14): `⊕ ALLY` EchoCard badge (`setup_ally`) + Mist-Blue board ring, the `AllyRecruitOffer` Resolve panel (earned chance + Talk/Fight/Fit sub-bars + accept/decline), a durable `⊕ Companion` roster tag on `origin=="recruited_ally"`, and readable seam cues (claimant→combat intro line, Amber "Pressure raised" ObjectiveBanner marker, `ally_killed` bark). Supersedes [[p4-ally-echobar-plain-card]].
**Source:** Jeff, 2026-07-12
**Date:** 2026-07-12

---

### 34. p4-companion-invite-sanctum-event

**Q:** Where does the ally-recruit offer surface — on the Resolve screen, or as its own thing?
**A:** Its own **Sanctum event**, not part of Resolve (Jeff, post-approval iteration). A successful roll writes a durable `sanctum.companion_invite` (one slot — **no-stack** guard: a second success is discarded while one is pending). `FlowSanctumState` projects `data.companion_invite`; the `%CompanionInvite` modal on `SanctumScreen` shows it on Sanctum entry and **persists until decided** (re-projects each entry). Actions: `sanctum.companion.accept` (promote + clear) / `sanctum.companion.decline` (clear). The old Resolve `AllyRecruitOffer` panel + `cta.recruit_accept/decline` + `explore_map.ally_recruit_offer` were removed. Supersedes the plan's Resolve-panel design in [[p4-recruit-agency-offer]]. Rationale: a companion choosing to join the house deserves its own beat back home.
**Source:** Jeff, 2026-07-15
**Date:** 2026-07-15

---

### 35. p4-guide-spirit-routing-fix

**Q:** Why could a stage with a guide_spirit objective never be completed (soft-lock)?
**A:** `guide_spirit` was missing from `SituationResolutionService._ASYNC_OBJ_TYPES` (`core/realms/SituationResolutionService.gd:28`), so a guide_spirit OBJECTIVE routed to the flavor `in_explore` path instead of the real combat hand-off — the situation was marked resolved but `stage.objectives[idx].completed` never flipped, so `objectives_remaining` stayed ≥1 and the `cta.proceed_to_stage_map` CTA never rendered. A pre-existing **Phase 3c** oversight on `main` (Phase 3c added guide_spirit end-to-end but not to this routing list), surfaced during Jeff's P4 playtest and folded into the P4 PR. Fix: append `"guide_spirit"` to `_ASYNC_OBJ_TYPES` (+ routing test). Follow-up chip: guard the in-explore path so any is_objective resolving there is caught/completed (defense-in-depth).
**Source:** Jeff + investigation, 2026-07-15
**Date:** 2026-07-15

---
