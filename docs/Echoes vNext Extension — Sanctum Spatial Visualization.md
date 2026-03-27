# Echoes vNext Extension — Sanctum Spatial Visualization

**Document Type:** Visual Systems Extension (vNext)

**Scope:** Sanctum Simulation Rendering Layer

**Status:** MVP Planning

**Audience:** Developers, Designers, Technical Artists, UX Designers

---

# 1. Purpose of This Document

This document defines the **visual simulation layer** for Sanctum in Echoes vNext.

It clarifies:
- What the spatial layer is responsible for
- What it is NOT responsible for
- What ships in MVP
- What is planned post-MVP
- Technical and artistic expectations
- Integration rules with the deterministic simulation

This document extends the core vNext architecture. It does not modify it.

---

# 2. Core Philosophy

Echoes remains:
- Deterministic
- State-first
- Snapshot-driven
- UI-driven for interaction

The spatial layer exists to:
- Increase emotional connection
- Make consequences visible
- Embody cultural identity
- Support immersion without adding control

Spatial = **Visualization of state**

UI = **Interaction with state**

The spatial layer must never mutate simulation logic.

---

# 3. MVP Scope — Sanctum Spatial Layer

## 3.1 Perspective & Camera

- True 2D Isometric (diamond grid)
- Clean vector-based placeholder aesthetic
- No full 3D for MVP

Camera:
- Pan enabled
- Two discrete zoom levels:
- Near (detail)
- Far (management overview)
- Designed mobile-first

Zoom design:
- PC: key or wheel step
- Mobile: prepared for pinch (not required at launch)

Target View Density:
- ~10 tiles visible across at default zoom
- Tile size will be determined after lab testing (32×16, 64×32, 128×64 prototypes required)

---

## 3.2 Grid Philosophy

Sanctum Grid:
- Mostly hidden (art-forward floor)
- Semi-visible structure through subtle seams
- Debug toggle reveals full grid

Realms / Battles:
- Grid may be more visible for clarity

Touch Targets:
- Generous
- Selection outlines required
- Mobile accuracy prioritized

---

## 3.3 Sanctum Layout (MVP)

MVP Structure:
- Single large zone
- Pre-set building positions

Future Structure:
- Multiple floating zones
- Connected by Anansi webs
- Unlockable over time

Core MVP Landmarks:
- Ritual Circle
- Old Great Tree
- Great Hall (Realm entry)
- Market Stalls
- Ashanti King Hall

---

## 3.4 Echo Visibility Rules (MVP)

Max visible Echoes: ~20

Priority Order:
1. Main party (always visible)
2. Pending bark / recent bark
3. Extreme emotions (morale/fear)
4. Pending events (Calling, bond/rivalry, other state flags)
5. Ambient fillers

Echoes assigned to buildings:
- May disappear into building visuals
- Always accessible via panel

---

## 3.5 Movement Model (Hybrid)

Simulation:
- Step-based logic

Visual:
- Smooth tween between tiles

Pathing (MVP):
- Manhattan movement
- No A* required

Roaming:
- Cosmetic idle roaming allowed
- Action-triggered movement overrides roaming

Movement must never drive logic.

---

## 3.6 Interaction Model

Spatial interaction is read-only.

Allowed:
- Click Echo → open detail panel
- Click Building → open building panel

Not allowed:
- Clicking ground to issue commands
- Free spatial manipulation

All actions remain panel-driven.

---

## 3.7 “Alive” Signals (MVP)

Required:
- Walking animations
- Bark/shout labels
- Casual cosmetic conversations
- Emotion indicators (icon/text)
- Ambient glow lighting
- Static Anansi webs between areas

Conversations:
- MVP cosmetic only
- Future: relationship-driven

---

# 4. Post-MVP Expansion

## 4.1 Multi-Zone Sanctum

- Floating layered islands
- Web connectors as navigable VFX
- Z-depth layering

## 4.2 Advanced Movement

- Obstacle avoidance
- Context-aware gathering
- Building congestion handling

## 4.3 Relationship Visualization

- Bond-driven clustering
- Rival separation
- Conversation chains players can follow

## 4.4 Atmosphere Upgrade

- Light2D torch systems
- Glow shaders
- Subtle particle systems
- Reactive webs

---

# 5. Technical Architecture Expectations

## 5.1 Renderer Responsibilities

Renderer MAY:
- Spawn visuals
- Animate movement
- Display labels and debug overlays

Renderer MUST NOT:
- Modify hero data
- Compute simulation outcomes
- Store persistent gameplay state

## 5.2 Renderer Input Contract (MVP Minimum)

SanctumSpatialRenderer receives:

```
{
  echoes: [
    { id, name, emotion_flags, event_flags }
  ],
  buildings: [
    { id, name, grid_pos }
  ]
}
```

Renderer prioritizes visibility based on rules defined above.

---

# 6. Art Direction Summary

