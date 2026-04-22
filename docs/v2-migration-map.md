# Echoes vNext — V2 Migration Map

> **Story:** V2-MIG-001 (Order 10 — first pickup in the Alignment wave)
> **Status:** Done
> **Created:** 2026-04-06
> **V2-MIG-002 shipped:** 2026-04-06
> **Source of truth:** `docs/Echoes vNext Working GDD.md`

This document is the authoritative map from V1 (current code) to V2 (canonical design).
Every Alignment wave story traces back to this map. Implementation work should not begin until
the relevant domain section here is agreed.

**How to read each domain:**

| Column | Meaning |
|---|---|
| V1 Current | What the code does today — exact field names, files, config keys |
| V2 Target | What the GDD says it should become |
| Migration Action | `Rewrite` / `Carryover` / `New Build` / `Supersede` |
| Owner | The V2 story that implements the change |
| Invariants | What must NOT break during the migration |

**Migration Actions defined:**

- **Rewrite** — existing system is reworked to match V2 spec; old code goes away
- **Carryover** — existing code is valid and carries forward with minimal change
- **New Build** — V2 requires a system that does not yet exist in V1
- **Supersede** — old code or concept is retired; kept for history, do not build from it

---

## Domain 1 — Progression (Storyweight / Standing / Step)

### V1 Current State

**Service:** `core/progression/ProgressionService.gd`

| Save field (per echo in `sanctum.roster[]`) | Type | Notes |
|---|---|---|
| `xp_total` | int | Cumulative XP |
| `rank` | int (1–5) | Major progression tier (V1 "rank" = V2 "Standing") |
| `level` | int (1–5) | Sub-progress within rank (V1 "level" = V2 "Step") |

**XP sources (balance.json `progression` block):**
- `xp_kill_bonus`: 25 per kill
- `xp_stage_clear_base`: 40 per stage
- `xp_realm_completion_bonus`: 100 on realm completion
- Virtue multipliers up to ×0.20 each (courage/wisdom/faith weighted)

**Level thresholds:** `[0, 100, 300, 600, 1000]` — 5 Steps per rank

**Rank-up:** triggers at `level == max_level_per_rank (5)` — increments rank, resets level to 1, carries XP overflow

**Config keys:**
```
data.progression.level_thresholds
data.progression.max_level_per_rank
data.progression.rank_level_base_shift
data.progression.rank_up_trait_drift_magnitude
```

**Player-facing language in V1:** XP / Rank / Level (used in snapshot data, UI strings, overlay)

---

### V2 Target (GDD §11.5)

| V2 concept | Maps from | Notes |
|---|---|---|
| `Storyweight` | `xp_total` | Main visible growth spine — represents reclaimed and integrated story |
| `Standing` | `rank` | Major maturity threshold; 5–10 Standings total |
| `Step` | `level` | Sub-progress within a Standing; 5–10 Steps per Standing |

- Each Standing should contain 5–10 Steps
- Steps are made from Storyweight gain and should be **visible to the player** — not a hidden internal value
- All player-facing strings must use V2 language: `Storyweight`, `Standing`, `Step`
- Internal save aliases (`rank`, `level`, `xp_total`) may persist during migration as compatibility fields (V2-MIG-002 adds the V2 bridge keys additively)

---

### Migration Action

| Item | Action | Owner |
|---|---|---|
| Player-facing language (snapshots, UI, overlay strings) | **Rewrite** | V2-PROG-001 |
| ProgressionService.gd internal logic (rank/level/xp) | **Carryover** during migration → **Rewrite** when milestone system ships | V2-PROG-004+ |
| `balance.json progression` config keys | **Carryover** (values valid) → relabeled by V2-PROG-001 | V2-PROG-001 |
| ActorSchema REQUIRED_FIELDS (`rank`, `xp_total`, `level`) | **Carryover** as compatibility aliases | V2-MIG-002 |

> **V2-PROG-001 scope note:** Player-facing snapshot keys, UI strings, and event dict keys are renamed to V2 vocabulary (Storyweight / Standing / Step). `balance.json` progression config keys (`level_thresholds`, `xp_kill_bonus`, etc.) are **not renamed** in this story — `ProgressionService.gd` reads them internally and a rename requires a service rewrite. Config key relabeling is deferred to V2-PROG-004+ (ProgressionService rewrite).

