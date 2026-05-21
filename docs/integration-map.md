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
| **V2-PROG-006** — Maturity Expression | Foundation | Done | `MaturityExpressionService.gd` | `expression_band` → nascent/forming/grounded/whole; `presence_strength` 0.1–1.0 |

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
| **V2-PROG-003** | Alignment | — | Vector expansion (4 → 10 virtue domains) |
| **V2-PROG-004** | Alignment | — | Calling V1→V2 ID migration |

---

## Architecture Reference (quick links)

- Snapshot contract → `CONVENTIONS.md` § Snapshot Shape
- Action types → `CONVENTIONS.md` § Action Type Registry
- Save schema → `core/save/SaveSchema.gd`
- Balance config → `data/balance.json`
- Flow states → `core/state/flow/states/`
- Test runner → `ui/AppRoot.gd` → `_run_tests()`