Tone Blend:
- Slight Diablo grit
- Wakanda architectural inspiration
- Akan / Ashanti symbolism
- Diaspora returning to mother culture
- Lighthearted but grounded

Color & Materials:
- Red sand floors
- Red clay buildings
- Warm torchlight glow
- Green + yellow accent tones
- Nostalgic West African memory feel

Iconography:
- Symbols primarily on buildings
- Select UI overlays
- Not heavy on tile repetition

---

# 7. Performance & Platform

Platforms:
- PC/Mac first
- Mobile ultimate target

Constraints:
- ~20 Echoes visible max
- Two zoom levels
- No heavy real-time simulation overhead
- Efficient label handling

---

# 8. Development Phasing

Phase A — Spatial Lab (Separate project)
- Test tile sizes
- Test zoom levels
- Test depth sorting
- Validate mobile readability

Phase B — Renderer Contract
- Implement read-only SanctumSpatialRenderer

Phase C — Sanctum Integration
- TileMap added to Sanctum
- Placeholder buildings
- Party Echo rendering

Phase D — Alive Layer
- Movement triggers
- Bark system
- Cosmetic roaming

Phase E — Buildings Fully Spatial
- Assignment movement
- Building interaction visuals

---

# 9. Guardrails

- Spatial must never delay core SANCTUM logic work.
- Maintain 70/30 rule (Core / Spatial time).
- If simulation changes are required, backend first.
- Keep MVP small; expand after core loop is stable.

---

# 10. Definition of Done (Spatial MVP)

Spatial MVP is complete when:

- Sanctum renders in isometric view
- Placeholder buildings are visible and clickable
- Party Echoes are visible and clickable
- Echoes tween between tiles when triggered
- Barks appear above Echoes
- Two zoom levels function
- Debug overlay works
- No gameplay logic moved into visuals

---

---

# 11. Data Flow & Architecture Diagram

This section clarifies how simulation, snapshots, renderer, and UI interact.

The Sanctum Spatial Layer is a **pure consumer of state**.

## 11.1 High-Level Flow

```
┌────────────────────────────┐
│   Core Simulation Layer    │
│  (State Machines / Logic)  │
└──────────────┬─────────────┘
               │
               ▼
┌────────────────────────────┐
│       Snapshot Builder     │
│ (SanctumSnapshot creation) │
└──────────────┬─────────────┘
               │
               ▼
┌────────────────────────────┐
│  SanctumSpatialRenderer    │
│ (Read-Only Visualization)  │
└───────┬───────────┬────────┘
        │           │
        ▼           ▼
┌─────────────┐   ┌─────────────┐
│  TileMap    │   │  UI Panels  │
│  Actors     │   │ (Inspector) │
│  VFX Layer  │   │             │
└─────────────┘   └─────────────┘
```

Key rule:

- Simulation never reads from renderer.
- Renderer never mutates simulation.
- UI panels dispatch actions to simulation.
- Renderer reacts only to updated snapshots.

---

## 11.2 Event Cycle Example (Echo Assigned to Building)

```
1. Player clicks building panel
2. UI dispatches "assign_echo" action
3. Simulation validates + updates state
4. New SanctumSnapshot generated
5. Renderer receives updated snapshot
6. Renderer animates Echo moving to building tile
7. Echo optionally hidden (inside building)
```

Notice:
- Movement is a visual consequence of state change.
- The animation does not cause the assignment.

---

## 11.3 Zoom Handling (MVP)

Zoom is visual-only and does not alter simulation.

```
Zoom Level State (Visual Only)
   ├─ Near  → Detailed view
   └─ Far   → Management overview
```

Zoom must not:
- Change tile logic
- Affect movement speed
- Influence actor state

---

## 11.4 Debug Overlay Layer

Debug overlay is layered above renderer but below UI panels.

```
Simulation
   ↓
Snapshot
   ↓
Renderer
   ↓
Debug Overlay (toggle)
   ↓
UI Panels
```

Debug overlay can display:
- Grid coordinates
- Actor IDs
- Intent labels
- State names
- Morale/Fear values
- Target lines

Debug overlay is developer-facing only.

---

## 11.5 Future Multi-Zone Extension Concept

For floating Sanctum zones:

```
Zone A (TileMap Layer 1)
     │
     │  (Static Web Connector)
     ▼
Zone B (TileMap Layer 2)
```

Each zone:
- Has its own grid bounds
- Shares the same simulation snapshot
- Is rendered within the same SpatialRenderer instance

Navigation between zones remains panel-driven in MVP.

---

---

# 12. Visual State Checklist (QA / Design Validation)

This checklist ensures the spatial layer correctly reflects simulation state and meets MVP expectations.

## 12.1 Structural Validation

- [ ]  Isometric TileMap renders correctly (no depth sorting artifacts)
- [ ]  Default view shows ~10 tiles across (at default zoom)
- [ ]  Two discrete zoom levels function (Near / Far)
- [ ]  Panning works smoothly (no camera jitter)
- [ ]  Semi-visible grid does not feel board-like
- [ ]  Debug toggle reveals full grid clearly

