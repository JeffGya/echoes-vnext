# UI/UX Reference — Echoes vNext

> Landscape-first responsive UI/UX patterns for Echoes vNext on Godot 4.6.1.
> Authoritative knowledge of snapshot-to-screen mapping, safe areas, persistent
> chrome, modal layering, touch targets, screen inventory, Living Tree visual
> language, and interaction patterns.

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

1. **Landscape-first across phone, tablet, and desktop.** Base 1280×720; compact still keeps 48×48 targets.
2. **Responsive means recomposition.** Cap readable UI, change columns/wrap/visibility by profile, and give wide-screen surplus to spatial presentation.
3. **Living Tree / West African aesthetic.** Adinkra-inspired iconography, earthy warm palette, weight and texture over gradients.
4. **Snapshot fidelity.** The UI is a pure renderer — it displays what the snapshot says, nothing more.
5. **Clarity over density.** Player should always know where they are, what they can do, and what matters.
6. **Emotional resonance.** Emotional state should feel real through shared named states and Living Tree treatments, not raw numbers.

---

## Touch Target Standards

- **Minimum:** 48×48dp for all interactive elements
- **Preferred:** 56×56dp for primary CTAs
- **Spacing:** at least 8dp between adjacent touch targets
- **Safe zones:** at least 16 logical units or the converted OS safe inset, whichever is larger
- **Bottom exclusion:** safe bottom + shell chrome height + 8-unit separation

---

## Responsive Profiles

| Profile | Safe logical condition | Composition |
|---|---|---|
| Compact | width <1200 or height <680 | One primary column where needed; secondary information reflows, overlays, or uses bounded detail/list scrolling |
| Standard | below 1440×810 | Spatial-first layout with capped supporting panels |
| Wide | at least 1440×810 | UI remains capped; surplus expands Sanctum, exploration, and combat space |

- Desktop UI scale cap: 1.25.
- Phone landscape target: about 960×540 logical, cap 2.0.
- Tablet/foldable target: about 1280×720 logical, cap 1.5.
- Do not uniformly scale individual scene roots.
- Do not add scroll containers to every main screen. Use them for genuinely long
  lists, detail pages, or modal bodies after the primary layout is recomposed.
- Autowrap labels that affect geometry need an authored/profile wrap width before
  the first layout pass.

---

## Screen Inventory

### Sanctum Family (SanctumShell)
Shell owns the persistent inset/capped BottomRail. Screens do NOT render their own nav.

| Screen | Flow State | Purpose |
|--------|-----------|---------|
| SanctumScreen | `flow.sanctum` | Spatial-first hub: title/vow/guidance, Ase/Ekwan, departure party, Thread reserve, Echo detail and institutions |
| SummonScreen | `flow.summon` | Grade/count selection + summon action |
| EchoPartyScreen | `flow.echo_party` | Roster detail, party toggles, progression, bonds, skills |
| RealmSelectScreen | `flow.realm_select` | Realm cards + runtime locks |
| VowScreen | `flow.vow_manage` | Vow selection, pledge, break |
| WeavingRiteScreen | `flow.weaving_rite` | Thread/Echo rite selection and resolution |

### Venture Family (RealmShell)
Shell owns the persistent inset/capped EchoBar. Individual screens reserve its
bottom exclusion and do not render their own party bar.

| Screen | Flow State | Purpose |
|--------|-----------|---------|
| StageMapScreen | `flow.stage_map` | Stage progress list and party prep |
| StageExploreScreen | `flow.stage` / `flow.stage_explore` | Stage preview plus exploration flow — keep prep UI on StageMap |
| CombatBoardScreen | `flow.encounter` / `flow.keeper_trial` | Responsive isometric board, objective, initiative, pace and camera controls |
| ResolveScreen | `flow.resolve` | AppRoot modal outcome surface: combat/scout/contact/situation resolution |

---

## Snapshot-to-Screen Mapping

Every screen reads a snapshot of shape `{ type, meta, data, actions }`:

