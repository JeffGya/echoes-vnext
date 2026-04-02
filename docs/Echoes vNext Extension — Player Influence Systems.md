# Echoes vNext Extension — Player Influence Systems (Scouting, Sanctum Jobs, +3)

**Purpose:** Extend the vNext addendum with concrete *player-influence* systems that keep Echoes a **layered game** (choices + consequences) rather than a “watch-only simulator.”

This document introduces **two confirmed systems** and **three additional systems** of comparable complexity. For each system, it defines:

- What it is (player-facing)
- What it changes (tactical + narrative)
- How it slots into the **GDD loop** and **vNext pillars**
- What state machines / runtime systems it needs
- Snapshot + Action contract implications (UI stays decoupled)

---

## 0) Non-negotiables carried forward from vNext

### 0.1 Pillars

1. **State machines own flow and logic** (flow + encounter + actor)
2. **Grid / map is canonical** for space and objective play
3. **UI/UX ships with every feature** via **snapshots + action lists**, not hard-coded UI logic

### 0.2 “Game, not simulator” requirement

Echoes is a game when players can reliably:

- Set **intent** (what matters)
- Make **tradeoffs** (risk vs reward)
- See **consequences** (tactical and narrative)

This extension focuses on systems that add meaningful decisions **without direct control**.

### 0.3 UI architecture note (from the YouTube summary)

We adopt the *spirit* of “controls talk to state, state notifies controls,” but using **vNext’s snapshots/actions**:

- UI **dispatches actions** (by id)
- State machines **validate + apply**
- UI **renders snapshots**

We avoid deep signal cascades for core simulation so changes remain:

- Deterministic
- Explainable
- Replayable

---

# System 1 — Stage Directives: Scouting / Sacrifice (confirmed)

## 1.1 Player-facing concept

Before entering a stage, the Keeper chooses a **Directive** that shapes Echo behavior as **weighted preferences**:

- **SCOUT** (information-first)
- (future examples) PROTECT, PRESERVE, PUSH, FOCUS

**SCOUT** enables deliberate “cheap probe” runs *or* high-skill recon attempts. Scouting outcomes depend on the party’s **INT/CHA/AGI** and survival.

## 1.2 Tactical effect

Scouting produces **Information** (tiered) about the stage:

- Enemy faction + rough count
- Wave count / packs
- Objective modifiers (e.g., shrine drain parameters)
- Approx stat ranges / role tags

Higher combined INT/CHA/AGI increases info depth and may unlock **non-loss recon options** on later attempts.

## 1.3 Narrative + Sanctum effect (Sacrifice)

Scouting above recommended difficulty can be used as sacrifice. Consequences scale with:

- **Relative power** of lost Echoes (level vs recommended)
- **Charisma** (social weight)
- Archetype tone
- Current morale/fear

This creates meaningful tragedy:

- Losing a beloved, high-CHA Echo shakes the Sanctum more than losing a low-impact recruit.

## 1.4 Slotting into GDD + vNext

- **GDD alignment:** “Guidance > Control” — the Keeper sets intent; Echoes interpret.
- **vNext alignment:** Directives are the canonical “player influence now” layer.
- **Realms/Stages:** SCOUT becomes a stage-level choice that changes outcomes and future planning.

## 1.5 Required systems / state machines

### Flow State Machine

- Adds a **Pre-Stage Directive** step:
    - `stage_briefing → directive_select → party_confirm → stage_enter`

### Encounter State Machine

- Stores `directive_id` in encounter context.
- Ensures directive is part of deterministic input.

### Actor State Machine

- Reads directive weights and biases intent:
    - survival bias, avoid overcommit, prefer disengage/guard, prioritize “reporting” behaviors.

### New/extended services

- **DirectiveService** (data + tuning): directive definitions, weights, unlocks.
- **ReconService** (info scoring + tier mapping): deterministic info extraction from stage + observed events.
- **SanctumRippleService** (emotional ripple computation): applies Sanctum-wide deltas when scouting fails.

