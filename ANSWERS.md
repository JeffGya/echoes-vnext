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
| 36 | prog012-per-echo-scope-only | PROG-012 owns the per-Echo autonomy seam; the party-coherence forecast belongs to V2-VOICE-002 | 2026-07-29 |
| 37 | prog012-four-maturity-outputs | Hidden maturity layer emits FOUR outputs: Judgment, Presence, Composure, Legibility | 2026-07-29 |
| 38 | prog012-must-ship-live | PROG-012 must ship with a live divergence-detection effect, not a dormant seam | 2026-07-29 |
| 39 | autonomy-is-derived-not-stored | Autonomy is derived per activation from Standing/maturity/traits/bonds/vows/emotion; nothing new persists | 2026-07-29 |
| 40 | prog012-vs-combat003-boundary | PROG-012 ships inputs + thresholds; V2-COMBAT-003 resolves the five responses | 2026-07-29 |
| 41 | autonomy-seam-partially-exists | directive_band_mul is already a live autonomy axis; what is missing is the consequence/legibility layer | 2026-07-29 |
| 42 | party-ladder-not-response-ladder | The hidden 4-band party ladder and the 5 event-local responses are different axes, not a mapping | 2026-07-29 |
| 43 | prog012-absorbs-parked-notes | The two calling-virtue corrections and the Storyweight truncation bug all ship inside PROG-012 | 2026-07-29 |
| 44 | storyweight-speak-truncated | Conversation Storyweight was `int(0.2)` → `0`, silently never awarded | 2026-07-29 |
| 45 | prog012-refusal-unreachable-measured | 0 refusals in 439 measured rounds across all bands — the Phase 7 band+offset fix is correct but its effect is unobservable until the fear economy is rebalanced | 2026-08-09 |
| 46 | prog012-divergence-single-directive-measured | Divergence fires almost only under directive.scout_carefully; seek_signs shows contest on 4 of 535 turns — a directive-content property, not a detector defect | 2026-08-09 |
| 47 | fear-recovery-was-unconditional | Every dominant fear recovery term paid out for winning, and shipped fights are always winnable, so fear pinned at 0 | 2026-08-11 |
| 48 | move-then-attack-was-impossible | An actor that closed to melee range could not attack; 80% of enemy activations produced no action at all | 2026-08-11 |
| 49 | fear-40-target-retired | The COMBAT-001 "stay below fear 40" target is retired; the band boundaries stay, and the economy rises to use them | 2026-08-11 |
| 50 | probe-must-mirror-the-summon-path | A probe that calls EchoFactory.generate() without init_vectors builds a party that cannot exist in play | 2026-08-11 |

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

### 36. prog012-per-echo-scope-only

**Q:** Does V2-PROG-012 also compute the GDD's hidden four-band party-coherence ladder, or only the per-Echo autonomy seam?
**A:** **Per-Echo only.** `V2-VOICE-002` (Order 252, Ready) already owns the pre-run party read — "let the player see unstable party pressure before commitment" — and it *depends on* PROG-012, so the layering is per-Echo inputs → party aggregation → `V2-INFRA-004`'s integrated readiness read. The GDD's `aligned/strained/hesitant/refusing` ladder (`docs/Echoes vNext Working GDD.md:1329-1338`) is a party-level pre-run forecast and is therefore VOICE-002's surface, not this story's. See [[party-ladder-not-response-ladder]].
**Source:** Jeff + Notion backlog query, 2026-07-29
**Date:** 2026-07-29

---

### 37. prog012-four-maturity-outputs

