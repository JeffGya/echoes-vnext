# UI Screen Ledger

This file is the canonical screen-story ledger for the Sanctum UI/UX overhaul and
the cross-shell responsive/layering pass.

## Boundaries

- Visible layers only. No new gameplay systems.
- Landscape only on mobile and desktop.
- Sanctum remains a prototype spatial shell in this pass.
- Responsive work preserves snapshots, actions, simulation, persistence, routing outcomes, copy, and gameplay rules.
- Missing art is handled honestly through mid-fi placeholder framing.
- Reused visual treatments should be added to `assets/theme/LivingTreeSystem.tres` incrementally and reused immediately.
- Skills are not treated as a full loadout system.
- Bonds remain existing functionality only.
- Inventory is absent and should not be implied.
- If engine reality clashes with the screen spec, stop and re-spec with Jeff.

## Screen Order

1. Sanctum Hub
2. Echo Detail
3. Bonds and Skills within Echo Detail
4. Party Management
5. Vows Selection and Management
6. Realm Selection

## Current Progress

- `Responsive/layer/safe-area refactor`: Jeff approved in-game; ready for PR
- `Sanctum Hub`: approved
- `Echo Detail`: existing implementation migrated; dedicated design-story review pending
- `Bonds and Skills`: existing implementation migrated; dedicated design-story review pending
- `Party Management`: existing implementation migrated; dedicated design-story review pending
- `Vows`: existing implementation migrated; dedicated design-story review pending
- `Realm Selection`: existing implementation migrated; dedicated design-story review pending

## Responsive, Layering, and Safe-Area Pass

### Foundation

- Godot 4.6.1, landscape-only, 1280×720 design base.
- Resizable/HiDPI desktop window: 1600×900 initial, 960×540 minimum,
  `canvas_items` + fractional `expand`.
- `ResponsiveLayoutController` emits compact/standard/wide logical layouts and
  converted logical safe insets; desktop/phone/tablet UI scaling stops at its cap.
- AppRoot stays the composition root and owns the full-rect screen host plus one
  layer-40 blocking `ModalHost`.
- Canonical layers: world 0, content 10, persistent chrome 20, transient 30,
  blocking modal 40, recovery/debug 128.
- Persistent BottomRail/EchoBar are safe-inset, bottom-inset, and width-capped.
  Screens reserve their bottom exclusion.
- All blocking modal roots cover the full viewport and chrome, stop underlying
  input, contain focus, and restore prior focus.

### Migrated Gameplay Surfaces

| Family | Surface | Responsive/layer result |
|---|---|---|
| Sanctum | Sanctum overview | Authored `OverviewFlow`: `TopBand` followed by `OverviewBody`; header metadata reflows in two columns; Departure Party and Thread Reserve stay capped around the spatial field; no primary overview scroll pane. |
| Sanctum | Echo Party | Responsive list/detail/party composition with safe bottom exclusion; rank/calling blockers use ModalHost. |
| Sanctum | Summon | Safe capped content; summon confirmation/reveal uses its Living Tree modal through ModalHost. |
| Sanctum | Realm Select | Compact one-column, wider multi-column cards; width and height use available safe space. |
| Sanctum | Vows | Compact one-column and wider two-column composition; pledge/break outcome uses ModalHost. |
| Sanctum | Weaving Rite | Responsive multi-panel grid uses the available width; long rite content remains bounded and reachable. |
| Sanctum | Blocking events | Awakening, Companion invitation, Rank Up/Calling, Calling information, Institution detail, Vow moments, and Summon reveal render above rail/world through ModalHost. |
| Realm | Stage Map | Safe responsive stage/party composition; compact single-column and wider spatial allocation. |
| Realm | Stage preview | Briefing and map refit to safe width and height; preview content does not leave an explore HUD behind. |
| Realm | Stage exploration | Capped Living Tree Turn/Objectives/Party HUD with same-row directive badge; Step/actions remain above EchoBar; board keeps spatial focus and zoom on live resize. |
| Realm | Combat board | Objective, initiative, and controls remain capped while wide layouts expose more board; pan/zoom state is preserved where possible. |
| Realm | Blocking events | Directive, prebattle, engagement, contact/conversation, situation, return-home, and Resolve surfaces use ModalHost above EchoBar. |
| Onboarding | Invocation, Anansi Web, Forgotten Name, First Sanctum Encounter, Sanctum Naming, Keeper Intro | Safe frames, readable wrapping, reachable focus order, and bounded long content without adding Sanctum/Realm chrome. |
| Boot | Save Error | Safe responsive card with long error detail reachable. |

### Interaction and Accessibility Contract