| Snapshot type | Screen rendered |
|--------------|----------------|
| `flow.sanctum` | SanctumScreen |
| `flow.summon` | SummonScreen |
| `flow.echo_party` | EchoPartyScreen |
| `flow.realm_select` | RealmSelectScreen |
| `flow.vow_manage` | VowScreen |
| `flow.weaving_rite` | WeavingRiteScreen |
| `flow.stage_map` | StageMapScreen |
| `flow.stage` | StageExploreScreen (preview mode) |
| `flow.stage_explore` | StageExploreScreen (explore mode) |
| `flow.encounter` / `flow.keeper_trial` | CombatBoardScreen |
| `flow.resolve` | ResolveScreen through AppRoot ModalHost |

Routing logic lives in `AppRoot.gd` (shell selection) then `SanctumShell.gd` or `RealmShell.gd` (screen selection).

---

## Displaying Emotion & Morale

- Read the projected `emotional_status` field only.
- Player-facing statuses: radiant, whole, grounded, uncertain, hesitant, burdened,
  pressed, strained, fraying, hollow.
- Use `EmotionPresentation.gd` and `LivingTreeSystem.tres`; do not build local emotion palettes.
- Raw morale/fear and internal morale tiers are simulation data, not UI fields.
- Operational outcomes such as KO/refusal may still appear when the snapshot exposes them.

---

## Displaying Progression

- Show **Standing** (not rank) and **Step** (not level) in all player-facing contexts
- Calling displayed by name (Ward / Break / Veil / Path / Rite / Root), not ID
- Virtue domain (dominant_vector) shown as the echo's current identity — not a stat bar
- Maturity band (nascent / forming / grounded / whole) can inform visual presence/weight

---

## Key UI Rules

- **Build structure in `.tscn`, not `.gd`.** Scripts only set values: `text`, `modulate`, `visible`, `disabled`.
- Responsive scripts may set profile values such as `columns`, margins, visibility,
  wrap widths, and min/max sizes; do not create or reparent UI structure in code.
- **Shell-cached nav pattern:** SanctumShell owns the BottomRail via `_cached_nav`. Do not inject nav into snapshots.
- **Realm chrome pattern:** RealmShell owns the 88-unit EchoBar. Screens reserve it.
- **Spatial-first pattern:** capped cards and controls stop growing on wide views;
  the Sanctum/exploration/combat field gets the additional real estate.
- **Sanctum overview pattern:** `OverviewFlow` authors `TopBand` followed by
  `OverviewBody`; header metadata reflows beside guidance. Do not add primary
  overview scroll panes to solve header/party/thread geometry.
- **Stage Explore pattern:** capped Living Tree Turn/Objectives/Party HUD with
  directive badge in the same top row; Step/actions live above EchoBar exclusion.
- **No IDs in player-facing display.** Show names, standings, callings — never internal ID strings.
- **Per-row actions** are dispatched by the row itself, never put in `snapshot.actions`.

---

## Layering and Blocking Modals

| Layer | Use |
|---:|---|
| 0 | World/spatial presentation |
| 10 | Active screen content |
| 20 | Persistent BottomRail/EchoBar/navigation |
| 30 | Non-modal barks, transitions, placement controls, notifications |
| 40 | AppRoot blocking ModalHost |
| 128 | Recovery/debug/emergency |

- A blocking modal root covers the whole viewport, including persistent chrome and cutouts.
- The decorative dim backdrop ignores input; the full modal input root stops it.
- Only one blocking modal is active. Multi-step dialogs change authored substates.
- Modal cards stay within logical safe insets; long bodies may scroll while required CTAs remain reachable.
- Opening a modal records focus, moves focus inside, contains it, and restores it on close.
- Realm modal surfaces: Resolve, directive, prebattle, engagement, contact/conversation,
  situation, and return-home.
- Sanctum modal surfaces: summon reveal, Awakening, Companion invitation, Rank Up/
  Calling, Calling information, institution detail, and vow pledge/break moments.
- Shell-owned CanvasLayers must follow inherited visibility; a hidden shell must not
  draw or intercept input over the active shell.

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
- `ui/components/ResponsiveLayoutController.gd` — layout/profile/safe-area calculation
- `ui/components/ModalHost.gd` — app-wide blocking modal ownership
- `ui/shells/SanctumShell.gd` — sanctum shell with cached nav
- `ui/shells/RealmShell.gd` — realm shell routing
- `CONVENTIONS.md` — responsive, layer, modal, and UI-only interface contracts