## 1.6 Snapshot + Action contract

### Actions

- `directive_set_scout`
- `directive_set_protect` (future)

### Snapshots

- Stage briefing snapshot includes:
    - recommended level estimate
    - risk preview bands (not exact)
    - expected info tier range given party stats
- Post-stage report snapshot includes:
    - recon findings (tiered)
    - sanctum impact summary (fear/morale ripples)

---

# System 2 — Sanctum Jobs & Buildings: Institutions (confirmed)

## 2.1 Player-facing concept

The Sanctum grows into a living hub. Echoes can be assigned to **Jobs** inside **Buildings**:

- Trainer, Mayor, Cook/Bartender, Armorer/Smith, etc.

Job outcomes are **emergent**, based on:

- Echo traits + stats
- Morale/fear
- Archetype
- History (battle-hardened, repeated failures, heroic victories)

Echoes can eventually become **Pillars** (permanently stationed), acting as mentors that shape future workers.

## 2.2 Tactical effect

Buildings provide gameplay modifiers that affect runs:

- Training boosts growth/XP curves
- Workshop unlocks gear upgrades / repairs
- Council affects realm choices / risk mitigation
- Hearth improves recovery / morale stabilization

But outcomes are not fixed: a low-morale charismatic mayor may become a “shady dictator” — short-term gain, long-term debuff, and costly removal.

## 2.3 Narrative effect

Sanctum becomes a cultural mirror of the Keeper’s choices.

- Who you elevate
- Who you exile
- Who you sacrifice

Jobs can create **event arcs** (conflicts, mentorship, corruption, inspiration).

## 2.4 Slotting into GDD + vNext

- **GDD alignment:** Sanctum is the reflection layer; heroes develop identity and legacy.
- **vNext alignment:** State-first + snapshot-driven UI makes the Sanctum playable early without hardcoding.
- **Bridge effect:** Sanctum systems provide *persistent* context that changes how Realms play.

## 2.5 Required systems / state machines

### Flow State Machine

- Sanctum expands into substates:
    - `sanctum_overview → buildings → building_detail → assign_job → resolve_events`

### New: Sanctum State Machine (micro)

A dedicated micro-state machine under Flow to keep Sanctum logic clean:

- building placement/upgrade
- job assignment
- periodic ticks
- event resolution

### Actor State Machine (Sanctum mode)

Same actor AI layer, different context:

- “work intent” selection
- retention (who leaves job early)
- mentorship behavior

### New/extended services

- **SanctumService**: buildings, slots, upgrades, staffing.
- **JobOutcomeResolver**: computes emergent modifiers + risks.
- **SanctumTickService**: time-based progression (background effects) + event triggering.

## 2.6 Snapshot + Action contract

### Actions

- `building_build_<id>`
- `building_upgrade_<id>`
- `job_assign` / `job_unassign`
- `pillar_confirm` (permanent assignment)

### Snapshots

- Sanctum overview shows:
    - buildings, staffing, current modifiers, risks
- Job detail shows:
    - “synergy” bands (Weak/Moderate/Strong)
    - discovered traits (progressively revealed)
    - events in motion

---

# System 3 — Realm Intel & Risk: Rumors, Omens, and Commitment (new)

## 3.1 Player-facing concept

Before committing to a node/stage, the Keeper can acquire **Intel** through:

- Rumors (cheap, unreliable)
- Omens (costly, more reliable)
- Sanctum institutions (Mayor/Chronicler/Scoutmaster)

Intel is a *layered* information system that supports planning without removing uncertainty.

## 3.2 Tactical effect

- Better intel improves:
    - directive selection
    - party selection
    - avoidance of catastrophic mismatches
- Intel can reveal:
    - objective type likelihood
    - enemy role tags
    - special modifiers (e.g., “shrine drain is severe”)

## 3.3 Narrative effect

Intel has tone:

