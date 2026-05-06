# Sanctum Screen Ledger

This file is the canonical screen-story ledger for the Sanctum UI/UX overhaul.

## Boundaries

- Visible layers only. No new gameplay systems.
- Landscape only on mobile and desktop.
- Sanctum remains a prototype spatial shell in this pass.
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

- `Sanctum Hub`: approved and committed
- `Echo Detail`: not started
- `Bonds and Skills`: not started
- `Party Management`: not started
- `Vows`: not started
- `Realm Selection`: not started

## Sanctum Hub

### Scope

- Scrollable spatial-first Sanctum overlay in landscape.
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
- Empty house preview: local message in the courtyard panel.
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
  - Rebuilt into a spatial-first overlay with reusable party and courtyard templates.
  - Preserved the existing naming modal and Ase delta feedback.
  - Tightened the hub by removing the courtyard panel, increasing title contrast, and replacing inline emotion text with chips.
- `ui/components/EmotionChip.*`
  - Added a reusable emotional-state chip for current and future Sanctum-family surfaces.
- `assets/theme/LivingTreeSystem.tres`
  - Added the first Sanctum-specific theme slice for cards, header text treatments, and emotion chips.

### Regression Notes

- Godot headless compile check passed after the final theme and shell polish pass.
- Stable pre-existing warnings remain from Sanctum tile setup and invalid external UIDs outside this story.

### Jeff Signoff

- Status: approved
- Notes: hub story approved after final bevel, spacing, and rail polish; next screen story is Echo Detail
