# Continuity Visual Design — Household Fire (Continuity Flame)

> Design decision record for the Continuity Flame visual system.
> V2-CONTINUITY-001. See also: `docs/integration-map.md` for story status.

---

## Cultural Grounding

In Akan spiritual practice the household fire is the living record of the lineage — you keep the fire burning as you keep the lineage burning. The Continuity Flame represents what the house has *kept*, not what it is spending today.

It is distinct from the Ase Flame (the active economy marker in the Sanctum grid — bright, active, what you spend). The Continuity Flame is ember-toned, deep, and settles as the house matures.

---

## What Was Considered and Rejected

| Option | Reason for Rejection |
|--------|---------------------|
| Adinkra symbols | Ruled out — being reserved for a more specific purpose elsewhere in the game |
| Kente cloth strip | Ruled out — too decorative, doesn't carry the right temporal/relational meaning |
| Text labels with numbers | Ruled out — Continuity is never shown as a raw number to the player |

---

## The Six Band Characters

Each band has a flame *quality*, not a power level.

| Band | Threshold | Flame Quality |
|------|-----------|---------------|
| **Awakening** | 0 pts | Fragile, flickering, uncertain — the fire has just been lit |
| **Habit** | 5 pts | Steadier ember, visible routine forming — the fire is being tended |
| **Role** | 15 pts | Warm and purposeful — the fire has a keeper |
| **Governance** | 30 pts | Complex, multi-layered warmth — the fire knows its house |
| **Differentiation** | 50 pts | Distinctly coloured by the house's dominant character — this fire is not like others |
| **Cultural Maturity** | 75 pts | Deep, ancient, settled — the fire has outlasted many things |

Config-driven from `balance.json → data.continuity.bands`.

---

## Intra-Band Progression

Within each band the flame subtly brightens and steadies. Driven by `set_settled(t: float)` where:
- `t = 0.0` — newly entered the band
- `t = 1.0` — near the next threshold

No number is shown. The player reads the fire the same way they read a real fire.

---

## Display Placement

- Inline in TitleRow beside the Sanctum name label
- Minimum touch target: 20×24px
- **Hidden entirely when `continuity_points == 0`** — a brand-new house has no fire yet

---

## Implementation

**Control:** `ContinuityFlameControl` at `ui/screens/sanctum/ContinuityFlameControl.gd`

**API:**
- `set_band(band: String) -> void` — accepts a band name string (e.g. `"awakening"`, `"habit"`, etc.)
- `set_settled(t: float) -> void` — drives intra-band brightness/steadiness (0.0–1.0)

**Rendering:** White-base rendering + `modulate` Tween drives both the procedural triangle placeholder and future texture assets.

**Asset convention:** Drop `res://ui/assets/continuity/flame_{band}.png` — auto-activates with zero code change.

**Animation:**
| State | Cycle Duration | Brightness Swing |
|-------|---------------|-----------------|
| Unsettled (t near 0) | 0.3s | ±30% |
| Settled (t near 1) | 1.2s | ±6% |

---

## Band Transition Moment

When the house crosses a band boundary, a full-screen ceremonial moment fires (similar to vow pledge). This is planned for **V2-CONTINUITY-003** — not yet implemented.

---

## Key Distinction: Continuity Flame vs. Ase Flame

| | Ase Flame | Continuity Flame |
|---|---|---|
| **Meaning** | What you spend today | What you have kept across time |
| **Visual register** | Bright, active, spatial | Ember-toned, settling, inline |
| **Location** | Sanctum spatial grid at (0,0) | TitleRow beside Sanctum name |
| **Driven by** | Ase economy (EconomyService) | ContinuityService |
| **Shown when** | Always (once awakened) | Hidden when continuity_points == 0 |

Two distinct visual registers. Two distinct meanings. They must never be confused in implementation or display.

---

## Continuity Drivers

| Event | Delta | Notes |
|-------|-------|-------|
| Thread accept (Weaving Rite) | +5 | Primary growth driver |
| Thread reject | Escalating per echo | Capped; penalises repeated rejection by the same echo |
| Vow break | −3 | Costs continuity when the house breaks its word |

Save keys: `sanctum.continuity` (int, default 0), `sanctum.rejection_counts` (Dict keyed by echo_id, default {}).

---

## Gating

`InstitutionService.get_snapshot_data()` adds `blocker_reason: String` to each institution entry when continuity is below threshold. This is the mechanism by which Continuity gates institution access — no other gating exists at this layer.
