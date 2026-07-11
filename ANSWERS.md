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