**Invariants:**
- `EchoFactory` RNG draw order is **IMMUTABLE** — rank/level birth values must stay at the same draw positions (append-only rule)
- Save repair must not lose existing `rank`/`level`/`xp_total` values; V2 bridge fields are additive only
- `DerivedStatService` uses `rank` for stat scaling — cannot rename until stat computation is also migrated

---

## Domain 2 — Calling

### V1 Current State

**Services:** `core/progression/CallingService.gd`, `core/progression/ProgressionService.gd`

**Current callings (V1, superseded):** `blade`, `warder`, `steward`, `ranger`, `seer` → **V2-PROG-004 ✅ Done** — replaced with `okofor`, `onyamesu`, `aduro`, `sum_okwanfo`, `okomfo`, `kra_soro`

| Save field (per echo) | Type | Notes |
|---|---|---|
| `calling_origin` | String | Birth calling weight (seeded at summon) — **ambiguous**: used both as birth bias AND as identity placeholder before confirmed calling |
| `calling` | String | Confirmed calling ID (empty string if not yet confirmed) |
| `calling_eligible` | bool | Set `true` when `rank == 3` |
| `calling_options` | Array | Temp ephemeral list during selection; erased on confirm |

**Eligibility gate:** `rank == 3` — only one calling milestone exists in V1

**Vector-to-calling map (balance.json):**
```
vanguard  → blade
protector → warder
pillar    → steward
seeker    → ranger (courage >= wisdom) or seer (wisdom > courage)
```

**Absolute fear thresholds by calling (balance.json):**
```
blade: 75, warder: 80, ranger: 80, steward: 85, seer: 85
```

**Calling origin ambiguity (known seam):** `calling_origin` is seeded at birth as a bias weight, but it doubles as the pre-confirmation identity string in UI snapshots. This is the primary seam that V2-PROG-002 must resolve before any Standing milestone work can proceed.

---

### V2 Target (GDD §11.5, §11 calling reference)

- Calling milestones at **Standing 3, Standing 6, Standing 9** (three-ring structure)
- Standing 3 = core calling confirmation (clearest vector-alignment layer)
- Standing 6 = deepening (allows drift and synthesis across adjacent calling families)
- Standing 9 = culmination (loosened structure, cross-track movement is valid)
- Calling names: V2 GDD §11 calling reference defines Standing-3 set — see `docs/calling-reference.md` for current list (note: may need alignment to V2 names)
- `calling_origin` ambiguity must be resolved first: one canonical birth-origin field + one confirmed-calling field, no overlap

**V2 Standing-3 calling set (GDD §11):**

| Calling | Standing-3 description |
|---|---|
| (Warder equivalent) | bears danger for others and refuses collapse |
| (Blade equivalent) | meets danger directly and turns courage into momentum |
| (Steward equivalent) | sustains life, morale, and communal steadiness |
| (Seer equivalent) | reads spirit, sign, and hidden meaning |
| (Ranger equivalent) | reads path, distance, and shifting ground |
| (Shadow/new) | moves through concealment, timing, and unseen openings |

> Note: V2 has **6 callings at Standing 3** vs V1's 5. The sixth (concealment/shadow family) is new. Exact V2 calling IDs must be confirmed against `docs/calling-reference.md` and the GDD before V2-PROG-004 begins.

---

### Migration Action

| Item | Action | Owner |
|---|---|---|
| `calling_origin` ambiguity (birth bias vs identity placeholder) | ~~Migration — resolve to two clean fields~~ **Resolved (V2-PROG-002)** | V2-PROG-002 |
| Calling eligibility gate (rank 3 → Standing 3/6/9) | **Rewrite** (UI milestone flow — pending) | V2-PROG-004+ |
| Calling names (V1 5 callings → V2 6 callings at S3) | ~~Rewrite~~ **Done (V2-PROG-004)** — 6 V2 IDs active in all backend systems | V2-PROG-004 ✅ |
| `calling_eligible`/`calling_options` ephemeral fields | ~~Supersede (safe to drop schema shape)~~ **Superseded (V2-PROG-002)** | V2-PROG-002 |
| Absolute fear thresholds by calling | ~~Carryover~~ **Done (V2-PROG-004)** — V2 values set in balance.json | V2-PROG-004 ✅ |
| V1→V2 save migration (blade/warder/steward/ranger/seer) | **Done (V2-PROG-004)** — SaveService repair migrates on load | V2-PROG-004 ✅ |

