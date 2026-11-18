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
| Realm | Stage exploration | Capped Living Tree Turn/Objectives/Party HUD with same-row directive badge; Step/actions remain above EchoBar; the board runs on the shared `BoardCamera`: tap the party or a revealed situation to lock it, tap empty board for FREE, drag, wheel, pinch and Z; the camera keeps its world point and zoom on live resize. |
| Realm | Combat board | Objective, initiative, and controls remain capped while wide layouts expose more board; pan/zoom state is preserved where possible. |
| Realm | Pickup event host | `flow.pickup` routes to the Combat board scene. The board terrain and size are drawn from the snapshot. The real board tokens (`CombatTokenLayer`) show only the standing Echoes, in `row` order, each on its `row[].tile`, with the chooser as the active token (the layer's own ring); enemies, dead actors and fallen Echoes get no token. `CombatBoardScreen.pickup_row_actors` builds that list. Tokens appear on their tile with no slide: the token layer is reset when the event opens and when it closes, and leaving also clears the bark popups. The combat HUD (round, objective, speed bar, quiet-fight line, action menu) is hidden; a `PickupEventStage` sits on top (it holds the pack strip) and the EchoBar stays visible. Back does nothing (the snapshot has no `nav.back`). Debug builds show a temporary Skip and Continue placeholder until V2-ITEM-001b step U9. Camera (D-73): at a new event identity the board frames all row and find tiles with `PickupCameraFrame` (pure planner, `ui/screens/combat/PickupCameraFrame.gd`) from `data.camera_frame` (`floor_zoom`, `margin_px`, `tween_seconds`), clear of the safe areas, the pack strip and the EchoBar; the move is a Sanctum-style tween (`begin_screen_animation`); the camera is set FREE; a repeat or swap snapshot never moves it; a layout change reframes only if the player has not panned or zoomed; a tap on an Echo is ignored; leaving kills the tween and leaves the view. Tests: suite `pickup_ui`, files `tests/PickupUiHostTests.gd` and `tests/PickupCameraFrameTests.gd`. The framing box is the tile centres grown by one tile in total (half a tile on each side). Screenshot fixtures: `pickup_idle_zoomed_out` (kills the opening tween, zooms to 0.3, then reframes with no tween), `pickup_idle_plus`, `pickup_idle_none`, `pickup_idle_frozen` (real won fight through `tests/fixtures/PickupRealBoard.gd`; only the event keys `reaction` or `frozen` are set), `pickup_idle_axis_a` (placement seed 0: the row runs on the row axis, falling to the right) and `pickup_idle_axis_b` (seed 1: the col axis, rising to the right); a seed is set before the real builder runs, so core places the tiles again. The finds lie on their tiles through `PickupFindsLayer` (see the finds layer row); the `pickup_idle_*` fixtures (`pickup_idle_plus`, `pickup_idle_none`, `pickup_idle_frozen`, `pickup_idle_many`, `pickup_idle_many_b`, `pickup_idle_axis_a`, `pickup_idle_axis_b`) show the idle picture (`pickup_idle_zoomed_out` is the framing check), and the review fixtures are the intro ones: `pickup_intro_many`, `pickup_intro_many_b` (seed 1), `pickup_intro_empty`, `pickup_intro_near`, `pickup_intro_full`, `pickup_intro_axis_a` (seed 0), `pickup_intro_axis_b` (seed 1), step `real_pickup:<kind>:intro[:seed=n]`, which publish the real first (intro) snapshot before `pickup.skip`. The chooser bark shows in every phase except `intro` (idle, swap_pick and swap_preview too, D-55; see the bark row); leaving also clears it. An empty `encounter_id` while the stage is visible and the board size is unchanged does not reset the presentation (a reload can publish no id). |
| Realm | Pickup finds layer | a `Node2D` named `PickupFindsLayer` authored in `CombatBoardScreen.tscn` inside `BoardRoot`, before `TokenLayer` (so tokens draw in front) (V2-ITEM-001b R3, D-72 e). Six `ItemTile` marks are authored (the finds cap is 6). `CombatBoardScreen._render_pickup` calls `show_finds(data, _board)` on every pickup snapshot; `_leave_pickup` calls `clear()`. Phase rule (D-74), read from `data.phase` in the pure `ground_finds(data)`: in `intro` it draws EVERY find that carries a `tile`, taken ones too (nothing is in the pack yet; the intro pack strip shows only the pre-event pack), all in the hidden look. In `idle` and any other phase it draws only finds with status `left`, `tried` or `lost` (a frozen chooser loses all), revealed; `taken` finds are in the Travel pack and get no mark. A flip from intro to idle redraws once; the event identity (situation and run count) does not change. The reveal motion is U6. The camera frames the same find tiles in both phases (`pickup_frame_cells` ignores status). A mark is centred on `_board.map_to_local(tile)` plus `feet_offset_y`, the same point a token uses. Mark edge = `bed()` = `token_radius` x 2 = 40 (the token diameter, from the layer's `CombatTokenVisualConfig`). `MAX_MARKS` = 6 equals the last band of `finds_cap_by_realm_scale`. A `tile` counts only with both `col` and `row` (`tile_valid`); the camera uses the same test. The ground ellipse is drawn from the `CombatTokenVisualConfig` shadow values (`shadow_offset`, `shadow_size`, `shadow_color`). A find with `revealed == false` shows an `ItemTile` set up with an empty row (hatch plate, no kind shape, no grade, no name; D-37). Static: no dimming, no motion, no hit areas (marks ignore the mouse and take no focus; U7 adds hit areas). The same finds draw nothing again. No new theme variation, colour or StyleBox. Tests: suite `pickup_ui`, file `tests/PickupFindsLayerTests.gd`. |
| Realm | Pickup chooser bark | The existing `BarkPopupLayer` (the standard combat bubble, template `BarkPopupOriginal`; no new look) shows ONE line above the chooser's row token (V2-ITEM-001b R4, D-41, D-72 a). `CombatBoardScreen._render_pickup` calls `_show_pickup_bark(data, actors)` after the tokens and finds, then `_update_bark_positions(actors)`; `_process` re-anchors the bubble when the camera moves or tweens (`_last_actors` is set by `_render_pickup`). Anchor = `_actor_screen_pos` of the chooser's ROW tile (bubble 72 px above). Text = `CombatBoardScreen.pickup_bark_text(data)`: `PickupUiText.bark(case, reaction, reason, standing_band(chooser standing), chooser index in row)`, the same call and inputs as `PickupEventPlan.build` (`plan.bark.text`); an empty text shows nothing. Phase rule: `data.phase == "intro"` shows no bark (U6 plays it at the right moment); any other phase shows it. The popup uses the new optional event key `persist: true` of `BarkPopupLayer.show_barks`: it skips the hold and fade-out. It is removed only by: `clear_all()` (leaving the event, a new event identity, a text that becomes empty, and `_reset_presentation_state`), a bark for the same actor that replaces it, or `update_actor_positions` with a map that lacks its actor id; every other caller keeps the 2.5 s hold. A repeat snapshot with the same event, chooser and text keeps the same popup (key `_pickup_bark_key`); a changed text in the same event replaces it. `BarkPopupLayer.has_popup(actor_id)` is new. Tests: suite `pickup_ui`, file `tests/PickupBarkTests.gd`. Screenshot fixtures: `pickup_idle_plus`, `pickup_idle_none`, `pickup_idle_many` (idle shows the bark, intro fixtures do not). |
| Realm | Pickup event text and styles | All pickup event text is in `ui/components/PickupUiText.gd` (keys from the snapshot map to lines; item words come from `ItemUiText`). Every line is an agent-written PROPOSAL until Jeff's end review (D-56); `tests/fixtures/PickupUiProposedCopy.json` pins them, separate from `ItemUiApprovedCopy.json`. Theme variations: `PickupSlotEmpty`, `PickupSlotNew`, `PickupDetailsCard`, `PickupBar`, `PickupBarText`, `PickupNameTag`, `PickupWhereGround`, `PickupWhereCarried`, `PickupWherePack`, `PickupAllowance`, `PickupAllowanceSpent`, `PickupControlButton`; the rest reuse `Item*` and `EmotionChip*` variations. No new colour. |
| Realm | Pickup event planners | Pure helpers, no scene nodes: `ui/screens/combat/PickupEventPlan.gd` turns a `flow.pickup` snapshot into the intro timeline (`build`, `frame_at`, `skip_to_idle`; times and constants come from the approved mockup, except `FIELD_STEP` and `FIELD_Y` (D-52 one-row field); 1280 x 720 design space, the scene maps it; `opts.positions` gives real Echo start positions) and `ui/screens/combat/PickupSwapPlan.gd` reads the swap keys (`legal_targets`, `is_twin_refusal`, `preview`, `after_confirm`, `button_state`, `dim_map`). The scene steps U4 to U9 play the frames back; they do not decide anything. Tests: suite `pickup_ui`, file `tests/PickupPlannerTests.gd`. |
| Realm | Pickup pack strip | `ui/screens/combat/PickupPackStrip.tscn` + `.gd`, a child of `PickupEventStage` (V2-ITEM-001b U4). Shows the Travel pack: tone from `pack.tone` (`ItemPanelPack`, `ItemPanelPackNear`, `ItemPanelPackHeavy`), `pack.capacity` slots (eight authored at most; the 001a `ItemSlot` and `ItemTile` are reused), held pieces, stacks and gathered finds from `pack.slots`, empty slots as `PickupSlotEmpty`, unlisted load (`carried` minus listed) as filled sockets without a tile, and the swap and destroy allowance tokens (`PickupAllowance`, `PickupAllowanceSpent`; lines from `PickupUiText` and `ItemUiText`). No strap line. In the `intro` phase it shows only entries with no `find_id` and takes the tone from `pack.tone_before`; it keeps no tone rule (D-70). The board reads the top of the shell `%EchoBarFrame` and the strip bottom edge sits 24 logical units above it at every screen size (D-59, changed by D-69); the strip is centred, and the compact profile uses a 64 slot bed instead of 72. API: `apply_snapshot`, `slot_count`, `slot_global_center`, root `modulate.a` for the later fade. Static in U4: no motion (U6), tiles not tappable (U7). Tests: suite `pickup_ui`, file `tests/PickupPackStripTests.gd`. Screenshot fixtures: `pickup_pack_empty`, `pickup_pack_near`, `pickup_pack_full` play a real won fight through `tests/fixtures/PickupRealBoard.gd` (they need `ECHOES_TEST_SAVE_DIR`); `pickup_host` stays the hand-built U1 frame. |
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
