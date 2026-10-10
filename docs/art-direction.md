# Echoes of the Sankofa — Art Direction Reference

> **Source of truth for all visual and UX decisions in the project.**
> Sourced from the Art Direction Bible v2 and confirmed by Jeff (Gyamfi).
> All decisions documented here are locked unless explicitly revised.
> For game design decisions (lore, systems, balance), see the Working GDD.

---

## Design Pillars (UI Expression)

| Design Pillar | UI/UX Translation |
|---|---|
| **Guidance over Control** | Surface information, not levers. Show what Echoes feel; hide complexity. |
| **Legacy over Grind** | Every screen should feel like it matters. No filler screens. No disposable UI. |
| **Autonomous Companions** | Echoes have visible personality. Stats are secondary to character expression. |

---

## Tone

Reverent, warm, ancient-modern. The UI should feel like a sacred ledger — deliberate marks, not noise. No flashy effects. No clinical minimalism. Surfaces carry meaning.

---

## Platform & Touch Rules

- **Minimum touch target:** 48×48 logical units
- **Safe zones:** top 64px (notch/status), bottom 64px (home indicator)
- **One-thumb reach zone:** bottom 60% of screen is comfortable
- **No hover states** — all interactions must work with tap only
- **Portrait-first** layout; landscape optional for combat grid
- Desktop minimum window: 1280×720; scale gracefully to 1920×1080

---

## Typography

| Role | Font | Size |
|---|---|---|
| Display / titles | Madimi One | 22–32sp |
| Body / labels | Iosevka Charon (mono) | 14–16sp |
| Micro / legends | Micro | 12sp |

---

## Core Palette (Global)

Sourced from Art Direction Bible v2 (global swatches, not virtue-specific):

| Name | Hex |
|---|---|
| Akan Gold | `#D4AF37` |
| Deep Forest | `#3D5A47` |
| Terracotta | `#C85A54` |
| Ivory | `#F5F0E8` |
| Shadow Charcoal | `#2A2A3A` |

---

## Echo Identity — Story-Colour Settlement

Story-colour is a physical replacement for part of an Echo's skin, not paint, clothing dye, a wound, transparency, or missing anatomy. An Echo remains physically whole and opaque at every state.

Two visual signals must remain independent:

- **Patch coverage and loose-thread count** show how settled the Echo's story is.
- **Patch hue** shows the Echo's current mood and may shift without changing patch shape or coverage.

At any one moment, an Echo's story-colour uses one solid hue. Patches may be non-contiguous, but they must remain clean, flat areas of colour against natural brown skin. Clothing, equipment, and hair never inherit story-colour.

| Visual state | Story-colour coverage | Loose Threads | Read |
|---|---:|---|---|
| **Unsettled** | At least `1/3`, up to `1/2` of the skin | Many; every colour-to-skin boundary visibly comes undone | A physically whole Echo whose identity is still substantially unresolved |
| **Weaving / developing** | About `1/4` to `1/3` | Fewer; present around every remaining unsettled boundary | Lived stories and Weavings are reducing and stabilizing the unresolved area |
| **Settled** | About `1/8` to at most `1/4` | Minimal to none | A small, stable colour patch remains as part of the Echo's visible history |
| **Mythical** | `0` | None | A rare older Echo whose story has fully settled under separate, specific ascension rules |

Mythical is not an automatic high-Standing costume upgrade. Mythical Echoes sit toward the older end of the approved young-adult-to-early-senior range, remain grounded and recognizably human, and do not need halos, fantasy anatomy, armor, or spectacle to communicate rarity.

---

## Environment Stylization — Shape Before Surface

Environment art must be stylized in its underlying geometry, proportions, perspective, and silhouettes. Painterly texture over realistically proportioned buildings, trees, or terrain does not meet the project style.