**V2-PROG-002 resolution (2026-04-06):**
- `calling_origin` — immutable birth bias. Seeded at summon by EchoFactory. Never changes. Fallback only.
- `calling` — confirmed runtime identity. Empty until Standing-3 milestone. Drives behavior, initiative, and prep snapshots.
- `BehaviorArbiter`, `CombatState._calc_initiative()`, and `FlowStageMapState` all prefer `calling` (confirmed) when set; fall back to `calling_origin`.
- `EchoActor.from_echo()` now projects both fields into the actor dict.
- `SaveService` bridge repair initialises `calling: ""` on all existing roster echoes (additive only).
- `calling_eligible` / `calling_options` are documented as ephemeral/deprecated — not the V2 gate shape.

**Invariants (still hold):**
- `calling_origin` is drawn at summon via `EchoFactory` — the draw order is immutable
- `ActorSchema.REQUIRED_FIELDS` still includes `calling_origin` — do not remove
- `calling` is NOT in REQUIRED_FIELDS (enemies/structures have none)

---

## Domain 3 — Vectors (10 Virtue Domains)

### V1 Current State

**Service:** `core/actors/VectorService.gd`

**Current vectors (4):** `protector`, `vanguard`, `seeker`, `pillar`

| Save field (per echo) | Type | Notes |
|---|---|---|
| `vector_scores` | Dict (String → int 0–1000) | One entry per vector |
| `dominant_vector` | String | Hysteresis-protected (3% threshold to switch) |

**Initialization:** `balance.json data.vectors.archetype_init` → per-class_origin starting scores
**Drift:** triggered at rank-up; weighted per `dominant_vector` (e.g. vanguard → courage 65%, wisdom 25%, faith 10%)

**Config keys:**
```
data.vectors.archetype_init
data.progression.vector_drift_weights
```

**Architecture note (migration-friendly):** VectorService uses **dynamic key iteration** — it does not hardcode the 4 vector names. Adding new vectors requires only `balance.json` changes. The code layer is config-driven. ✅

---

### V2 Target (GDD §13.1–§13.8)

The V1 4-vector model is **replaced** by the 10 V2 virtue domains. These are the Thread domains — not a separate "vector list" but the same underlying identity layer renamed and expanded.

**10 V2 virtue domains:**

| # | Virtue | Restores | Pressures |
|---|---|---|---|
| 1 | Courage | resolve, action under fear, risk tolerance | recklessness, overreach, defiant pride |
| 2 | Wisdom | discernment, interpretation, patience, judgment | hesitation, emotional distance, over-analysis |
| 3 | Leadership | responsibility, guidance, social steadiness | control, ego, burden, domination |
| 4 | Acceptance | grief processing, surrender to reality, peace with loss | passivity, fatalism, premature surrender |
| 5 | Humility | perspective, teachability, respect for limits | self-erasure, timidity, reduced self-worth |
| 6 | Forgiveness | release, repair, continuation after harm | naivety, repeated injury, unresolved resentment |
| 7 | Truth | clarity, self-recognition, honesty | shame, rupture, unbearable revelation |
| 8 | Generosity | offering, reciprocity, communal orientation | depletion, exploitation, self-neglect |
| 9 | Compassion | care for suffering, tenderness, protective warmth | exhaustion, over-identification, refusal of necessary hardness |
| 10 | Empathy | attunement, emotional understanding | blurred boundaries, emotional contagion, indecision |

**Virtue affinity wheel** (GDD §13.7 — internal only, not shown to player):
```
Courage → Leadership → Truth → Wisdom → Humility → Acceptance →
Forgiveness → Compassion → Empathy → Generosity → (loops back)
```

**Opposite-pair tensions (locked virtue pairings):**
```
Courage ↔ Acceptance
Leadership ↔ Forgiveness
Truth ↔ Compassion
Wisdom ↔ Empathy
Humility ↔ Generosity
```

**V2 vector-to-calling mapping:** The V1 `vector_to_calling` map must be rebuilt against the 10 virtue domains when V2-PROG-003 and V2-PROG-004 ship.

---

### Migration Action