**Q:** How many named outputs does the hidden maturity-expression layer produce, and what are they?
**A:** **Four.** The GDD names only **Judgment** (`GDD:1360` — hold, interpret and assert self under pressure) and **Presence** (`GDD:1361` — how strongly that state presses onto nearby or bonded others). Jeff expanded the set to four, and research identified the only two further dimensions the GDD *describes but never names*: **Composure** (`GDD:1369` — steady against noise, hit harder by true contradiction) and **Legibility** (`GDD:1273`, `:1282`, §7.3 — intent becomes more specific and readable as wholeness grows). Rejected as peers: Self-command (overlaps Judgment's own definition), Instability (the GDD lists it as an *input*, `GDD:1380`), and Resolve/Conviction/Coherence/Initiative/Restraint (absent from the GDD entirely — inventions).
**Source:** Jeff, 2026-07-29 (GDD §11.5 research)
**Date:** 2026-07-29

---

### 38. prog012-must-ship-live

**Q:** May PROG-012 ship as a dormant seam, given its consumer (Keeper guidance) does not exist until COMBAT-003/004?
**A:** **No — it must have at least one live, observable effect at ship time.** The chosen effect is **divergence detection**: when an Echo's own judgment out-votes the active directive, name it and surface it (log + telemetry/bark) instead of letting it happen silently, which is what happens today. Rationale: V2-COMBAT-002 shipped a movement-aware layer that was **completely inert through an entire merged PR** while 1281 tests passed, because nothing live consumed it. A dormant seam is not verifiable by a green suite.
**Source:** Jeff, 2026-07-29
**Date:** 2026-07-29

---

### 39. autonomy-is-derived-not-stored

**Q:** Is autonomy a stored per-Echo field or derived at runtime?
**A:** **Derived**, per `GDD:1270-1345`, from Standing/Storyweight maturity, archetype, trait balance, calling family/accent, bonds and rivalries, vow state, fear and morale, and current instability/distortion. Nothing new persists, so there is no save migration and autonomy cannot drift out of sync with Standing. Note the word "autonomy" appears **zero** times in `core/` today. Contrast with `confidence` ([[echo-confidence-model]]), which uses a stored base plus derived runtime blend — autonomy deliberately does not.
**Source:** GDD §11.5, 2026-07-29
**Date:** 2026-07-29

---

### 40. prog012-vs-combat003-boundary

**Q:** Does PROG-012 resolve the five guidance responses, or only supply the inputs and thresholds?
**A:** **Inputs and thresholds only.** `docs/proposals/keeper-tactical-guidance-promotion.md:520` is explicit: "V2-PROG-012 for autonomy-threshold tuning, then V2-COMBAT-003 for deterministic pressure collision and reason-bearing outcomes." Corroborated by `keeper-tactical-guidance-architecture.md:753` ("settle autonomy/refusal threshold behavior before collision-order work"). COMBAT-003 owns choosing Align/Interpret/Hesitate/Object/Refuse; the architecture doc's `response_thresholds: {}` (`:622`) is the empty stub PROG-012 fills.
**Source:** keeper-tactical-guidance proposals, 2026-07-29
**Date:** 2026-07-29

---

### 41. autonomy-seam-partially-exists

**Q:** Does an autonomy seam already exist in code under another name?
**A:** **Partially.** `data.maturity_expression.directive_band_mul` (nascent 1.30 → whole 0.75) is live and applied in `BehaviorArbiter.gd:1786-1790`, and `refusal_thresholds_by_band` (65/72/80/90) already drives the Absolute Fear Rule. So the numeric axis is built; what is missing is any *consequence* — nothing detects, names, or surfaces the moment an Echo's judgment out-votes the directive, and the directive is only ever re-weighted, never reinterpreted. Two defects found alongside: `presence_strength` is passed to `BehaviorArbiter._score` (`:1623`) and **never read**, and `directive_band_mul` double-counts against rank-scaled identity weighting (`:1666`).
**Source:** codebase research, 2026-07-29
**Date:** 2026-07-29

---

### 42. party-ladder-not-response-ladder

**Q:** How does the GDD's four-band ladder (aligned/strained/hesitant/refusing) map onto the five guidance responses (Align/Interpret/Hesitate/Object/Refuse)?
**A:** **It does not — they are different axes.** `GDD:1338` states they are "related but distinct": the four bands are a *hidden pre-run forecast of party coherence*, while the five responses are *event-local and per-recipient*. No mapping is required or intended. **Naming hazard:** three of the four band names (`grounded`, `hesitant`, `strained`) already mean something else in the live 10-tier `emotional_status` vocabulary (`core/emotion/EmotionService.gd:198-229`), so whoever builds the party ladder must rename or explicitly disambiguate.
**Source:** GDD §11.5, 2026-07-29
**Date:** 2026-07-29

---

### 43. prog012-absorbs-parked-notes

**Q:** Do the three review notes parked on the PROG-012 page ship with it, or split out?
**A:** **All three ship inside PROG-012** (Jeff's call). They are corrections and a bug, not open questions: **Okofor→Generosity** is contradicted by GDD-derived vector composition (Okofor pulls Protector = Courage+Compassion and Pillar = Acceptance+Humility; Generosity belongs to Onyamesu's vectors); **Sum-Okwanfo→Forgiveness** likewise (Skeptic = Truth+Humility, so Humility is supported; Forgiveness belongs to Mediator). Both live in `core/realms/ConversationService.gd:26-33`. The third is a live bug — see [[storyweight-speak-truncated]]. Note `data/balance.json:280` `vector_to_virtue_primary` also conflicts with the calling-reference compositions and belongs to the same audit.
**Source:** Jeff, 2026-07-29
**Date:** 2026-07-29

---

### 44. storyweight-speak-truncated

**Q:** Why does a successful conversation turn appear to award no Storyweight?
**A:** Because it awards **exactly zero**. `data.contact.storyweight_speak_partial_step` is `0.2` (`data/balance.json:3132`), but the consumer at `core/runtime/FlowRuntime.gd:8218` wraps the award in `int(...)`, which truncates `0.2` → `0`. So conversation Storyweight has **never** been granted. The original review note ("+0.2 may be too small to register as motivation") understated it. For comparison, combat awards kill 25 / stage clear 40 / realm 100 against `level_thresholds` of 100 per Step (`data/balance.json:1402-1404`). Ships inside PROG-012 per [[prog012-absorbs-parked-notes]].
**Source:** codebase research, 2026-07-29
**Date:** 2026-07-29

---

### 45. prog012-refusal-unreachable-measured

**Q:** Does the Phase 7 Absolute Fear Rule band+offset fix (see [[prog012-absorbs-parked-notes]]) have an observable effect in real play?
**A:** **Not yet — refusal is unreachable in natural play.** Measured across all expression bands, fresh and veteran Echoes, and tripled enemy counts (439 rounds total): **0 refusals**. Fear peaks around **27** against band+offset thresholds of **60–90**, because passive/active fear recovery (`fear_self_recovery`, `sanctum_fear_recovery_bonus`) outpaces every accumulation path measured. The Phase 7 fix (`absolute_fear_offset` composing with the band, instead of replacing it) is structurally correct and passes falsifiable tests, but no amount of threshold tuning will make it visible until the fear economy itself is rebalanced to let fear climb higher in a real encounter. **Do not tune refusal thresholds expecting a visible effect** — that lever is not the bottleneck.
**Source:** measured probe, V2-PROG-012 Phase 10, 2026-08-09
**Date:** 2026-08-09

---

### 46. prog012-divergence-single-directive-measured

**Q:** Does divergence detection fire meaningfully across all directives, or only under one?
**A:** **Effectively single-directive today.** Under `directive.seek_signs`, only **4 of 535** scored Echo turns showed any contest (max `contest_ratio` 0.0179, well under `min_contest_ratio` 0.28) — not because the detector is structurally incapable (a throwaway probe found a real, non-flat `directive_bonus` spread for `seek_signs`, comfortably clearing the threshold), but because that directive's resolved preference (`actor.move`, driven by `clue_seeking_priority`/`reporting_priority`) already closely matches what an Echo's own base identity favours in combat — a genuine identity-vs-directive conflict rarely arises naturally under this directive's content. `directive.scout_carefully` is where divergence is actually observable (recalibrated to `min_contest_ratio: 0.28`, ~0.73 events/encounter across 15 measured encounters). Coverage is directive-agnostic by construction (`tests/DivergenceDetectorTests.gd` enumerates `DirectiveService.get_registry()` at runtime), so this generalises automatically to any directive added later — but a future directive whose content resembles `seek_signs` (i.e. whose preferred action already matches unprompted Echo behavior) will show the same near-silence, and that is expected, not a bug.
**Source:** measured probe, V2-PROG-012 Phase 6/10, 2026-08-09
**Date:** 2026-08-09

---

### 47. fear-recovery-was-unconditional

**Q:** Why did fear pin at 0 in every shipped fight, when the emotion system has six accumulation sources and six recovery sources?
**A:** **Every dominant recovery term paid out for winning, and the shipped encounter design guarantees the party is winning.** `fear_reduce_on_outnumber` was a flat −2 whenever living echoes outnumbered living enemies. It reads as a condition but behaved as a constant, because `enemy_spawn_config.max_count` is 4 against a party of 5, so it fired from round 1 of every fight. The kill economy (−15 to the killer, −5 to every living ally) paid the same for killing 1 of 8 as for killing the last enemy. Together they delivered −4.15 fear per echo per round against a total accumulation of +1.22. Recovery was not narrowly winning — it was **oversupplied by 3–7×**, and 59–71% of it was thrown at the fear-0 floor. Zero refusals in 439 rounds was never a near-miss. The fix set makes relief *situational*: outnumber relief scales with the margin (A4), kill relief scales with the share of threat removed plus a flat bonus if the dead enemy was the one hitting you (A3), and all relief tapers as fear rises (A5). Measured on the hardest shipped fight, peak fear went 4 → 46.
**Source:** Jeff + measured probe (`tests/FearReachabilityProbe.gd`), 2026-08-11
**Date:** 2026-08-11

---

### 48. move-then-attack-was-impossible

**Q:** Why did enemies attack on only 1 in 5 of their activations?
**A:** **An actor that closed to melee range during its activation could not attack, because attacking was never the declared action.** `CombatPressureService._add_ordinary_combat` emitted TWO goals for a non-adjacent hostile over the *same* region and the *same* path: an `advance` (TACTICAL, HIGH urgency) planning `actor.move`, and an `engage` (SAFETY, NORMAL) planning `melee_attack`. `_final_goal_before` orders the shortlist by urgency descending, so the action-less advance always won. Measured: **80% of enemy activations produced no action at all**, and only 7 of 35 enemy-rounds produced a swing — while 100% of *planned* swings resolved correctly. The loss was entirely in goal selection, not in execution. This contradicted `docs/movement-model.md` §8.1 and §22.4. Two earlier hypotheses were wrong and are recorded so they are not retried: it is **not** BehaviorArbiter scoring (moving the `enemy_advancing` situational bonus from `actor.move` to `melee_attack` produced byte-identical output), and demoting the advance goal's urgency made it **worse**. The fix removes the duplicate and gives `engage` the TACTICAL slot — the bucket matters, because `withdraw` occupies SAFETY at HIGH under collapse and would evict an engage left there.
**Source:** measured probe, 2026-08-11
**Date:** 2026-08-11

---

### 49. fear-40-target-retired

**Q:** Does the V2-COMBAT-001 target — "party landing one kill per round-pair stays below fear=40 in a standard 5-round fight" — still hold?
**A:** **Retired.** It existed only as a comment in `data/balance.json`, in no design document, and it predates the V2-PROG-010 recovery paths that broke it. Jeff: *"The boundary is worth revisiting. Main goal is to make sure the game is tuned to be enjoyable. We don't have to hold on to old constraints."* The **band boundaries stay where they are** and the economy rises to use them, rather than the boundaries dropping to meet a starved economy. The reason is concrete: **69 fear values are authored outside `data.combat.emotion`**, most assuming the full 0–100 range — vow break costs 15/25/40, `combat_exit_loss_fear` 20, `fear_base_max` 40, contact `fear_ceiling` 90. Two are live gameplay behaviours that had also never fired for the same reason refusal had not: `party_return_fear_threshold` 60 and `cautious_advance_fear_threshold` 50, both consumed by `FlowStageExploreState`. Lowering the boundaries would desync all 69 and strand those two. Raising fear to use the scale lights them all up at once.
**Source:** Jeff, 2026-08-11
**Date:** 2026-08-11

---

### 50. probe-must-mirror-the-summon-path

**Q:** Is it enough for a probe to build its party with `EchoFactory.generate()`?
**A:** **No — that builds a party that cannot exist in play.** `generate()` deliberately leaves `emotion` and `dominant_vector` unpopulated and relies on `EmotionService.init_echo()` and `VectorService.init_vectors()`, which the real summon path calls immediately afterwards (`FlowRuntime` ~:1370). A probe that skips them gives every Echo `dominant_vector = ""`, which silently disables the vector half of the identity-fear-spike gate **and** every vector term in BehaviorArbiter scoring. This invalidated a headline finding: the identity fear spike was reported as "never fires at any rank in any scenario", with the cause named as `uncalled` Echoes failing the calling gate. **Both were wrong.** The `uncalled` weight row already exists and already clears the 30-point threshold; the spike was blocked by the empty vector the probe itself created. With a production-shaped party the spike fires normally, peak fear rose 18 → 45 on the same encounter, and the fight resolved in 9 rounds instead of 13. This is [[reachability-not-just-execution]] applied to the fixture rather than the assertion: production-shaped data means *built by the production path*, not merely *non-empty*.
**Source:** measured probe, 2026-08-11
**Date:** 2026-08-11

---