## 12.2 Echo Rendering Validation

- [ ]  Main party Echoes always visible
- [ ]  Max ~20 Echoes visible at once
- [ ]  Visibility prioritization follows defined order:
    - [ ]  Main party
    - [ ]  Pending/recent bark
    - [ ]  Extreme emotions
    - [ ]  Pending events
    - [ ]  Ambient fill
- [ ]  Assigned-to-building Echo visibility matches design:
    - [ ]  If configured to hide: Echo disappears into building
    - [ ]  If configured to show: Echo idles near/at building
- [ ]  Echo remains accessible via panel even if hidden

## 12.3 Movement Validation

- [ ]  Movement is step-based in logic, smooth in visuals (hybrid)
- [ ]  No animation drives state changes (visual-only)
- [ ]  Roaming is cosmetic only
- [ ]  Action-triggered movement overrides roaming
- [ ]  Movement remains readable at both zoom levels

## 12.4 Interaction Validation

- [ ]  Clicking Echo opens correct detail panel
- [ ]  Clicking Building opens correct building panel
- [ ]  No ground-click command behavior exists (MVP)
- [ ]  Touch targets feel generous on mobile-sized viewport
- [ ]  Selection outline/feedback clearly indicates what is selected

## 12.5 Emotional & “Alive” Signals

- [ ]  Bark text appears above Echo
- [ ]  Bark auto-fades correctly
- [ ]  Recent bark/pending bark affects visibility priority as intended
- [ ]  Emotion indicators reflect snapshot state (label/icon)
- [ ]  Casual conversations appear occasionally (cosmetic)
- [ ]  Ambient glow present (torchlight memory tone)
- [ ]  Static Anansi webs visible in MVP (background element)

## 12.6 Debug Overlay Validation

- [ ]  Grid coordinates toggle
- [ ]  Actor ID toggle
- [ ]  Intent label toggle
- [ ]  Current state name toggle
- [ ]  Morale/Fear numeric toggle
- [ ]  Target line toggle (stub acceptable in MVP)

## 12.7 Performance Validation

- [ ]  Stable performance with ~20 visible Echoes
- [ ]  No excessive label overlap at Far zoom (or auto-hide rules exist)
- [ ]  Mobile viewport simulation remains readable

---

# 13. MVP Completion Criteria

Spatial MVP is considered complete when:

- All Visual State Checklist items pass.
- No simulation logic has migrated into the renderer.
- Two zoom levels function predictably.
- Sanctum feels inhabited without adding gameplay complexity.
- Spatial layer integrates without slowing core SANCTUM development.

---

# **14. Implementation Phases & Backlog Alignment**

This section maps the spatial work to practical implementation phases and SANCTUM story progression.

The goal is to ensure spatial development enhances — not blocks — core system development.

---

## **Phase A — Spatial Lab (Separate Project)**

**Purpose:** Learn and validate isometric rendering fundamentals safely.

Deliverables:

- Test 32×16, 64×32, 128×64 tile sizes
- Validate ~10 tiles visible across target
- Implement two zoom levels (Near / Far)
- Confirm depth sorting works
- Validate mobile viewport readability

No integration with Echoes repo.

---

## **Phase B — Renderer Contract (Echoes Repo)**

**Purpose:** Introduce read-only SanctumSpatialRenderer.

Deliverables:

- Define minimal renderer input contract
- Implement echo prioritization logic
- No logic mutation allowed

Aligned with: Post SANCTUM-002

---

## **Phase C — Sanctum Spatial Integration**

**Purpose:** Embed TileMap into Sanctum screen.

Deliverables:

- Semi-visible floor
- Placeholder buildings at fixed positions
- Party Echo rendering
- Click-to-inspect wiring

Aligned with: Early building stories (SANCTUM-003 / 004)

---

## **Phase D — Movement & Alive Layer**

**Purpose:** Make Sanctum feel inhabited.

Deliverables:

- Assignment-triggered movement
- Cosmetic roaming
- Bark system
- Emotion indicators
- Ambient glow
- Static Anansi webs

Aligned with: Job assignment & Sanctum tick stories

---

## **Phase E — Buildings Fully Spatial**

**Purpose:** Buildings gain meaningful presence.

Deliverables:

- Echo enters/exits buildings visually
- Building interaction highlights
- Improved prioritization of visible Echoes

Aligned with: SANCTUM job systems stabilization

---

## **Phase F — Multi-Zone Expansion (Post-MVP)**

**Purpose:** Expand Sanctum into floating layered zones.

Deliverables:

- Multiple TileMap layers
- Web connectors
- Z-depth layering
- Possible navigable zone transitions

Aligned with: Post-MVP expansion roadmap

---

## **Development Rhythm Rule**

- 70% time → Core SANCTUM systems
- 30% time → Spatial improvements

If spatial work delays core logic → pause spatial work.

---