| Item | Action | Owner | Status |
|---|---|---|---|
| `balance.json data.vectors.archetype_init` (4-vector init scores) | **Rewrite** — replace with 10-vector init scores (10 class origins × 10 vector keys) | V2-PROG-003 | ✅ Done |
| `balance.json data.progression.vector_drift_weights` (4 entries) | **Rewrite** — rebuilt for all 10 vectors | V2-PROG-003 | ✅ Done |
| `balance.json data.calling.vector_to_calling` map | **Rewrite** — extended to all 10 vectors with V1 calling IDs (interim; full V2 remap in V2-PROG-004) | V2-PROG-003 | ✅ Done |
| `balance.json data.actors.behavior.vector_action_muls` | **Rewrite** — 6 new vectors added to all 5 action types | V2-PROG-003 | ✅ Done |
| `balance.json data.combat.shrine.purify_weight_by_vector` | **Rewrite** — 6 new vectors added | V2-PROG-003 | ✅ Done |
| `balance.json data.grid.placement_modifiers.by_dominant_vector` | **Rewrite** — 6 new vectors added | V2-PROG-003 | ✅ Done |
| `balance.json data.combat.initiative_modifiers.by_dominant_vector` | **Rewrite** — 6 new vectors added | V2-PROG-003 | ✅ Done |
| `balance.json data.summoning.class_origin_weights` | **Rewrite** — 6 new class origins added at weight 1.0 | V2-PROG-003 | ✅ Done |
| `VectorService.gd` code | **Carryover** ✅ — config-driven, no code changes for expansion; `backfill_vector_scores()` static method added | V2-PROG-003 | ✅ Done |
| `SaveService.gd` vector repair | **Extend** — calls `VectorService.backfill_vector_scores()` to add 6 new keys to existing echo saves at 0 | V2-PROG-003 | ✅ Done |
| Existing `vector_scores` save data (4 old keys) | **Migration** — V2-MIG-002 ensures `{}` exists; V2-PROG-003 backfill adds 6 new keys at 0 on load | V2-MIG-002 + V2-PROG-003 | ✅ Done |
| `dominant_vector` save field | **Carryover** — field name valid; value preserved across backfill | V2-MIG-002 | ✅ Done |

**Invariants (unchanged):**
- VectorService MUST remain config-driven — do not hardcode virtue names in GDScript
- Old `vector_scores` keys (`protector`, `vanguard`, `seeker`, `pillar`) are preserved — backfill is additive only
- `BehaviorArbiter` scoring that references vector names must stay in sync with balance.json

---

## Domain 4 — Directives ✅ Done (V2-DIRECTIVE-001)

### V2 Current State

**Service:** `core/directives/DirectiveService.gd`

**Registered directives (2 — V2 foundation pair):**

| ID | Selectable | Intent weights |
|---|---|---|
| `directive.scout_carefully` | ✅ Always | survival_bias, avoid_overcommit, prefer_disengage, resource_efficiency |
| `directive.seek_signs` | ✅ Always | clue_seeking_priority, reporting_priority, exposure_acceptance, survival_bias |

Each directive also carries `pros: Array[String]` and `cons: Array[String]` (2 each, game-tone, for the selection overlay).

**Save field:** `stage_context.active_directive_id` (String) — carryover, field name unchanged.

**Save repair (V2-DIRECTIVE-001):** `directive.none` → `directive.seek_signs`; `directive.scout` → `directive.scout_carefully`; all other V1 IDs → `directive.scout_carefully`.

**Directive selection:** Blocking overlay on `StageScreen` — appears on every stage entry. Player must confirm before interacting with the stage. Scene: `ui/screens/venture/DirectiveSelectOverlay.tscn`.

**Intent-weight scoring:** `BehaviorArbiter._directive_bonus()` — generic loop over `balance.json data.actor.directive_action_muls`. No GDScript changes needed to add new directives. V2 semantic keys added: `avoid_overcommit`, `exposure_acceptance`, `clue_seeking_priority`, `reporting_priority`.

V1 locked directives (`protect`, `push`, `preserve`, `focus`) — **superseded**. Commented out in service. Deferred to a future expansion DIRECTIVE story.

---

### Migration Action (resolved)

