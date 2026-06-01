# Echoes vNext — Integration Map

> **Active story tracker** — replaces `docs/v2-migration-map.md` for all work after V2-MIG-001 (Alignment wave complete 2026-04-06).
>
> **Source of truth:** `docs/Echoes vNext Working GDD.md`
> **Backlog:** Notion DB `d3dc9cb4-21e9-44fc-9229-238474907ed6`
> **Conventions:** `CONVENTIONS.md`

---

## How to Read This Map

| Column | Meaning |
|--------|---------|
| Story | Story ID + name from backlog |
| Wave | Alignment / Foundation / Expansion / Full Game |
| Status | Pending / In Progress / Done |
| Ships | Key files changed or created |
| Notes | Deferred decisions, dependencies, design exceptions |

---

## Foundation Wave — Sanctum Systems

| Story | Wave | Status | Ships | Notes |
|-------|------|--------|-------|-------|
| **V2-SANCTUM-001** — Sanctum Pulse + Emotion Recovery | Foundation | Done | `EmotionRecoveryService.gd`, `FlowRuntime.gd` hooks, `SanctumScreen` active-effects panel | Bank-tick emotion recovery, active-effects chips, VOW-002 morale/fear modifiers |
| **V2-SANCTUM-002** — Institutions, Passive Recovery & Sanctum Visualization | Foundation | Done | `SanctumLayoutService.gd` (extended), `SanctumBuildingLayer.gd` (new), `SanctumOccupantLayer.gd` (refocused), `SanctumPlacementLayer.gd` (new), `SanctumSpatialRenderer.gd/.tscn`, `SanctumShell.gd`, `SanctumScreen.gd/.tscn`, `InstitutionService.gd`, `FlowRuntime.gd`, `SaveSchema.gd`, `balance.json`, `tests/SanctumLayoutTests.gd` | Deleted `SanctumGroundScene` (wrong layer type, non-deterministic randf, dead-end). Three-layer spatial architecture: SanctumBuildingLayer (Ase Flame + institution markers, z=1), SanctumOccupantLayer (echoes only, combat-board circle tokens + morale_tier fill, z=2), SanctumPlacementLayer (valid cell highlights + ghost, z=3). Ase Flame permanent at (0,0). Free building placement with 2-tile Chebyshev exclusion zone. Passive effects (Hearth +2 morale/hr, Training Grounds +1 storyweight/hr) fire for ALL roster echoes at economy.settle_time (social gravity, not job assignment — job assignment is V2-SANCTUM-003). Institution positions stored in save_data. Institutions panel overlay from Header card button. InstitutionDetailPanel updated with V2 language (social identity, condition colors, passive effect description). Continuity + Ekwan gate only; virtue gating deferred to V2-CONTINUITY-003. 8 new SanctumLayoutTests. Notion context written to V2-SANCTUM-003/004/005 and V2-CONTINUITY-003. |

---

## Foundation Wave — Economy Systems

| Story | Wave | Status | Ships | Notes |
|-------|------|--------|-------|-------|
| **V2-ECONOMY-001** — Ase Flame + Ekwan baseline | Foundation | Done | `EconomyService`, `SaveSchema`, `FlowRuntime` bank timer | Ase Flame awakening, offline cap, Ekwan stub added |

---

## Foundation Wave — Progression Systems