- False rumors lead to tragedy
- Clear omens feel like ancestral guidance
- Chroniclers create a culture of preparedness

## 3.4 Slotting into GDD + vNext

- **GDD alignment:** Realms as meaning-laden journeys; the Keeper interprets signs.
- **vNext alignment:** strengthens *player influence* in the map layer (not just combat).

## 3.5 Required systems / state machines

### Flow State Machine

- Adds a **Map Intel** decision point:
    - `map_node_hover → intel_panel → commit_node`

### Services

- **IntelService**: stores intel items with reliability, expiry, and provenance.
- **OmenResolver**: deterministic generation of hints from realm seed + sanctum modifiers.

## 3.6 Snapshot + Action contract

- Node snapshot includes: known intel, confidence bands.
- Actions: `intel_buy_rumor`, `intel_request_omen`, `commit_node`.

---

# System 4 — Echo Bonds & Rivalries: Social Graph as Gameplay (new)

## 4.1 Player-facing concept

Echoes develop relationships:

- Bonds (mentor/protege, friendship)
- Rivalries (competition, resentment)

Relationships evolve based on:

- shared missions
- job assignments
- sacrifice events
- morale/fear trajectories

## 4.2 Tactical effect

Relationships influence:

- directive compliance likelihood
- fear refusal thresholds
- guard/support tendencies
- synergy bonuses when bonded pairs deploy together

## 4.3 Narrative effect

Creates emergent stories:

- A bonded pair refuses to abandon each other
- A rivalry escalates into sabotage in the Workshop

## 4.4 Slotting into GDD + vNext

- **GDD alignment:** “Echoes of Personality” + legacy continuity.
- **vNext alignment:** actor decisions remain deterministic but socially grounded.

## 4.5 Required systems / state machines

### Actor State Machine

- Reads relationship weights in intent selection:
    - protect bonded ally
    - refuse directives that risk rival’s safety (or do the opposite)

### Services

- **BondService**: stores graph edges, updates via events.
- **BondEventResolver**: triggers sanctum events and combat barks.

## 4.6 Snapshot + Action contract

- Roster snapshot includes bond indicators.
- Sanctum events snapshot includes relationship consequences.
- Actions: `resolve_event_choice_<a|b|c>`.

---

# System 5 — Vows & Burdens: Persistent Promises that Shape Runs

## 5.1 Player-facing concept

The Keeper can pledge a **Vow** — a cultural doctrine that defines how the Sanctum operates. Each vow carries a proverb in Twi, a benefit that activates while the vow is held, and a tradeoff the Keeper accepts as constraint.

Vows are discovered through play (realm events, scenario triggers). Until discovered, they appear as riddle-hinted mysteries on the Vow screen. Once discovered, the Keeper can pledge the vow at any time — not just at the start of a realm.

Only one vow can be active at a time. A vow releases naturally when a realm run completes. Breaking a vow early applies the full penalty immediately.

## 5.2 Tactical effect (VOW-001 foundation — behaviour hooks pending VOW-002+)

- Breaking a vow triggers:
    - Ase cost (configurable per vow in `balance.json`)
    - Morale delta applied to all roster echoes via `EmotionService`
    - Fear delta applied to all roster echoes via `EmotionService`
- Deferred: vow-in-effect hooks that bias Actor SM intent weights globally (VOW-002+)

## 5.3 Narrative effect

Vows create identity and doctrine:

- Pledging displays a “moment of reflection” overlay — proverb in Twi + English, “The web remembers.”
- The active vow proverb is shown on the Sanctum screen as a mantra under the Sanctum name.
- Breaking requires explicit confirmation with the full penalty shown before committing.

## 5.4 Slotting into GDD + vNext

- **GDD alignment:** the Keeper’s guidance shapes meaning and legacy. Vows are cultural memory.
- **vNext alignment:** a systemic influence layer — unlock through play, commit to doctrine, face consequences.

## 5.5 Built in VOW-001