| Item | Action | Status |
|---|---|---|
| `directive.scout` | **Rewrite** → `directive.scout_carefully` with V2 weights | ✅ Done |
| `directive.none` | **Rewrite** → `directive.seek_signs` (remap) | ✅ Done |
| `directive.protect`, `push`, `preserve`, `focus` | **Superseded** — removed from registry | ✅ Done |
| `stage_context.active_directive_id` save field | **Carryover** — key name and format unchanged | ✅ Done |
| V1→V2 save repair | Added migration block to `SaveService.gd` | ✅ Done |
| `balance.json directive_action_muls` | V2 semantic keys added | ✅ Done |
| `BehaviorArbiter._DEFAULTS` | Mirrored balance.json additions | ✅ Done |
| `FlowStageState` snapshot | Added `data.directive` payload; refactored to `static build_snapshot()` | ✅ Done |
| Selection UI | `DirectiveSelectOverlay.tscn` + `.gd` on `StageScreen` | ✅ Done |

---

## Domain 5 — Sanctum

### V1 Current State

**Services/states:** `FlowSanctumState.gd`, `SanctumService.gd`, `SanctumShell.gd`, `SanctumScreen.gd`

**What V1 Sanctum provides:**
- Roster display (echoes with name/rank/calling)
- Party management (up to 5 slots — toggle in/out)
- Summon flow (Ase-gated)
- Realm select (realm cards + runtime locks)
- Bonds display (social graph — BOND-001 ✅ merged)
- Vow management (doctrine pledges — VOW-001 ✅ merged)

**What V1 Sanctum does NOT have:**
- Building system (no Training Grounds, Council Hall, Hearth, Smith, Old Great Tree)
- Job assignments (no Trainer, Mayor, Cook/Bartender, Armorer, Caretaker)
- Continuity spine (no `continuity` field in save)
- Ambient incident system
- Spatial visualization (Echoes visible in house)

**Save schema (V1):** `save_data["sanctum"]` contains: `roster`, `active_party_ids`, `name`, `starter_granted`, `bonds`, `party_encounters`, `active_vow`, `unlocked_vows`

> **Schema discrepancy note:** `SaveSchema.gd` shows `unlocked_vows: []` (Array), but `CONVENTIONS.md` (updated post-BOND/VOW merge) shows `vows: {}` (Dict keyed by vow_id). The CONVENTIONS.md version is canonical (it is more recent). V2-MIG-002 save bridge should validate which shape is live and repair accordingly.

---

### V2 Target (GDD §20.17, §23.1)

**Five foundation buildings + jobs:**

| Building | Job | Primary role | Unlock timing |
|---|---|---|---|
| Hearth | Cook / Bartender | Recovery/morale, social mixing, high-frequency incidents | Early — first available |
| Training Grounds | Trainer | Readiness/preparation, rivalry/status pressure, sharper incidents | Early — first available |
| Council Hall | Mayor | Governance, broader house direction | Mid — after care layer |
| Smith / Crafter | Armorer / Smith | Crafting, gear, build capacity | Mid |
| Old Great Tree | Caretaker / Spirit Guide | Spiritual support, continuity meaning | Mid-to-late |

**Continuity** (`continuity` save key — new): Sanctum growth spine measuring rootedness and cultural maturity through rituals, vow adherence, recovered Threads, relationship growth, Echo social density.

**Ambient incident system:** Echoes visible in house, moving/lingering/working/arguing. Incidents surface through building+job state. Routine presentation primarily ambient.

**Architecture invariants:**
- `FlowSanctumState` snapshot shape (type/meta/data/actions) remains valid rail
- `SanctumShell` + cached-nav pattern stays
- Flow state IDs are unchanged — new building/Continuity states extend the SANCTUM family

---

### Migration Action

| Item | Action | Owner |
|---|---|---|
| Flow state machine (FlowSanctumState, shell) | **Carryover** — valid rail | — |
| Building system (5 buildings) | **New Build** | V2-SANCTUM-001+ |
| Job system (5 jobs) | **New Build** | V2-SANCTUM-001+ |
| Continuity save key + service | **New Build** | V2-SANCTUM-001+ |
| Ambient incident system | **New Build** | V2-SANCTUM-001+ |
| Spatial visualization (echo presence in house) | **New Build** | V2-SANCTUM-001+ (post-foundation) |
| `save_data["sanctum"]` schema (additive) | **New Build** (additive fields only) | V2-MIG-002 |

