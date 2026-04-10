# UI/UX Reference — Echoes vNext

> Mobile-first UI/UX patterns for Echoes vNext. Authoritative knowledge of: snapshot-to-screen mapping, touch target standards, screen inventory, West African aesthetic direction, and interaction patterns.

**Claude Code:** invoke as `/game-ui-ux-echoes` or `anthropic-skills:game-ui-ux-echoes`
**Codex / any agent:** read this file directly — all knowledge is self-contained here.

## When to consult this document
- Designing or implementing a new screen
- Making layout decisions
- Deciding how to display emotion, morale, or progression
- Checking which shell/family a screen belongs to
- Any question about touch targets, spacing, or visual hierarchy

---

## Design Principles

1. **Mobile-first.** All screens designed for portrait phone. Touch targets minimum 48×48dp.
2. **West African aesthetic.** Adinkra-inspired iconography, earthy warm palette, weight and texture over gradients.
3. **Snapshot fidelity.** The UI is a pure renderer — it displays what the snapshot says, nothing more.
4. **Clarity over density.** Player should always know where they are, what they can do, and what matters.
5. **Emotional resonance.** Morale and fear should feel real — not just numbers but visible states.

---

## Touch Target Standards

- **Minimum:** 48×48dp for all interactive elements
- **Preferred:** 56×56dp for primary CTAs
- **Spacing:** at least 8dp between adjacent touch targets
- **Safe zones:** 16dp margin from screen edges

---

## Screen Inventory

### Sanctum Family (SanctumShell)
Shell owns the persistent NavBar. Screens do NOT render their own nav.

| Screen | Flow State | Purpose |
|--------|-----------|---------|
| SanctumScreen | `SANCTUM` | Hub: Ase balance, roster preview, party slots, name modal |
| SummonScreen | `SUMMON` | Grade selection + summon action |
| PartyManageScreen | `PARTY_MANAGE` | Toggle party members, confirm party |
| RealmSelectScreen | `REALM_SELECT` | Realm cards + runtime locks |

### Venture Family (RealmShell)
No shared chrome — each screen is self-contained.

| Screen | Flow State | Purpose |
|--------|-----------|---------|
| StageMapScreen | `STAGE_MAP` | Stage progress list, party prep, future: skill/directive selection |
| StageScreen | `STAGE` | Reserved for future visual stage exploration — do not add prep UI here |
| CombatBoardScreen | `ENCOUNTER` | Isometric TileMap, initiative panel, prebattle panel, party bar |
| ResolveScreen | `RESOLVE` | Victory/defeat, actor roster, continue or next stage |

---

## Snapshot-to-Screen Mapping

Every screen reads a snapshot of shape `{ type, meta, data, actions }`:

| Snapshot type | Screen rendered |
|--------------|----------------|
| `SANCTUM` | SanctumScreen |
| `SUMMON` | SummonScreen |
| `PARTY_MANAGE` | PartyManageScreen (inside SanctumShell) |
| `REALM_SELECT` | RealmSelectScreen |
| `STAGE_MAP` | StageMapScreen |
| `STAGE` | StageScreen |
| `ENCOUNTER` | CombatBoardScreen |
| `RESOLVE` | ResolveScreen |

Routing logic lives in `AppRoot.gd` (shell selection) then `SanctumShell.gd` or `RealmShell.gd` (screen selection).

---

## Displaying Emotion & Morale

- **Morale tiers:** inspired / steady / shaken / broken — use distinct visual states, not just color
- **Fear:** display as a rising threat indicator; at fear ≥ 80 the echo visually refuses
- Emotion state is on the actor dict — read `actor["emotion"]["morale"]` and `actor["emotion"]["fear"]`
- Never show raw numbers to the player — translate to tiers/states

---

## Displaying Progression

- Show **Standing** (not rank) and **Step** (not level) in all player-facing contexts
- Calling displayed by name (Ward / Break / Veil / Path / Rite / Root), not ID
- Virtue domain (dominant_vector) shown as the echo's current identity — not a stat bar
- Maturity band (nascent / forming / grounded / whole) can inform visual presence/weight

---

## Key UI Rules

- **Build structure in `.tscn`, not `.gd`.** Scripts only set values: `text`, `modulate`, `visible`, `disabled`.
- **`ScreenTemplate.gd`** is the canonical starting point for all new bespoke screens.
- **Shell-cached nav pattern:** SanctumShell owns the NavBar via `_cached_nav`. Do not inject nav into snapshots.
- **No IDs in player-facing display.** Show names, standings, callings — never internal ID strings.
- **Per-row actions** are dispatched by the row itself, never put in `snapshot.actions`.

---

## West African Aesthetic Direction

See `docs/art-direction.md` for full direction. Key points:
- Adinkra symbols as iconographic anchors
- Palette: warm ochres, deep browns, forest greens, terracotta
- Typography: weighted, purposeful — legibility over decoration
- Animation: deliberate, weighted — not bouncy or playful
- Sound direction: percussive, organic, grounded

---

## Related Files
- `docs/art-direction.md` — full art direction document
- `docs/DesignSystem_LivingGrove_Complete_Guide.md` — Living Grove design system
- `ui/AppRoot.gd` — shell routing logic
- `ui/shells/SanctumShell.gd` — sanctum shell with cached nav
- `ui/shells/RealmShell.gd` — realm shell routing
- `ui/screens/ScreenTemplate.gd` — canonical screen base