- Minimum target 48×48; primary CTA height 56; at least 8 units between adjacent targets.
- Actionable content keeps at least 16 logical units or the converted OS safe inset,
  whichever is larger.
- UI scale stops at its device cap; wide-screen surplus goes to Sanctum/exploration/
  combat space instead of continuously enlarging controls.
- Scroll containers are reserved for genuinely long lists, detail pages, or modal
  bodies. They are not the default solution for primary Sanctum composition.
- Cross-shell routing disables hidden shell CanvasLayers so Realm EchoBar input cannot
  block the Sanctum rail.

### Manual Signoff and Residual Risks

- Jeff approved the integrated responsive/layering build for PR preparation.
- Standalone/editor-launched OS windows are the source of truth for desktop resizing;
  the embedded Godot game dock follows editor-dock dimensions.
- Physical cutout/home-indicator behavior remains dependent on each platform's
  `DisplayServer.get_display_safe_area()` report; logical conversion is covered by
  automated tests, but new device classes still need a quick real-device check.
- Extremely long future/localized copy can change wrap height. Any new wrapped header
  copy must ship with an authored/profile wrap width and compact/wide regression.
- Debug-panel redesign remains outside this pass.

## Sanctum Hub

### Scope

- Responsive spatial-first Sanctum overlay in landscape.
- Shell-owned bottom action rail.
- Contextual Realm entry truth:
  - `Choose Realm` when no realm is active.
  - `Resume Trial` when a realm is active.
- Persistent hub readout for:
  - Sanctum name
  - Ase flame and Ase balance
  - active party summary
  - thread reserve
  - active vow when present
- Name modal remains supported from the current snapshot contract.

### Non-Scope

- No building entry interactions.
- No free-roam avatar.
- No direct Echo-detail spatial tap until the Echo Detail story ships.
- No new Continuity feature surface.
- No Weaving shortcut that bypasses the current route through Echo management.

### Current Truth

- The Sanctum base is still a prototype shell.
- The spatial view still relies on placeholder floor and placeholder Echo presence.
- Thread reserve, vow state, party summary, and Ase values are all coming from the existing snapshot contract.
- The rail still uses current actions. It does not add new flow actions.

### Empty, Error, and Notification Notes

- Empty party: local message in the party panel.
- Empty thread reserve: local message in the reserve panel.
- No active vow: local message in the doctrine panel.
- Unavailable Weaving: visible but disabled, with local framing kept on the hub rather than a toast.
- Ase delta feedback remains local to the Ase card.

### Rationale

- The hub moved away from the right-dashboard pattern so the spatial Sanctum can read as the main play surface.
- The shell action rail now carries the recurring movement verbs, which keeps the hub quieter and more readable.
- Realm truth is expressed in the rail without core changes by switching between existing `nav.realm_select` and `cta.enter_stage` actions.
- Repeating content uses reusable scene/template rows rather than fixed hardcoded slots.
- Vow state is now folded into the title block instead of occupying a separate empty-state panel.
- The Ase card now labels the resource directly and avoids decorative flame-state copy.
- Party emotion now uses a reusable chip component intended for reuse across later Sanctum screens.

### Implementation Notes

- `ui/shells/SanctumShell.*`
  - Replaced the foldable nav with an authored bottom action rail.
  - Bound the rail to cached Sanctum actions.
  - Realm button now truthfully switches between select/resume behavior.
- `ui/screens/sanctum/SanctumScreen.*`
  - Rebuilt into a spatial-first overlay with reusable party templates.
  - Responsive `OverviewFlow` keeps the title/Ase band above a shared body and leaves
    the middle of the screen to the spatial Sanctum.
  - Primary overview cards reflow without whole-screen or nested header/thread scroll panes.
  - Preserved the existing naming modal and Ase delta feedback.
  - Tightened the hub by removing the courtyard panel, increasing title contrast, and replacing inline emotion text with chips.
- `ui/components/EmotionChip.*`
  - Added a reusable emotional-state chip for current and future Sanctum-family surfaces.
- `assets/theme/LivingTreeSystem.tres`
  - Added the first Sanctum-specific theme slice for cards, header text treatments, and emotion chips.

### Regression Notes

- Godot 4.6.1 headless compile and full registered test suite passed behind the
  required 200-second watchdog after the responsive/layering polish.
- Stable pre-existing warnings remain from Sanctum tile setup and invalid external UIDs outside this story.

### Jeff Signoff

- Status: approved
- Notes: hub story and the integrated responsive/layering refactor were approved
  after final geometry, modal, cross-shell input, exploration HUD, and rail/EchoBar polish.