- **Architecture:** Start from documented Ghanaian material and construction logic, then simplify it into squat or compressed structures, oversized roof masses, narrow openings, gently bowed rooflines, tapered wall planes, and visibly hand-shaped asymmetry. Use a few thick structural pieces rather than realistic construction density.
- **Trees:** Build trunks and branches as strong calligraphic curves, roots as broad readable sweeps, and crowns as a small number of large overlapping foliage masses. Avoid botanical anatomy, thousands of individual leaves, and realistic branching density.
- **Objects and terrain:** Favor chunky, slightly top-heavy silhouettes, broad surface patches, oversized functional forms, and sparse graphic plant fans over realistic scale, micro-rubble, or incidental texture.
- **World depth:** Compress scenes into a few designed layers. Floating plateaus should have clear flat tops, tapered hanging silhouettes, simplified vegetation, and rhythmic web arcs rather than realistic geology and atmospheric perspective.
- **Perspective:** A slightly theatrical or gently impossible perspective is acceptable when it improves clarity, rhythm, and emotional staging. Concept art does not need to imitate the game's isometric presentation.
- **Finish:** Dark-brown contours, matte gouache-like blocks, limited value planes, and paper or woven grain support the style, but they cannot substitute for exaggerated shape design.

The target is an adult illustrated folktale: reverent and grounded, but visibly authored rather than photographed or reconstructed.

### Dormant starting Sanctum

The starting Sanctum is dormant, not broken or ruined. Its structures, sacred tree, vessels, work shelter, and communal hearth remain whole and usable.

- Use closed or resting openings, stored tools, covered work surfaces, settled dust, still air, sparse edge growth, and absence of activity to communicate sleep.
- The Ase hearth is intact and deliberately placed, but completely cold: no flame, ember, smoke, glow, spark, or recent-burn cue.
- Age may appear through faded surfaces, subtle staining, hand-shaped irregularity, and quiet maintenance needs, but not through collapsed roofs, missing walls, exposed structural failure, rubble, shattered objects, or dead vegetation.
- The intended player read is `waiting to wake`, not `waiting to be rebuilt`.

---

## Rarity Colors

| Rarity | Hex |
|---|---|
| Common | `#A8865A` |
| Uncommon | `#4CAF72` |
| Rare | `#7AB5C8` |
| Legendary | `#C8826E` → `#D4AF37` (gradient) |

---

## Virtue × Realm Palette

**5 colors per realm, confirmed from Art Direction Bible v2.**

| # | Role | Use |
|---|---|---|
| 1 | **Clean** | "Clean" quality tier fill; disc center gradient start |
| 2 | **Compromised** | "Compromised" quality tier fill |
| 3 | **Broken** | "Broken" quality tier fill |
| 4 | **Glow / Border** | Ring/border color for all quality tiers; gradient outer edge |
| 5 | **Shadow** | Empty slot fill or disc shadow |

| Virtue | Realm | Clean (1) | Compromised (2) | Broken (3) | Glow/Border (4) | Shadow (5) |
|---|---|---|---|---|---|---|
| Courage | Vale of Dust | `#E8D5B0` | `#C8A55A` | `#A67848` | `#6B5A4A` | `#2A1E14` |
| Wisdom | Shrouded Grove | `#E8EDE8` | `#B0B8B0` | `#A0B8C0` | `#8BA888` | `#3A5A44` |
| Leadership | Crimson Plains | `#E8D8C8` | `#E86830` | `#B83028` | `#8A7870` | `#2A1818` |
| Acceptance | Hollow River | `#78A0B0` | `#C8D8E0` | `#3A4A58` | `#5A7060` | `#8AB0C0` |
| Humility | Glimmering Spire | `#F8F4E8` | `#F0D060` | `#D0E0F0` | `#C8D0D8` | `#181828` |
| Forgiveness | Twilight Fields | `#C08890` | `#908090` | `#607890` | `#7860A0` | `#C89840` |
| Truth | The Forgotten Sky | `#E0A8A0` | `#F0F4F8` | `#4878B8` | `#D0B858` | `#1A2040` |
| Generosity | Obsidian Reef | `#E8E0D8` | `#E06848` | `#A87830` | `#286888` | `#181820` |
| Compassion | Ashen Peaks | `#E8F0F0` | `#A0C0D0` | `#909090` | `#E88030` | `#281818` |
| Empathy | Ivory Tundra | `#F8F8FC` | `#D8ECF4` | `#90B8C8` | `#506878` | `#283848` |

---

## Thread Quality Tier System

### Definitions