**Invariants:**
- All new Sanctum save fields are **additive only** — never remove existing fields
- `SanctumService.get_party_actors()` and `get_roster_actors()` are valid choke points
- Bond/vow save keys already merged (BOND-001, VOW-001 Done) — do not re-add

---

## Domain 6 — Economy

### V1 Current State

**Services:** `core/economy/EconomyService.gd`, `core/economy/EconomyAccrualService.gd`

**Current currencies:**

| Key | Status | Role |
|---|---|---|
| `economy.ase` | ✅ Active | Primary spendable — summoning, rites, Thread handling |
| `economy.ekwan` | ⚠️ Placeholder | Saved but no spend logic yet |

**No V2 currencies in save schema:**
- No `relics`
- No `faith`
- No `harmony`
- No `favor`
- No `threads` reserve
- No `continuity` (see Domain 5)

**Accrual model:** Settlement-based (not frame-based). Settle before every spend. Offline accrual applied once per session on Continue. Cap: 8hr.

**Config (balance.json):**
```
data.economy.ase_online_per_min_base: 0.3
data.economy.sanctum_bank_interval_seconds: 240
data.economy.offline_cap_seconds: 28800
data.summoning.grade_costs: { uncalled: 60, called: 150, chosen: 400 }
```

---

### V2 Target (GDD §19.1–§19.2)

**Spendable currencies (3):**

| Currency | Role |
|---|---|
| `ase` | Life-source currency. Summoning, rites, Thread handling. Offline accrual tapers with Sanctum stability/strain. |
| `ekwan` | Shaped matter and build capacity. Rooms/buildings, crafting, research/preparation. |
| `relics` | Rare artifact layer. Equippable special artifacts or rare catalysts. Remains scarce — remembrance and weight. |

**Visible states (not normal currencies — not spent like money):**

| State | Role |
|---|---|
| `faith` | Sanctum-level visible state. Influences decisions and atmosphere. |
| `harmony` | Sanctum-level visible state. House social coherence. |
| `favor` | Sanctum-level visible state. |

**Progression/readiness states (not spent):**

| State | Role |
|---|---|
| `continuity` | Sanctum growth spine (see Domain 5) |
| `threads` (reserve) | Crystallized story fragments returned from Realm completion; enter reserve before Weaving Rite |

---

### Migration Action

| Item | Action | Owner |
|---|---|---|
| `economy.ase` (active) | **Carryover** — field name, service choke points all valid | — |
| `economy.ekwan` (placeholder) | **Carryover** → activated when building/crafting system ships | V2-ECONOMY-001+ |
| `EconomyService.spend_ase()` / `add_ase()` / `can_afford_ase()` | **Carryover** — valid single choke points | — |
| Settlement model (no frame-based accrual) | **Carryover** | — |
| Relics (new currency) | **New Build** | V2-ECONOMY-001+ |
| Faith / Harmony / Favor (visible states) | **New Build** | V2-ECONOMY-001+ / V2-SANCTUM-001+ |
| Threads reserve (save key) | **New Build** | V2-WEAVE-001+ |
| Ase offline accrual degradation (Sanctum stability) | **Rewrite** — currently flat; V2 says strain/neglect weakens recovery toward near-zero | V2-ECONOMY-001+ |

**Invariants:**
- `economy.ase` and `economy.ekwan` keys must remain until migration is complete
- All new economy keys are additive; handled by V2-MIG-002 save bridge
- UI balance predictions remain non-authoritative (Core is always authoritative)

---

## Already-Merged V2 Work (Valid Rails — Do Not Overwrite)

These systems are already done and their save seams are live:

| Story | System | Save keys (in `save_data["sanctum"]`) |
|---|---|---|
| BOND-001 | Social graph | `bonds: []`, `party_encounters: []` |
| VOW-001 | Vow doctrine | `vows: {}` (keyed by vow_id), `active_vow: {}` |
| V2-WEAVE-001 | Thread recovery model | `sanctum.threads: {}` (keyed by thread_id); `realms[id].realm_recovery_segments: []` |
| V2-WEAVE-002 | Foundation Weaving Rite loop | per-echo `woven_threads: []`, per-echo `weave_memory_marks: []` |
| V2-EMOTION-001 | Fear & Morale Readability | Shipped dual `morale_tier` + `fear_signal` display. Unified to single `emotional_status` in V2-EMOTION-002. |
| V2-EMOTION-002 | Unified Emotional Status | Replaced dual display with 8-tier `emotional_status` (radiant → hollow). `get_fear_signal()` removed. `get_emotional_status(morale, fear)` added. EchoParty morale/fear bars removed. All emotion surfaces now use single field. Documented in CONVENTIONS.md with no-dual-display rule. |