| Story | Wave | Status | Ships | Notes |
|-------|------|--------|-------|-------|
| **V2-MIG-001 / V2-MIG-002** — Save bridge + repair | Alignment | Done | `SaveSchema.gd`, `SaveService.gd` | V2 save root keys added additively alongside V1 aliases |
| **V2-PROG-001** — Progression language rename | Alignment | Done | `FlowSanctumState`, snapshots | Standing/Step/Storyweight labels canonical |
| **V2-PROG-002** — Calling seam unification | Alignment | Done | `calling-reference.md`, `EchoFactory` | 6 callings, Twi names documented as target |
| **V2-PROG-003** — Vector expansion (4 → 10 virtue domains) | Alignment | Done | `VectorService.gd`, `balance.json`, `SaveService.gd` | 10 vector keys canonical; backfill repair on load |
| **V2-PROG-004** — Calling V1 → V2 ID migration | Alignment | Done | `CallingService.gd`, `SaveService.gd`, `balance.json` | V2 calling IDs active; V1 IDs migrated on load |
| **V2-PROG-006** — Maturity Expression | Foundation | Done | `MaturityExpressionService.gd` | `expression_band` → nascent/forming/grounded/whole; `presence_strength` 0.1–1.0 |
| **V2-PROG-007** — Calling lattice: Standing-6 + Standing-9 data + adjacency ring | Foundation | Done | `balance.json` (12 S6 expressions, 24 S9 culminations, adjacency ring), `CallingService.gd` (4 new static functions), `ConfigService.gd` (config integrity guard on load), `CallingTests.gd` (11 new tests, 34 total), `calling-reference.md` | Standing-6/9 names from GDD §11 now in config. Adjacency data-driven. `validate_config_integrity()` called at balance load. Standing-9 `twi_provisional` flag for names needing cultural validation (14 of 24). Vector/archetype fit computation at S6 deferred to V2-PROG-009 — noted in that story's Notion page. |
| **V2-PROG-008** — Calling lattice service layer (S6/S9 query functions) | Foundation | Done | `CallingService.gd` (`get_standing_6_options`, `compute_standing_6_pool`, `get_standing_9_options`, `validate_count_integrity`), `ConfigService.gd` (count integrity guard wired at balance load), `CallingTests.gd` (9 new tests, 43 total), `calling-reference.md` (CallingService API table) | S6 pool = own 2 + adj 2 + adj 2 = 6 total. Anchor: `echo["calling"]` → fallback `echo["calling_origin"]` → `[]` for unresolvable. Raw pass-through — PROG-009 owns eligibility gating and UI projection. `validate_count_integrity` runs alongside `validate_config_integrity` at balance load. V2-PROG-009 calls `compute_standing_6_pool` (selection panel) and `get_standing_9_options` (culmination previews). |
| **V2-PROG-009** — Skills Tab: Unlock Loop + Party Toggle Fix | Foundation | Done | `balance.json` (14 skill defs with `type`/`description`/`unlock_conditions`, 6 calling stubs, `calling_constellation` block), `SkillDefinition.gd` (9 required fields), `SaveService.gd` (`unlocked_skills:[]` additive repair), `FlowRuntime.gd` (party toggle fix for flow.sanctum; `sanctum.unlock_skill` handler), `FlowSanctumState.gd` (enriched skill entries with constellation data), `SanctumScreen.tscn`+`.gd` (Constellation Web UI: calling node, S3 nodes, ghost S6/S9, detail strip, expand/collapse), `ConstellationLines.gd` (new, orbital rings + connecting lines via `_draw()`), `SkillUnlockTests.gd` (8 new tests) | Skills tab shows Constellation Web for called echoes; empty state for uncalled. S3 nodes interactable (40 Ase to unlock). Ghost S6/S9 nodes visible, non-interactive (MOUSE_FILTER_IGNORE). `unlocked_skills:[]` per-echo save field. Party toggle now works from flow.sanctum without navigating to echo_party. `_build_skill_entries_for_echo` now accepts `ase_balance` and returns `is_unlocked`, `ase_cost`, `can_afford`, `calling_confirmed`, `constellation_angle`, `constellation_radius`, `tier`. |
| **V2-PROG-010** — Maturity Expression as Live Simulation Factor | Foundation | Done | `balance.json` (8 new config blocks in `data.maturity_expression`: `rank_strength_scale`, `refusal_thresholds_by_band`, `identity_weight_scale`, `presence_dampen_scale`, `fear_self_recovery`, `sanctum_fear_recovery_bonus`, `directive_band_mul`, `rank_benefits_config`), `MaturityExpressionService.gd` (`get_rank_strength()`, `compute_sanctum_fear_recovery_bonus()`), `ActorStateMachine.gd` (rank_strength compute; band-keyed refusal thresholds; passive fear tick; active identity spike + `_compute_identity_fear_spike()`; actor dict writeback; `combat_identity_spike` bark context), `BehaviorArbiter.gd` (`_score()` identity weight scaling + composure; `_directive_bonus()` calling+band mul; `_DEFAULTS` updated), `EmotionRecoveryService.gd` (optional `cfg_data` param; rank-based fear recovery bonus per tick), `FlowRuntime.gd` (passes `cfg_data` to EmotionRecoveryService), `FlowSanctumState.gd` (`rank_benefits`, `expression_band`, `rank_strength` in detail roster; `_build_rank_benefits()` helper), `FlowEncounterState.gd` (`expression_band`, `presence_strength` in actor projection), `SanctumScreen.tscn`+`.gd` (`RankBenefitsContainer` + 3 pre-built `EchoRankBenefitGlyph` nodes; `_rebuild_rank_benefits()`), `EchoRankBenefitGlyph.tscn`+`.gd` (new persistent earned-benefit glyph with expandable tooltip), `MaturityExpressionTests.gd` (7 new tests, 23 total) | **GDD-aligned:** expression band is a hidden simulation layer (GDD §1308). Rank scales 0.0→1.0 across ranks 1–9 (`rank_strength`). Bidirectional differentiation: nascent Echoes break sooner under fear (threshold 65), whole Echoes hold longer (threshold 90). Whole Echoes' trait+vector identity contributes up to 1.6× scoring weight at rank 9. Fear disruption is 40% lower at rank 9 via composure scaling. Identity-consistent actions (calling ∩ dominant_vector) trigger a fear spike-down (3–12 pts, rank-scaled) + bark. Sanctum fear recovery bonus active from rank 5, identity-based. Player-facing: earned benefit glyph (Akan-styled placeholder) on Echo detail card — no band labels, no raw numbers. **Out-of-scope notes:** leadership calming/identity drift → leadership story; directive resistance → V2-DIRECTIVE-002; Keeper disagreement/revolt → V2-PROG-012 + new story; whole Echo leveraging nascent → bond story; band extension beyond "whole" → mythic rite story. |