### Flow State
- `FlowVowState` (`core/state/flow/states/sanctum/FlowVowState.gd`) — static `build_snapshot()`. Snapshot type `flow.vow_manage`. Routed via `SanctumShell`.

### Services
- **VowService** (`core/sanctum/VowService.gd`): unlock, pledge, break, release, snapshot builder.
- Pledge timing: `pledged_at_realm` tracks which realm was active at pledge; `runs_at_pledge` handles Sanctum-only pledges.

### UI
- `VowScreen.tscn/.gd` — two-panel layout: card list left, detail right.
- `VowCard.tscn/.gd` — reusable card component. Undiscovered = `?` + riddle hint. Discovered = full detail.
- `PledgeMomentOverlay` — dark indigo full-screen overlay, 250ms fade, proverb + “The web remembers.”
- `BreakConfirmOverlay` — dark crimson full-screen overlay, 250ms fade, irreversible confirmation gate.
- `VowMantraLabel` on SanctumScreen — active vow proverb in Akan Gold under Sanctum title.

### Save schema additions
- `sanctum.vows: {}` — Dict of discovered vow entries keyed by vow_id.
- `sanctum.active_vow: {}` — active pledge state (`{}` when none).

### Balance additions (`data.sanctum.vows`)
- One vow defined: `tikoro_nko_agyina` (“Tikoro nko agyina” / “One head does not constitute a council”). Party-size doctrine.

### Tests
- `VowServiceTests.gd` — unlock, pledge, break, release, snapshot contracts.

## 5.6 Snapshot + Action contract

- `flow.vow_manage` snapshot: `can_pledge`, `active_vow`, `available_vows[]`
- Actions: `vow.pledge { vow_id, tier }`, `vow.break`, `nav.back`
- Debug (F1 panel): `vow unlock <id>`, `vow pledge <id>`, `vow break`, `vow status`

## 5.7 Deferred to VOW-002+

- Vow bias hooks into Actor SM intent weights (BehaviorArbiter integration)
- `VowViolationTracker` — deterministic violation detection during combat rounds
- Multiple vow tiers (VOW-001 implements tier 1 only)
- Additional vow definitions beyond `tikoro_nko_agyina`
- Vow unlock via in-game scenario triggers (currently debug-only)
---

# 6) Integration Map — where these systems live in the loop

## 6.1 Macro loop touchpoints

- **Sanctum**: Jobs/Buildings, Reflection, Vows, Bonds events
- **Realm Map**: Intel, node commitment, risk shaping
- **Stage**: Directives (SCOUT), sacrifice outcomes
- **Combat**: Actor SM interprets directive + vow + bonds deterministically
- **Aftermath**: Recon report, sanctum ripple, relationship updates

## 6.2 Determinism inputs

To keep “same inputs → same outcome,” include these as explicit inputs:

- campaign seed
- realm/stage seed
- party roster + ordering
- selected directive
- active vows
- relevant sanctum modifiers (institutions)
- relationship graph state

All must be logged and included in snapshots.

---

# 7) Implementation notes — preventing “watch-only” drift

## 7.1 Minimum viable influence per encounter

Every stage should expose at least one meaningful choice:

- directive
- intel spend
- vow consequence
- event resolution

## 7.2 Explainability requirement

Whenever an Echo deviates from player intent, logs should cite:

- directive weight
- vow pressure
- fear/morale
- archetype bias
- bond/rivalry influence

This keeps autonomy *legible*, not frustrating.

## 7.3 UI discipline

UI remains modular by only:

- rendering snapshots
- dispatching action ids

No UI control should directly mutate simulation state.

---

# 8) MVP sequencing suggestion (to avoid scope explosion)

1. **Stage Directives (SCOUT)** + Recon report + Sanctum ripple
2. **Sanctum Buildings (3)** + staffing + simple modifiers + a small tick
3. **Realm Intel (Rumor/Omen)**
4. **Bonds (light graph + 2 event types)**
5. **Vows (2 vows + violation tracking)**

