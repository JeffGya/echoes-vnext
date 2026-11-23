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
  pickup details card 31 (the `CardLayer` in `PickupEventStage`; above the bark layer, below the modal),
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
| Realm | Pickup event host | `flow.pickup` routes to the Combat board scene. The board terrain and size are drawn from the snapshot. The real board tokens (`CombatTokenLayer`) show only the standing Echoes, in `row` order, each on its `row[].tile`, with the chooser as the active token (the layer's own ring); enemies, dead actors and fallen Echoes get no token. `CombatBoardScreen.pickup_row_actors` builds that list. Tokens appear on their tile with no slide: the token layer is reset when the event opens and when it closes, and leaving also clears the bark popups. The combat HUD (round, objective, speed bar, quiet-fight line, action menu) is hidden; a `PickupEventStage` sits on top (it holds the pack strip) and the EchoBar stays visible. Back does nothing (the snapshot has no `nav.back`). Debug builds show a temporary Skip and Continue placeholder until V2-ITEM-001b step U9. Camera (D-73): at a new event identity the board frames all row and find tiles with `PickupCameraFrame` (pure planner, `ui/screens/combat/PickupCameraFrame.gd`) from `data.camera_frame` (`floor_zoom`, `margin_px`, `tween_seconds`), clear of the safe areas, the pack strip and the EchoBar; the move is a Sanctum-style tween (`begin_screen_animation`); the camera is set FREE; a repeat or swap snapshot never moves it; a layout change reframes only if the player has not panned or zoomed; a tap on an Echo is ignored; leaving kills the tween and leaves the view. Tests: suite `pickup_ui`, files `tests/PickupUiHostTests.gd` and `tests/PickupCameraFrameTests.gd`. The framing box is the tile centres grown by one tile in total (half a tile on each side). Screenshot fixtures: `pickup_idle_zoomed_out` (kills the opening tween, zooms to 0.3, then reframes with no tween), `pickup_idle_plus`, `pickup_idle_none`, `pickup_idle_frozen` (real won fight through `tests/fixtures/PickupRealBoard.gd`; only the event keys `reaction` or `frozen` are set), `pickup_idle_axis_a` (placement seed 0: the row runs on the row axis, falling to the right) and `pickup_idle_axis_b` (seed 1: the col axis, rising to the right); a seed is set before the real builder runs, so core places the tiles again. The finds lie on their tiles through `PickupFindsLayer` (see the finds layer row); the `pickup_idle_*` fixtures (`pickup_idle_plus`, `pickup_idle_none`, `pickup_idle_frozen`, `pickup_idle_many`, `pickup_idle_many_b`, `pickup_idle_axis_a`, `pickup_idle_axis_b`) show the idle picture (`pickup_idle_zoomed_out` is the framing check), and the review fixtures are the intro ones: `pickup_intro_many`, `pickup_intro_many_b` (seed 1), `pickup_intro_empty`, `pickup_intro_near`, `pickup_intro_full`, `pickup_intro_axis_a` (seed 0), `pickup_intro_axis_b` (seed 1), step `real_pickup:<kind>:intro[:seed=n]`, which publish the real first (intro) snapshot before `pickup.skip`. The chooser bark shows in idle, swap_pick and swap_preview at once (D-55) and in the intro from the plan's bark time (D-82; see the bark row); leaving also clears it. An empty `encounter_id` while the stage is visible and the board size is unchanged does not reset the presentation (a reload can publish no id). |
| Realm | Pickup finds layer | a `Node2D` named `PickupFindsLayer` authored in `CombatBoardScreen.tscn` inside `BoardRoot`, before `TokenLayer` (so tokens draw in front) (V2-ITEM-001b R3, D-72 e). Six `ItemTile` marks are authored (the finds cap is 6). `CombatBoardScreen._render_pickup` calls `show_finds(data, _board)` on every pickup snapshot; `_leave_pickup` calls `clear()`. Phase rule (D-74), read from `data.phase` in the pure `ground_finds(data)`: in `intro` it draws EVERY find that carries a `tile`, taken ones too (nothing is in the pack yet; the intro pack strip shows only the pre-event pack), all in the hidden look. In `idle` and any other phase it draws only finds with status `left`, `tried` or `lost` (a frozen chooser loses all), revealed; `taken` finds are in the Travel pack and get no mark. A flip from intro to idle redraws once; the event identity (situation and run count) does not change. The reveal motion is U6. The camera frames the same find tiles in both phases (`pickup_frame_cells` ignores status). A mark is centred on `_board.map_to_local(tile)` plus `feet_offset_y`, the same point a token uses. Mark edge = `bed()` = `token_radius` x 2 = 40 (the token diameter, from the layer's `CombatTokenVisualConfig`). `MAX_MARKS` = 6 equals the last band of `finds_cap_by_realm_scale`. A `tile` counts only with both `col` and `row` (`tile_valid`); the camera uses the same test. The ground ellipse is drawn from the `CombatTokenVisualConfig` shadow values (`shadow_offset`, `shadow_size`, `shadow_color`). A find with `revealed == false` shows an `ItemTile` set up with an empty row (hatch plate, no kind shape, no grade, no name; D-37). `show_finds` is the still picture: no dimming, no motion; marks have no hit areas of their own: they ignore the mouse and take no focus. U7 adds the pure hit test `PickupHitRules.hit` (a 48 px round target on each mark's screen centre, the later mark wins); the board turns a tap into `pickup.select`, and the keyboard focus is `set_focus_index` (see the row Pickup input and details card). The same finds draw nothing again. No new theme variation, colour or StyleBox. Tests: suite `pickup_ui`, file `tests/PickupFindsLayerTests.gd`. R6c (the intro): `PickupFindsLayer.show_intro(data, board, items, look, target, chooser_pos)` draws the finds at one clock time from `PickupEventPlan.frame_at(plan, t).items`. Reveal: the empty card flips (width 1 to 0 to 1 over `reveal_len`; the real face from the middle; it runs on its own clock, so a find can still turn while it rises). Carry (D-80): a taken find is carried from its tile up to above the chooser's head (the chooser's drawn token centre now, plus the token radius and `items.carry_above`, the height of the card CENTRE above the token top; the board passes it on every tick, so the card follows the chooser) over `items.carry_len` with the planner's ease, and is held there for `items.carry_hold`; its ground shadow stays on its tile and shrinks by `items.shadow_scale_drop`; the carried card is drawn above the tokens. Flight: from the carried place at the moment it starts to the pack strip slot over `items.fly_len` (smooth ease) with an arc of `items.arc_px`, growing to the slot size; the slot centre is a screen position, turned into board coordinates on every call (`to_board_target`, the layer's canvas transform), so camera pan and zoom do not matter. A flying mark has `z_index` 1, so it draws above the tokens (no new node); it has no shadow. A landed find is hidden and the strip slot shows it. A `tried` find is only revealed (the held item is not built). Pure `item_pose` holds the maths. `show_finds` stays the still picture (idle, no plan). Not built: dim of left-behind finds, lit glow, pulse, the held item. Reduced motion (D-82): `show_intro(..., reduced)` keeps a card on its tile: no flip squash (the face changes at once at the middle of `reduced.reveal_len`), no carry rise, no arc; a flying find fades out of the ground (`alpha` 1 to 0) while its pack slot fades in. |
| Realm | Pickup chooser bark | The existing `BarkPopupLayer` (the standard combat bubble, template `BarkPopupOriginal`; no new look) shows ONE line above the chooser's token (D-41, D-72 a). `CombatBoardScreen._render_pickup` calls `_show_pickup_bark(data, actors)` after the tokens and finds, then `_update_bark_positions(actors)`; `_process` re-anchors the bubble when the camera moves or tweens (`_last_actors` is set by `_render_pickup`). Anchor = `_actor_screen_pos` of the tile the chooser stands on: its end tile in idle, the tile the plan says in the intro (bubble 72 px above). Text = `CombatBoardScreen.pickup_bark_text(data)`: `PickupUiText.bark(case, reaction, reason, standing_band(chooser standing), chooser index in row)`, the same call and inputs as `PickupEventPlan.build` (`plan.bark.text`); an empty text shows nothing. Phase rule: in idle (and any phase but `intro`) the bark shows at once; in the intro it shows from `plan.bark.t0` (D-82), and with no valid plan the intro shows none. The popup uses the new optional event key `persist: true` of `BarkPopupLayer.show_barks`: it skips the hold and fade-out. It is removed only by: `clear_all()` (leaving the event, a new event identity, a text that becomes empty, and `_reset_presentation_state`), a bark for the same actor that replaces it, or `update_actor_positions` with a map that lacks its actor id; every other caller keeps the 2.5 s hold. A repeat snapshot with the same event, chooser and text keeps the same popup (key `_pickup_bark_key`); a changed text in the same event replaces it. `BarkPopupLayer.has_popup(actor_id)` is new. Tests: suite `pickup_ui`, file `tests/PickupBarkTests.gd`. Screenshot fixtures: `pickup_idle_plus`, `pickup_idle_none`, `pickup_idle_many` (idle shows the bark; the intro fixtures show it from the bark time, see `pickup_intro_bark`). Intro (D-82): with a valid plan the bark shows when the intro clock reaches `plan.bark.t0` (also after a clock jump past it), through the same popup, above the tile the plan says the chooser stands on (`_advance_pickup_bark`, `_show_pickup_bark(data, actors, intro_t)`); no type-on. The key `identity|chooser|text` keeps one popup: the flip to idle (the end of the intro or Skip) shows no second bubble and does not restart it; after a Skip the bubble shows at once. Tests: `tests/PickupIntroTests.gd`. |
| Realm | Pickup event text and styles | All pickup event text is in `ui/components/PickupUiText.gd` (keys from the snapshot map to lines; item words come from `ItemUiText`). Every line is an agent-written PROPOSAL until Jeff's end review (D-56); `tests/fixtures/PickupUiProposedCopy.json` pins them, separate from `ItemUiApprovedCopy.json`. The details card uses `ItemDetailsPanel` through the shared `ItemDetailsBlock` (the U2 variation `PickupDetailsCard` was removed, D-86). Theme variations: `PickupSlotEmpty`, `PickupSlotNew`, `PickupBar`, `PickupBarText`, `PickupNameTag`, `PickupWhereGround`, `PickupWhereCarried`, `PickupWherePack`, `PickupAllowance`, `PickupAllowanceSpent`, `PickupControlButton`; the rest reuse `Item*` and `EmotionChip*` variations. No new colour. |
| Realm | Pickup event planners | Pure helpers, no scene nodes: `ui/screens/combat/PickupEventPlan.gd` turns a `flow.pickup` snapshot into the intro timeline on BOARD TILES (`build`, `frame_at`, `skip_to_idle`; times come from the approved mockup, and every tunable number is read from `data.pointer_look` (D-83: groups `timing`, `reasons`, `tempo` hold the former mockup constants, the reason table and the tempo table); the planner has no tunable literal. It differs from the mockup in: the pointer start (0.5 s from `data.pointer_look.path.pointer_start`; it follows the camera tween length, D-73 `tween_seconds` is config: keep them in step when tuning), the `REF_TILES_*` tile reference (provisional feel values), the zero-walk guard (a pick waits until the last find has landed), and the per-reason motions that are dropped (the safe step back, the bold overshoot, the worth approach); no pixel space): the Echoes stay on their `row[].tile`; the chooser has `legs` (`out`: one tile forward off the row toward the finds; `walk`: the board's shortest path from `MovementPathService` to a free stand tile next to a find tile (not a row tile, not another find's tile); the path may cross tiles, no avoidance); finds carry `tile`, a state over time (hidden, revealed, lifted, flying, pack) and a pack slot index (the scene maps the slot to the strip); the pointer is the racetrack `pointer.path` (moves with from, to, kind, times) and the pure `pointer_pose(plan, t)` (D-76; there is no `pointer.steps`); pack tone comes from `data.pack.tone_before` and `tone`; header of the file lists every output key) and `ui/screens/combat/PickupSwapPlan.gd` reads the swap keys (`legal_targets`, `is_twin_refusal`, `preview`, `after_confirm`, `button_state`, `dim_map`). The scene steps U4 to U9 play the frames back; they do not decide anything. Tests: suite `pickup_ui`, file `tests/PickupPlannerTests.gd`. |
| Realm | Pickup pack strip | `ui/screens/combat/PickupPackStrip.tscn` + `.gd`, a child of `PickupEventStage` (V2-ITEM-001b U4). Shows the Travel pack: tone from `pack.tone` (`ItemPanelPack`, `ItemPanelPackNear`, `ItemPanelPackHeavy`), `pack.capacity` slots (eight authored at most; the 001a `ItemSlot` and `ItemTile` are reused), held pieces, stacks and gathered finds from `pack.slots`, empty slots as `PickupSlotEmpty`, unlisted load (`carried` minus listed) as filled sockets without a tile, and the swap and destroy allowance tokens (`PickupAllowance`, `PickupAllowanceSpent`; lines from `PickupUiText` and `ItemUiText`). No strap line. In the `intro` phase it shows only entries with no `find_id` and takes the tone from `pack.tone_before`; it keeps no tone rule (D-70). The board reads the top of the shell `%EchoBarFrame` and the strip bottom edge sits 24 logical units above it at every screen size (D-59, changed by D-69); the strip is centred, and the compact profile uses a 64 slot bed instead of 72. API: `apply_snapshot`, `slot_count`, `slot_global_center`, root `modulate.a` for the later fade. The strip has no motion of its own. U7: in `idle` a tile can be chosen (`pack_chosen`), takes focus and shows the cream ring; the allowance tokens open the `CauseTooltip` (hover, focus, tap); the `Box` separation is 8. Tests: suite `pickup_ui`, file `tests/PickupPackStripTests.gd`. Screenshot fixtures: `pickup_pack_empty`, `pickup_pack_near`, `pickup_pack_full` play a real won fight through `tests/fixtures/PickupRealBoard.gd` (they need `ECHOES_TEST_SAVE_DIR`); `pickup_host` stays the hand-built U1 frame. R6c: `apply_intro_frame(snapshot, landed, tone)` shows the intro at a time: a gathered slot is empty (in its idle place) until its find has landed, then shows the item like idle; the tone is the plan's tone (the snapshot's `tone_before` until the last landing, then `tone`). `slot_index_of_find` gives the idle slot of a find (the flight target), `bed_size` the slot bed in screen px. At the end of the intro the strip equals the idle strip (tested). `apply_intro_frame(snapshot, landed, tone, appear)`: `appear` (find id to alpha) shows a slot that is fading in (reduced motion); the slot is an item cell with an `alpha` and `slot.modulate.a` follows it. |
| Realm | Pickup input and details card | V2-ITEM-001b U7 (D-84). Pure rules `ui/screens/combat/PickupHitRules.gd`: `can_select(phase, side, status)` (only `idle`; a `left`, `tried` or `lost` find or a pack tile; nothing opens in the intro), `hit` (48 px round target, the later mark wins), `min_zoom` ((48 + 8) / the nearest pair of finds in board px; pairs on one spot are skipped; "about 0.49" holds only when the closest pair is 2 tiles apart on the nearest diagonal; a pair at spacing 1 on a diagonal (64 board px) asks for up to 0.875; a wider pair gives a lower floor; the camera never goes below the board-fit minimum, and when the framed box does not fit at the floor the fit wins and the floor gives way to it (`_pickup_fit_cap`, `PickupCameraFrame.fit_zoom`), so every find stays on screen), `selection`. Card placement is the pure `PickupDetailsPlan.plan` (D-84 m): the card lies fully to the left, right, above or below its item, 12 px away, and never covers it. Obstacles in screen px (`CombatBoardScreen._pickup_obstacles`). A find card: the Echo tokens as drawn now (`display_cell_position`, token radius, the canvas transform), the other finds, the pack strip with its tokens, the EchoBar, the debug buttons and the bark popups (`BarkPopupLayer.popup_rects`, weight 0.5). A pack card (D-84 n, D-86 g): only the EchoBar and the debug buttons; it may cover actors, finds, barks and the strip header on purpose. The card lies inside the usable rect (viewport inside the safe insets and a 16 px margin, above the EchoBar). Each side is scored by the weighted area it covers; the first side with none wins; if every side covers something the least area wins; ties keep the order. The card keeps the side it had for the same item while that side still fits, unless it covers something and another side covers nothing (so it does not jump while the camera or an Echo moves). An invalid plan (no side fits) is clamped inside the usable rect on both axes. Order for a find: left, right, above, below. Order for a pack tile: left, above, right, below, where left needs the first tile and right the last (`PickupPackStrip.is_first_slot`, `is_last_slot`). A pack card keeps the normal 12 px gap from its own tile, so the first tile gets the card on its left when that side is free, and every other tile, the last one too, gets it directly above, over the strip header. A card 320 wide above a tile covers the header only partly: at 1280x720 it covers the title and the swap token for the second tile, the title edge and both tokens for the third, and the tokens but not the title for the fourth (strip 344 wide, title 97 wide at its left edge). The hit target of a find is a circle of radius max(half the drawn find in screen px, 24), the same size the card anchor uses (`_pickup_find_half`). After Continue the board takes no pickup input and closes the card (`_pickup_ended`), because the Resolve card opens over the mounted board. The arrow (a square turned 45 degrees behind the card) sits on the edge facing the item, so one node points out of all four sides. `CombatBoardScreen`: `_on_board_tap` in the event calls `_on_pickup_tap` (a find opens or closes its card, a tap on open board closes it, a tap on an Echo, like any tap that does not choose a find, closes an open card and does nothing else, the camera is never released); `_gui_input` sets the pointing-hand cursor over a find that can be selected; `_input` handles Tab, Shift+Tab, arrows and Enter on the marks (focus enters only after a key or pad press; order: finds, the two tokens, the pack tiles, the buttons); `_apply_pickup_zoom_floor` raises the camera minimum zoom during the event and `_leave_pickup` restores it (reuses `camera.configure_zoom_range`; no config key, the floor comes from the finds in the snapshot). `PickupDetailsCard.tscn` + `.gd` in `CardLayer` (a `CanvasLayer`, layer 31, above the bark layer 30 and below the modal host 40) inside `PickupEventStage`: the shared `ItemDetailsBlock` (also used by `InventoryPanels`), a Close button (`ItemButtonOutline`, 48 high), a cream arrow `PickupCardArrow` toward the item (the one new theme variation of U7; same shape as `PayoutTooltipArrow`, the card fill and border colours). No motion on open or close, no Swap button (U8), no description line (marker for V2-ITEM-002). The card closes by an empty `pickup.select` when its item leaves the screen. The stage relays `action_requested` (a pack tile or Close); the board forwards it. Selected or keyboard-focused finds, pack tiles use the cream `ItemTileSelectedDark` ring through the `ring` option of `ItemTile.setup`. Tests: suite `pickup_ui`, file `tests/PickupInputTests.gd` (`input_*`), and two `inventory_ui` tests. Screenshot steps: `select_find`, `select_pack`, `select_none`, `focus_at`, `cam_zoom_by`, `hit_overlay` (harness only), `wait`. |
| Realm | Pickup event stage clock and pointer mote | `PickupEventStage` owns no visual. In phase `intro` a NEW event identity (`situation_id` + `run_count`) builds `PickupEventPlan.build(snapshot)` once and starts an intro clock (t=0; `advance(delta)` is called by `_process`; tests call it directly). The clock emits `clock_ticked(t)` on every tick and stops at `plan.total`, on `clear()`, on a phase other than `intro`, or when `plan.valid` is false; it does no `_process` work otherwise. A repeat snapshot of the same identity never restarts it. Pointer (D-76, Jeff 2026-11-18): a small ivory mote (#F5F0E8) drifts above the Echoes' heads along a racetrack (`PickupEventPlan.pointer_pose`, pure; monotone cubic speed; authored times for n 5 and n 3, a slow-down law for other rows), fades in during the 0.30 s lead, lands in the chooser with a 4 px wind-up and a 20 px sink, and a soft halo opens behind the chooser token and breathes. The Echoes stay still. No token has the selection ring in the pickup event (`_draw_tokens(actors, "", {})`). Nodes (authored in `CombatBoardScreen.tscn`, world space in `BoardRoot`, so camera zoom scales them like the tokens): `PickupPointerHalo/Halo` between `PickupFindsLayer` and `TokenLayer` (the Echo stands in front of its halo); `PickupPointerMote` (`Shadow`, `Trail1..5`, `Mote`) above `TokenLayer`. Every timing and look value comes from `data.pointer_look` (`data.inventory.pickup.pointer_look` in balance.json, D-77; Jeff tunes it there); the UI holds no constants and no defaults, and a snapshot without it gives no intro (`valid` false). The chooser's walk (R6b): the board keeps the plan of the event (built once per identity); when the clock crosses a leg's `t0` (`_advance_pickup_walk`, driven by `clock_ticked`) it redraws all row tokens with the chooser's `grid_pos` on the leg's end tile, `last_actor_action` `{action_type: "pickup.walk", source_id, path}` (the cells entered; the token layer's own constant-speed path walk, no telegraph, no hop) and the token descriptor keys `move_duration` = the leg's `t1 - t0` (an additive per-token override of the layer's speed-bar time) and `move_ease` = `path.walk_ease` (D-80: 0 or absent = the constant-speed walk; above 0 the progress along the whole path length is eased out with a cubic, so the token starts at speed and settles at the end tile; combat never sets either key). If the clock jumps over a leg (Skip, the `pointer_at` screenshot step) the token snaps to the end tile of the last leg crossed (`move_duration` 0.001). A repeat snapshot draws the chooser on the tile the clock implies, so it never resets the walk. In idle (after the intro, Skip, reload, re-enter) the chooser is drawn on `chooser_end_cell`; with no valid plan (no `pointer_look`) it stays on its row tile and nothing walks. Only soft radial gradients with normal blend: no outline, stroke, ring, scrim or sound. `PickupPointerMote.pose_at` is pure; the board calls it on every clock tick (`_on_pickup_clock`) and brightens the chooser token by 20% through `CombatTokenLayer.set_brighten`. The mote and halo are hidden in idle (Skip), on a new event and on leave. The halo, the mote and the chooser's brightness fade out over `mote.halo_fade_out` (default 0.30 s, config) from `pointer.fade_t` = the start of the chooser's first leg (`times.step0` when there is no leg); `pointer_pose` phases: hold, fade, gone; after that nothing is shown. The board and the stage pass `StopMarkMotion.reduced` to `PickupEventPlan.build` (D-82); nothing sets that flag outside tests and screenshots yet (the player setting belongs to U11). Known behaviour (D-78): the plan is built once per event identity from the first snapshot seen; after a swap and then a reload (or leave and re-enter) the chooser may stand next to another find than in the live session (presentation only). Tests: `tests/PickupPointerTests.gd`, `tests/PickupPlannerTests.gd`, `tests/PickupWalkTests.gd`. Fixtures: `pickup_intro_pointer` (seed 0), `pickup_intro_pointer_b` (seed 1), and fixed-time stills `pickup_intro_pointer_t1` (mid-glide, 2.5 s), `pickup_intro_pointer_turn` (first half turn, 1.7 s), `pickup_intro_walk_out` (step `pointer_at_leg_end`: end of the chooser's first leg), `pickup_intro_walk_end` (step `pointer_at_total`: the plan total, the chooser on its end tile; both read the plan), `pickup_intro_pointer_land`, `pickup_intro_pointer_hold` (step `pointer_at:<t>` moves the clock to that intro time and stops it; `pointer_advance:<s>` adds time). Finds and strip (R6c): on every tick the board calls `_advance_pickup_items(t)`, which reads `frame_at(plan, t)` of the SAME plan the board keeps and draws the finds layer and the strip; it also runs on every intro render, so a repeat snapshot resets nothing. A jump of the clock shows the same state as stepping, because the state is a pure function of the plan and `t` and the chooser's place comes from the plan while it stands (`chooser_walking` false); the live token position is read only while a leg runs (the token layer moves a token on its next frame, so after a jump the live position is still the old one). Fixtures: `pickup_intro_reveal`, `pickup_intro_carry`, `pickup_intro_hold`, `pickup_intro_flight`, `pickup_intro_end` (kind `empty`, seed 0) and the same `_many`; steps `pointer_at_find:<k>:<reveal|lift|hold|flight|landed>` and `pointer_at_total` read the plan; the carry and hold stills are `pickup_intro_carry` and `pickup_intro_hold`. Tests: `tests/PickupItemsTests.gd` (suite `pickup_ui`). Skip (D-82, visual only; the Skip input is U9): when the snapshot flips to idle while the intro ran, the mote, halo and the chooser's brightness fade out linearly over `mote.skip_fade` (0.18 s, stepped by `CombatBoardScreen._process`) from their last pose; the finds layer, the strip, the chooser and the bark are the idle picture at once; a second flip does nothing. Reduced motion (D-82): `PickupEventPlan.board_opts()` returns `{ reduced: StopMarkMotion.reduced }`; the board and the stage build the plan with it (one helper, so both build the same plan; the flag is read when an event starts). Reduced: the plan has no pointer path (one rest of the mote on the chooser, `path.pointer_reduced`), the chooser's legs take `reduced.leg_len` (the step out `reduced.step_len`, the frozen wait `reduced.frozen_wait`) with no ease and no walk scale, and the finds use `reduced.reveal_len`, `reduced.carry_len`, `reduced.fly_len`. The reduced literals live in `data.inventory.pickup.pointer_look.reduced` (`path.hold_reduced` and `path.pointer_reduced` stay in `path`). Fixtures: `pickup_intro_bark`, `pickup_intro_reduced`, `pickup_intro_reduced_hold`, `pickup_intro_reduced_flight`, `pickup_intro_reduced_end` (step `reduced:1` sets the flag before the snapshot), `pickup_intro_empty_clip`; step `pointer_at_bark`. |
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