> See CONVENTIONS.md `SocialGraphService` and `VowService` sections for full API contracts.

---

## Domain 7 — Stage System (Exploration Map)

### V1 Current State

**Services/states:** `FlowStageState.gd`, `RealmGenerator.gd`, `StageModel.gd`, `ObjectiveModel.gd`

**What V1 Stage provides:**
- Linear `stages[i].objectives[]` array — all objectives visible upfront
- No exploration map; stage is a pre-combat screen that routes directly to `flow.encounter`
- No hidden situation state, no party movement, no intel layer

**Save schema (V1):** `save_data["realms"][id].stages[]` — each stage has `index`, `type`, `seed`, `objectives[]`

---

### V2 Target (GDD — Stage System)

**Procedural exploration tilemap** — party navigates a lockable isometric map with scattered hidden "situations".

**Key V2 stage concepts:**
- Party moves as one guided group token (player is a guide, not commander)
- Directive-guided AI movement: `scout_carefully` → nearest unresolved; `seek_signs` → nearest objective first
- Situations hidden by default (`revealed: false`); rendered as '?' until revealed
- Situation types: `combat` (→ encounter), `npc` / `loot` / `money` (→ inline overlay in foundation)
- Map locks on first entry and persists (deterministic re-entry via `CampaignSeed`)
- `intel_clues: []` extensibility slot on every situation (V2-INTEL-001 reads/writes here)
- Map size: random asymmetric per stage, minimum 30×30; earlier realms smaller, later realms larger

**New models:**
| Model | File | Purpose |
|---|---|---|
| `SituationModel` | `core/realms/SituationModel.gd` | Single situation dict factory |
| `StageExploreModel` | `core/realms/StageExploreModel.gd` | Exploration map dict factory; attached as `stages[i]["explore_map"]` |

**New flow state:** `flow.stage_explore` — `core/state/flow/states/venture/FlowStageExploreState.gd`

---

### Migration Action

| Item | Action | Owner | Status |
|---|---|---|---|
| `stages[i].objectives[]` array | **Carryover** — unchanged, additive only | — | ✅ Done |
| `stages[i]["explore_map"]` field | **New Build** — added by `RealmGenerator`; default injected by `SaveService` repair | V2-STAGE-001 | ✅ Done |
| `StageModel.REQUIRED_FIELDS` | **Extend** — added `"explore_map"` | V2-STAGE-001 | ✅ Done |
| `RealmGenerator.generate()` | **Extend** — appended `_generate_explore_map()` after all existing RNG draws | V2-STAGE-001 | ✅ Done |
| `FlowStageState.cta.start` | **Rewrite** — routes to `STAGE_EXPLORE` instead of `ENCOUNTER` | V2-STAGE-001 | ✅ Done |
| `FlowStageExploreState` | **New Build** | V2-STAGE-001 | ✅ Done |
| Situation type taxonomy | **New Build stub** — combat/npc/loot/money stubs; full V2 objective taxonomy deferred | V2-STAGE-002 | Draft |
| Intel persistence across runs | **Done** — `revealed`/`resolved` persist across sessions; `intel_clues` + `intel_quality` written on reveal/engagement; `objectives_found` recomputed from flags on entry; Seek Signs +15pt threshold | V2-INTEL-001 | ✅ Done |
| NPC contact actor framework | **Deferred** — inline overlay placeholder only | V2-STAGE-003 | Draft |
| Loot/money full outcomes | **Deferred** — inline overlay stubs only | V2-STAGE-004 | Draft |
| Individual party units | **Deferred** — group token only in foundation | V2-STAGE-101 | Draft |
| Escape mechanic (full) | **Deferred** — stub roll > 40 in foundation | V2-INTEL-002 | Draft |

**Invariants:**
- `stages[i].objectives[]` array NEVER touched by explore_map work (additive only)
- `RealmGenerator` RNG draw order NOT reordered — explore paths appended after all existing draws
- All situations start `revealed: false`, `resolved: false`, `intel_clues: []`
- `SaveService` repair is additive — missing `explore_map` gets `StageExploreModel.make_default()`, never removed