---

## Foundation Wave — Vow Systems

| Story | Wave | Status | Ships | Notes |
|-------|------|--------|-------|-------|
| **VOW-001** — Vow pledge/break | Foundation | Done | `VowService.gd`, `VowScreen.gd` | 4 vows, tier system, FlowRuntime pledge/break handlers |
| **V2-VOW-002** — Vow compliance + active effects | Foundation | Done | `SanctumScreen` active-effects panel, `FlowRuntime` vow_stats | Compliance count, morale/fear hit on break, effect chips |

---

## Foundation Wave — Weave + Thread Systems

| Story | Wave | Status | Ships | Notes |
|-------|------|--------|-------|-------|
| **V2-WEAVE-001** — Thread reserve | Foundation | Done | `ThreadService.gd`, `FlowSanctumState` | Thread reserve display, cap config |
| **V2-WEAVE-002** — Weaving Rite | Foundation | Done | `WeavingRiteService.gd`, `WeavingRiteScreen` | Accept/Reject/Defer outcomes. Partial Integrate + Distort deferred to Expansion. |

---

## Foundation Wave — Realm + Stage Systems

| Story | Wave | Status | Ships | Notes |
|-------|------|--------|-------|-------|
| **V2-STAGE-001** — Stage Exploration | Foundation | Done | `StageExploreModel.gd`, `FlowStageExploreState.gd` | Situation model, explore turns, intel persistence |

---

## Foundation Wave — Social Systems

| Story | Wave | Status | Ships | Notes |
|-------|------|--------|-------|-------|
| **BOND-001** — Bond trigger | Foundation | Done | `SocialGraphService.gd`, bond scoring | Signed strength edges |
| **BOND-002** — Bond incidents + rival | Foundation | Done | `rival_incidents` tracking, `grief`/`shared_survival` modifiers | Rival pairs seeded for V2-SANCTUM-005+ |

---

## Foundation Wave — Combat Systems

| Story | Wave | Status | Ships | Notes |
|-------|------|--------|-------|-------|
| **V2-COMBAT-001** — Readiness score, hesitation band, defeat bug fix, enemy count scaling | Foundation | Done | `CombatState.gd`, `ActorStateMachine.gd`, `FlowEncounterState.gd`, `FlowRuntime.gd`, `balance.json`, `tests/CombatInitiativeTests.gd`, `tests/CombatConsequenceTests.gd` | Morale-tier initiative modifier (inspired +4 … broken −6); "hesitating" status band (fear ≥ 40); guard self-set fix; defeat re-entry bug fixed (encounter_ctx nulled on defeat path); enemy count config-driven via spawn groups (1/2/3 base by realm completion index); 8 new bidirectional emotion triggers (guard absorb, near-death, shrine purify, outnumbering, witness refuse, overwhelmed, consecutive no-damage). V2-COMBAT-002 required for tonal realm differentiation (type variety). V2-INFRA-005 required before permadeath. |

---

## Foundation Wave — Continuity Systems

| Story | Wave | Status | Ships | Notes |
|-------|------|--------|-------|-------|
| **V2-CONTINUITY-001** — Continuity Flame + Institution Gating | Foundation | Done | `ContinuityService.gd`, `ContinuityFlameControl.gd`, `FlowSanctumState.gd` (continuity_points + continuity_band in snapshot data), `InstitutionService.gd` (blocker_reason), `SaveSchema.gd` (sanctum.rejection_counts), `balance.json` (data.continuity.bands), `docs/continuity-visual-design.md` | Household Fire visual system — 6 bands (Awakening → Cultural Maturity), ember-toned TitleRow indicator distinct from Ase Flame. ContinuityService is single choke for all mutations. Thread accept +5, thread reject escalating (capped), vow break −3. Institution virtue gating via blocker_reason. Band transition ceremonial moment deferred to V2-CONTINUITY-003. Visual design record: `docs/continuity-visual-design.md`. |

---

## Upcoming (Foundation — next pickup order)

| Story | Wave | Priority | Notes |
|-------|------|----------|-------|
| **V2-DIRECTIVE-001** | Foundation | Next | Directive rewrite (Scout Carefully / Seek Signs) |

---

## Architecture Reference (quick links)

- Snapshot contract → `CONVENTIONS.md` § Snapshot Shape
- Action types → `CONVENTIONS.md` § Action Type Registry
- Save schema → `core/save/SaveSchema.gd`
- Balance config → `data/balance.json`
- Flow states → `core/state/flow/states/`
- Test runner → `ui/AppRoot.gd` → `_run_tests()`