---

# 9) Open knobs (designer decisions)

- Which stats define “power” for sacrifice ripple? (level vs composite power)
- How much intel is ever allowed to be certain?
- How quickly do pillars form, and are they reversible?
- Are vows optional (risk/reward) or always-on doctrine?
- Bonds: are they mostly buffs, mostly complications, or balanced?

---

# 10) MVP Scope Lock (Phase 1 Commitment)

This section defines the **hard MVP boundary** for these systems. No expansion beyond this list until Phase 1 is playable and stable.

## 10.1 Stage Directives (MVP)

Ship only:

- Directive: `SCOUT`
- Baseline (no directive)

Include:

- Actor SM survival bias
- 3-tier recon report (Low / Medium / High)
- Sanctum fear ripple scaling by relative power + Charisma
- Clear log explanations for deviation

Exclude for now:

- Additional directives
- Safe recon unlock paths
- Enemy adaptation
- Diminishing returns

---

## 10.2 Sanctum Jobs & Buildings (MVP)

Ship only 3 buildings:

1. Training Grounds
2. Council Hall
3. Hearth

Each building:

- 1 primary slot
- Simple synergy band (Weak / Moderate / Strong)
- Small persistent modifier
- Basic periodic tick (no complex event chains yet)

Exclude for now:

- Complex corruption arcs
- Multi-slot institutions
- Full Pillar permanence system (only mark as eligible)

---

## 10.3 Realm Intel (MVP)

Ship only:

- 1 Rumor (cheap, unreliable)
- 1 Omen (costly, more reliable)

Intel reveals:

- Objective likelihood
- Enemy role hint

Exclude for now:

- Expiring intel
- Multi-source intel stacking
- Chronicler synergy depth

---

## 10.4 Bonds (MVP)

Ship only:

- Friend
- Rival

Effects:

- Slight protect bias (Friend)
- Slight deviation bias (Rival)

Exclude for now:

- Multi-level bonds
- Complex betrayal arcs

---

## 10.5 Vows (MVP)

Ship only 2 vows:

1. Protect the Objective
2. No One Dies Alone

Include:

- Global bias weight
- Minor morale consequence on violation

Exclude for now:

- Doctrine stacking
- Removal penalties
- Escalating vow tiers

---

# 11) Narrative Integration — Anansi as Systemic Presence

This section clarifies how these mechanics align with the **Anansi mythic layer** without requiring heavy exposition.

Anansi is not a boss or narrator. He is the weaver of uncertainty and consequence.

## 11.1 Directives — “Walking the Web”

Selecting SCOUT is stepping into the web intentionally.

- Information gained = threads revealed.
- Sacrifice ripple = the web tightening.

Logs and flavor text should reference tension, threads, whispers, tightening patterns — not raw data.

---

## 11.2 Sanctum — “Weaving Against Oblivion”

The Sanctum is a counter-web.

- Buildings = reinforced strands.
- Corruption = twisting silk.
- Mentorship = layered weaving.

Anansi is present through tone, not exposition.

---

## 11.3 Intel — “Listening to the Spider”

Rumors are uncertain threads.

Omens are clearer strands.

Neither are absolute truth.

This preserves uncertainty while maintaining determinism.

---

## 11.4 Bonds — “Threads Between Souls”

Relationships are literal strands in the web.

When one Echo falls, the tension spreads.

---

## 11.5 Vows — “Declaring Pattern in Chaos”

Vows are the Keeper’s attempt to impose structure.

Anansi tests them.

Breaking a vow is not punishment — it is a revealed weakness in the weave.

---

## 11.6 Narrative Guardrail

- Do not over-explain Anansi.
- Do not add heavy lore systems yet.
- Use logs, UI phrasing, and event tone to imply presence.

The myth should be felt through systems, not delivered through exposition.

---

**End of Phase 1 Extension.**