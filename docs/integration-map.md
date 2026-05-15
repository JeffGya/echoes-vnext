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
| **V2-SANCTUM-002** — Institutions + Passive Recovery + Sanctum Ground | Foundation | Done | `InstitutionService.gd`, `SanctumGroundScene.tscn/.gd`, `SanctumScreen` wiring, `balance.json`, `SaveSchema/SaveService` | Hearth + Training Grounds. Foundation exception invoked (Continuity + Ekwan gate only; virtue gating deferred to V2-CONTINUITY-001+). All roster echoes in spatial scene. 3 ambient signals: token colour, bond-aware slot, building condition liveness. |

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

## Upcoming (Foundation — next pickup order)

| Story | Wave | Priority | Notes |
|-------|------|----------|-------|
| **V2-CONTINUITY-001** | Foundation | Next | Fuller Continuity progression spine + institution virtue gating |
| **V2-DIRECTIVE-001** | Foundation | — | Directive rewrite (Scout Carefully / Seek Signs) |
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