---

## Story Dependency Order (Alignment Wave)

```
V2-MIG-001 (this doc) ✅ Done
  ├── V2-MIG-002  Save schema bridge (additive V2 roots + repair) ✅ Done
  ├── V2-PROG-001 Progression language rename (Storyweight / Standing / Step) ✅ Done
  ├── V2-PROG-002 Calling seam unification (calling_origin ambiguity) ✅ Done
  │     └── V2-PROG-003 Vector expansion (4 → 10 vectors) ✅ Done
  │           └── V2-PROG-004 V2 calling IDs (6 callings, save migration) ✅ Done
  │                 └── V2-PROG-005 Skill family foundation (Ward/Break/Veil/Path/Rite/Root) ✅ Done
  │                 └── V2-PROG-006 Maturity-expression seam (SmartnessTier → expression_band) ✅ Done
  │                       └── V2-PROG-004+ Standing milestone UI system (S3/S6/S9 flow)
  ├── V2-DIRECTIVE-001 Directive rewrite (Scout Carefully / Seek Signs) ✅ Done
  ├── V2-SANCTUM-001+  Building + Continuity system
  ├── V2-ECONOMY-001+  Economy expansion (Relics, Faith, Harmony, Favor)
  ├── V2-DIRECTIVE-001 Directive rewrite (Scout Carefully / Seek Signs) ✅ Done
  │     └── V2-STAGE-001 Exploration stage map foundation ✅ Done
  │           ├── V2-INTEL-001  Intel persistence + intel_clues ✅ Done
  │           ├── V2-INTEL-002  Full escape / scouting sacrifice mechanic
  │           ├── V2-STAGE-002  Full V2 objective taxonomy (Scout/Reveal, etc.)
  │           ├── V2-STAGE-003  NPC contact actor framework
  │           ├── V2-STAGE-004  Loot/money full outcomes
  │           └── V2-STAGE-101  Individual party units / roaming enemies
  ├── V2-EMOTION-001   Fear & Morale Readability ✅ Done
  │     (get_fear_signal() · morale_tier/fear_signal in party_preview/party_slots/actor dicts)
  │     (EchoCardItem FearBadge · InitiativeRowItem MoraleBadge+RefusingLabel)
  │     (ResolveScreen EmotionSection · SanctumScreen House State strip)
  │     └── V2-SANCTUM-001+ Fear & morale recovery in Sanctum (open design)
  └── V2-WEAVE-001     Foundation Thread recovery model ✅ Done
        (per-stage segments → Realm completion → Threads crystallize → sanctum.threads reserve)
        (Thread Reserve Strip in Sanctum, Recovery Cord in StageMap)
        └── V2-WEAVE-002 Foundation Weaving Rite loop ✅ Done
```

PROG-001 and MIG-002 can proceed in parallel. All others depend on MIG-002 being done first for save bridge coverage.

---

## Open Questions Before Implementation

1. **V2 calling IDs:** ✅ RESOLVED (V2-PROG-004). Final IDs: `okofor`, `onyamesu`, `aduro`, `sum_okwanfo`, `okomfo`, `kra_soro`. See `docs/calling-reference.md` for full reference.
2. **Virtue domain vector IDs:** ✅ RESOLVED (V2-MIG-002). Vector keys remain lowercase vector names (`vanguard`, `protector`, `seeker`, `pillar`, + 6 new ones in V2-PROG-003). They are NOT the virtue names. Save repair in V2-MIG-002 ensures `vector_scores: {}` exists per echo; key expansion to all 10 vectors is V2-PROG-003's job (alongside balance.json update).
3. **Standing count:** GDD says "5–10 Standings total" — exact number needs locking before V2-PROG-004.
4. ~~**Threads reserve vs Thread items:** The relationship between stage-level recovery segments and full Thread items (Realm completion) needs one more clarity pass before V2-WEAVE-001.~~ **RESOLVED (V2-WEAVE-001 ✅ Done)** — stages contribute per-stage recovery segments (stored in `realm_recovery_segments`); full Threads crystallize only on Realm completion (1–3, always ≥1) and enter `sanctum.threads` reserve (cap=4). See CONVENTIONS.md `ThreadService` section for full API contract.