| Tier | Implementation label | Player-facing label | GDD source |
|---|---|---|---|
| Clean | `"clean"` | Strong | §14.3 (implementation term) |
| Compromised | `"compromised"` | Compromised | §14.3 (implementation term) |
| Broken | `"broken"` | Weak | §14.3 (GDD-sourced) |

> Note: "clean" and "compromised" are implementation labels. Only "broken" appears in the GDD directly.

### Grade → Quality Tier Mapping (§14.3)

| Combat Grade | Quality Tier |
|---|---|
| S | `"clean"` |
| A | `"clean"` |
| B | `"compromised"` |
| C | `"compromised"` |
| D | `"compromised"` |
| F | `"broken"` |

### Weighted Quality Float (crystallization)

| Tier | Weight |
|---|---|
| `"clean"` | 1.0 |
| `"compromised"` | 0.5 |
| `"broken"` | 0.1 |

### Thread Count Thresholds (§14.4)

| Quality Float | Threads Produced |
|---|---|
| ≥ 0.75 | 3 |
| ≥ 0.40 | 2 |
| ≥ 0.00 | 1 |

**GDD §14.4 guarantee:** every completed Realm produces at least 1 Thread. Code enforces `max(1, _resolve_count())`.

---

## ThreadSlotItem — Circular Sigil Disc

Used in the Sanctum's Thread Reserve Strip.

- **Size:** 48×48 logical units (meets the touch target)
- **Shape:** Circle; no rectangular border
- **Rendering:** `_draw()` via layered `draw_circle()` calls (12 steps) to approximate a radial gradient
  - Inner (center) = quality tier fill color for that virtue
  - Outer (edge) = virtue's glow/border color (Color 4)
  - Gradient gives a 3D/depth feel
- **Filled state:** Radial gradient disc. Broken tier draws a crack line over the disc.
- **Empty state:** Dim circular border ring only — virtue's glow/border color at 30% opacity, no fill.
- **Tooltip:** `"Virtue — quality_tier"` (e.g. "Courage — clean")
- **Broken tier crack:** `draw_line()` from upper-left to lower-right, 50% black, 1.5px

---

## RealmRecoveryCord — Segmented Recovery Strip

Used in the Stage Map screen between stages.

- **Structure:** VBoxContainer containing a row of cells + a persistent legend row
- **Cell size:** 40px wide × 16px tall per stage
- **Cell count:** one per stage in the active Realm
- **Rendering:** `_draw()` via layered `draw_circle()` calls (8 steps) per cell
  - Uses **active Realm's virtue palette** (virtue passed from snapshot)
- **Quality tier → visual:**
  - `"clean"` → radial gradient using clean color (Color 1)
  - `"compromised"` → radial gradient using compromised color (Color 2)
  - `"broken"` → radial gradient using broken color (Color 3) + crack line drawn over
  - `""` (future/not yet completed) → dim border only using border color (Color 4) at 20% opacity, 40% border stroke
- **Legend (persistent, always visible below cells):**
  - `[●] Strong`  `[≋] Compromised`  `[✕] Weak`
  - Font: Micro 12sp
  - Spacing: 12px between legend items

---

## Adinkra Motif Usage

Adinkra symbols are cultural, not decorative. Rules:
- Only use symbols whose meaning directly relates to the context of use
- Never use Adinkra as generic icons or for visual flair alone
- Sankofa (looking back to move forward) = appropriate for story recovery contexts
- Source: confirmed symbols only — do not invent or adapt

---

## Screen-Level UI Invariants

1. **No spinner on action dispatch** — dispatch is synchronous; snapshot returns immediately
2. **Destructive actions need confirmation** — any action advancing irreversible game state needs a confirm step
3. **Echoes feel alive** — always show emotion state, never just a stat block
4. **Snapshot is truth** — never maintain local UI state that mirrors core state

---

## Component Conventions

- All visual components rendering game data must use `_draw()` for custom graphics (not Texture2D where palette-driven rendering is needed)
- Radial gradients are approximated via layered `draw_circle()` — no native Godot 4 radial gradient API
- Virtue color lookup: `VIRTUE_PALETTE[virtue.to_lower()][quality_tier]` — always `.to_lower()` before lookup
- All new components follow the snapshot-driven read-only contract — no direct state access, no action dispatch (unless explicitly a CTA component)
