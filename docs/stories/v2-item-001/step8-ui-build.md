# V2-ITEM-001a step 8: inventory UI build (ui-ux-designer)

> **Cleanup note (2026-11-08).** Reports that this file cites by name but that are no longer in this folder were removed in the story cleanup. Their last copy is in git history at commit `11d566f`. Read one with `git show 11d566f:docs/stories/v2-item-001/<file name>`. The design and research files were merged into `basis-for-001b-and-later.md`.

Written in STE. UI only. No `core/` change. No commit. Private save dir: `ECHOES_TEST_SAVE_DIR=/tmp/echoes-vnext-tests/ui-ITEM001` (deleted before each run).
Contract: `docs/visual-plans/inventory-ui-mockup-v2.html` (D-44) and `decisions.md` D-33 to D-47. All wording is PLACEHOLDER.

## 1. Done per phase

| Phase | State | What |
|---|---|---|
| A | complete | `ItemTile` scene, drawn glyphs, theme styles, `ItemUiText.gd`, Sanctum panel from the new rail button |
| B | complete | Party pack button and departure line, pack panel, details area, drag and drop, select-and-move, `Let it go` modal, path HUD pack button and read-only pack panel |
| C | complete | `ItemResultRow` inside the leave, defeat and stage-clear cards; at-risk row in the leave confirmation; motion, finish-on-first-tap, Continue guard |
| D | complete | Suite `inventory_ui` (27 tests), source-grep test, theme-colour test, shard map, `AGENTS.md` note and suite counts |

Compile check after the last change: `--check-only --quit` gives 0 `SCRIPT ERROR` lines. `--import` ran after the new `class_name` files (`InventoryUITests`). The import run also writes `.png.import` files under `docs/`; I removed the untracked ones. No tracked file was left changed by it.

## 2. Files

New files (all under `ui/` unless marked):

| File | Owns |
|---|---|
| `ui/components/ItemTile.tscn`, `.gd` | The one tile scene (bed, plate, stack edge, count capsule, selected ring). `setup` :43, `play_lost` :143, `_get_drag_data` :193 |
| `ui/components/ItemTileGlyphs.gd` | Drawn inside of a tile: hatch, kind shapes, pips, six notch shapes, leaf, brackets, dashed lost outline |
| `ui/components/ItemSlot.tscn`, `.gd` | One slot (cubby or round socket). Drop target of a drag |
| `ui/components/ItemPanelDrop.gd` | Panel-level drop target (first free slot) |
| `ui/components/ItemMovePlan.gd` | Pure prediction of a move from `data.inventory`. `plan` :67, `discard_block` :102 |
| `ui/components/ItemMeter.gd`, `ItemLoadMark.gd` | Ledger gauge and strap line (drawn); satchel mark |
| `ui/components/InventoryPanels.tscn`, `.gd` | Sanctum panel, pack panel, details area. One scene for both shells |
| `ui/components/PartyPackButton.tscn`, `.gd` | Party pack button, single count, departure line. Used by party details and the path HUD |
| `ui/components/ItemResultRow.tscn`, `.gd` | The one row of result tiles; motion; Continue guard |
| `ui/components/ItemUiText.gd` | All new player-facing strings, each `# PLACEHOLDER` |
| `ui/overlays/ItemDiscardModal.tscn`, `.gd` | The `Let it go` confirmation (ModalHost) |
| `tests/InventoryUITests.gd` | Suite `inventory_ui` |
| `tests/fixtures/InventoryUIFixtures.gd` | Snapshot fixtures (tests and screenshots) |

Changed files:

| File | Change |
|---|---|
| `assets/theme/LivingTreeSystem.tres` | About 760 new lines (styles before `[resource]`, variations at the end): styles `StyleBoxFlat_item_*` (:822 on) and variations `Item*`, `RailButtonSelected` (:2130). No new colour token |
| `ui/shells/SanctumShell.tscn`, `.gd` | `InventoryButton` (first rail button, before Party), `InventoryPanels` instance, discard modal scene, `ui.toggle_pack_panel` intercept (:476), `_bind_inventory_button` (:510) |
| `ui/shells/RealmShell.tscn`, `.gd` | `InventoryPanels` instance (ChromeLayer), discard modal scene (:24), intercept (:572) |
| `ui/screens/sanctum/EchoPartyScreen.tscn`, `.gd` | `PartyPackButton` in the party panel; `set_content_inset_right` :171 (the three panels give up room on the right); reads `data.inventory` :147 |
| `ui/screens/venture/StageExploreScreen.tscn`, `.gd` | `PackHudButton` under the HUD strip; fed from `data.inventory` :637 |
| `ui/screens/venture/ResolveScreen.tscn`, `.gd` | `ItemRow` between the earnings summary and the ledger; `_item_blocks` :834, `_present_items` :852, Continue guard :1085 |
| `ui/overlays/realm/ReturnHomeModal.tscn`, `.gd` | `ItemRow` for the at-risk tiles; 0.25 s Confirm window only while tiles show (:105) |
| `ui/AppRoot.gd` | One line: registers `InventoryUITests` |
| `scripts/test-shard-map.sh` | `inventory_ui` in shard13 |
| `scripts/screenshot.gd` | 14 fixtures (`invs_*` Sanctum shell, `invr_*` Realm shell) and step `inv:<toggle_sanct\|toggle_pack\|select:box:slot>` |
| `AGENTS.md` | Suite count 144 to 145 (3 places), `inventory_ui` in the lists, note under Shell Routing |

## 3. Snapshot fields the UI reads

| Field | Read by | Use |
|---|---|---|
| `data.inventory.unique_cap`, `pack_capacity` | `ItemMovePlan.capacity` | Slot counts. Never hard-coded. Slots drawn = `max(size, highest slot + 1)` (`drawn_slots`) |
| `data.inventory.items`, `stacks`, `pack`, `pack_stacks` rows: `kind`, `name`, `slot`, `grade`, `mark_index`, `type_id`, `count`, `stack_limit`, `at_limit` | `ItemMovePlan.entries`, `ItemTile.setup` | Tiles in their saved slots. `id` is never read. `type_id` is read only to match two stacks for a merge hint |
| `data.inventory.sanctum_used`, `sanctum_room`, `warn.room` | `_render_sanctum_gauge` | Ledger gauge, `Full` word |
| `data.inventory.pack_count`, `pack_free`, `pack_load.level`, `warn.pack` | `InventoryPanels`, `PartyPackButton` | Pack button count; heavy tone, strap line, consequence word |
| `data.inventory.path.discard_pack_reason`, `discard_sanctum_reason`, `discard_used`, `move_reason` | `ItemMovePlan.discard_block`, `InventoryPanels` | Path mode (key present = path view). One-discard state and reason lines |
| `data.items.kept`, `lost` rows | `ResolveScreen._item_blocks` | Leave and stage-clear cards |
| `data.reward_breakdown[cause == "packs_lost"].params.items` | `ResolveScreen._item_blocks` | Defeat card |
| `data.carry_home_preview.items_at_risk` (inside the modal payload `carry`) | `ReturnHomeModal.present` | Leave confirmation row |
| report row `kind`, `grade`, `quantity`, `lost_quantity`, `source`, `mark_index` | `ItemResultRow`, `ItemTile` | Tile, ghost for a stack surplus, leaf |

## 4. Dispatches the UI sends

| Action | Payload | Sender | Notes |
|---|---|---|---|
| `inventory.move.apply` | `{ from, slot, to, to_slot }` (`to_slot` -1 = lowest free slot) | `InventoryPanels._do_move` :517 | By drop or by `Move to ...`. A predicted refusal is not sent. No `slot` key: not a snapshot action |
| `inventory.discard.apply` | `{ from, slot }` plus `count` for a stack | `ItemDiscardModal._on_let_go` :107 | Sent once, after the open window |
| `ui.toggle_pack_panel` | none | `PartyPackButton`, via party screen or path screen | UI-local. The shell intercepts it. It never reaches `FlowRuntime` |

The rail button sends nothing. It calls `InventoryPanels.toggle_sanctum`. No `actions` entry is needed (see BLOCKED 1 for the refusal reason).

## 5. Placeholder strings

Every string is in `ui/components/ItemUiText.gd` (149 lines), one line each, each ending in `# PLACEHOLDER`. Test `inventory_ui/placeholder_strings_are_marked_and_scenes_hold_no_words` scans the file and the six new scenes. The scenes hold only the glyphs `×`, `−`, `+` and the default `x1`.

| Group | Constants |
|---|---|
| Rail, titles | `RAIL_LABEL` (`Stores`), `SANCT_TITLE`, `SANCT_SUB`, `PACK_TITLE`, `PACK_SUB`, `SHOW_PACK`, `HIDE_PACK`, `PARTY_PACK_BUTTON`, `FULL_WORD` |
| Pack level and risk | `PACK_HEAVY`, `PACK_FULL_PATH`, `PACK_NEAR`, `DEPART_LINE`, `AT_STAKE` |
| Details | `DETAILS_*`, `WHERE_*`, `KIND_NAMES`, `BTN_MOVE_PACK`, `BTN_MOVE_SANCT`, `BTN_LET_GO`, `BTN_KEEP`, `PATH_*` |
| Refusals | `R_PATH`, `R_PACK_FULL`, `R_SANCT_FULL`, `R_DISCARD_USED`, `R_NOT_IN_PACK`, `R_OCCUPIED`, `R_TYPE`, `R_STACK_LIMIT`, `R_EQUIPPED`, `R_SANCTUM_ONLY`, `R_UNKNOWN`; map `reason_text` :93 |
| Drop hints | `DROP_*` |
| Modal | `MODAL_*`, `COUNT_FEWER`, `COUNT_MORE` |
| Cards | `CARD_SURVIVED`, `CARD_LOST`, `CARD_PREVIEW`, `leave_risk()` |

Word rules (ANSWERS #86): no "home", no "stage" in these strings. The result row and the at-risk line name no place (test `result_row_is_one_row...`, `leave_confirmation...`). The names of the prototype `W` register are used as written there. Existing text on the cards and the leave confirmation is untouched.

## 6. How the UI maps the rules

| Rule | Where |
|---|---|
| Panels are UI-local, each opens alone, none starts open (D-33, D-35) | `InventoryPanels.toggle_sanctum/toggle_pack`, state reset on a new screen type (`set_snapshot` :134) |
| Sanctum panel left; pack to the right of party details (D-34) | `Spacer` expands when docked right (`_apply_visibility`); the party screen gives up room (`set_content_inset_right`) |
| Pack panel: slots, leaf, heavy tone, strap line, consequence word, no counts, no bead gauge (D-36, D-39) | `_render_pack_state`; test `pack_panel_shows_no_counts_and_level_words` |
| Pulse on a transition into full, 0.4 s, reduced motion 0.15 s fade | `_update_pulses` :370 (uses `StopMarkMotion.reduced`) |
| Drop rules: empty slot reorders, no swap, merge on same type with room, cross container takes first free or the target slot | `ItemMovePlan.plan` :67; test `move_plan_follows_the_core_rules` |
| Select, details, `Move to ...`, `Let it go`; keyboard | Tiles are focusable buttons; arrows use Godot focus; Esc closes (`_unhandled_input` :292) |
| `Let it go`: default focus `Keep it`; Esc, Back, B, outside tap = `Keep it`; 0.25 s window; count picker; no hold or swipe | `ItemDiscardModal` (window :12, input :120, `NOTIFICATION_WM_GO_BACK_REQUEST`) |
| 0.6 s lock after confirm | `InventoryPanels.note_discard_modal_closed` :232. The shell calls it when the modal closes |
| Path view: pack button with the single count, read-only pack panel, one discard on a pack piece | `StageExploreScreen` HUD button; `inv.path` switches `InventoryPanels` to path mode (no drag, `Move` blocked with `path_open`) |
| Result cards: one row, kept then lost, ghost, lift 8, fade 0.5 s, no red/shake/sound | `ItemResultRow`, `ItemTile.play_lost` :143 |
| First tap finishes the motion; Continue guard 0.25 s; sequence cap 2.4 s | `ItemResultRow.absorb_continue` :181, `plan` :38; `ResolveScreen` :1085 |
| Reduced motion | `StopMarkMotion.reduced` (the one project flag); 0.15 s fade, no lift |
| Theme: no new colour token; gold only for action or full, with an ink keyline; dashed outline only for lost | Theme variations `ItemButtonGold`, `ItemCapsuleLimit`; the dashed outline is drawn only when `lost > 0` (`ItemTileGlyphs`) |

## 7. Tests run

Private save dir deleted before each run. Short filtered runs only. `Tests:` lines are raw.

| Suites | Raw `Tests:` line |
|---|---|
| `=inventory_ui` (27 tests, 0.5 s) | `Tests: 27 total, 27 passed, 0 failed` |
| `=foundation_ui,payout_ui,realm_ui,stage_stop_ui,sanctum.layout,sanctum.party,sanctum.summon,summon_price_ui,inventory_ui` | `Tests: 242 total, 242 passed, 0 failed` |
| `=snapshot_contract,snapshot_purity,snapshot_fingerprint,flow_transaction,board_camera.input,board_camera.view,stage_camera,explore,echo_party,pending_result,combat_ui,bark_popup` | `Tests: 172 total, 172 passed, 0 failed` |
| `=board_camera.bounds,board_camera.echo_detail,board_camera.zoom,board_camera.pointer,board_pointer,combat_camera,sanctum_pulse,onboarding,seam,inventory_actions,inventory_paths,inventory_moves` | `Tests: 257 total, 257 passed, 0 failed` |
| `scripts/check-shard-map.sh` | `SHARD MAP CHECK: OK (145 registered suites, each in exactly one of 13 shards or the merge step).` |

Two failures appeared in the first regression run and were fixed: the target-size guards (`sanctum.layout/all_interactive_targets_minimum`, `realm_ui/target_minima_and_spatial_caps`) needed `custom_minimum_size` of at least 48 wide on `PackButton`, `MoveButton` and `LetGoButton`.

Mutation checks by hand (each restored, `cmp` equal): Continue guard removed fails `resolve_cards_show_items_and_guard_continue`; swap allowed on an occupied slot fails `refused_drops...` and `move_plan...`; `toggle_pack` also opening the Sanctum panel fails `panels_start_closed_and_open_alone` and `party_pack_button_is_ui_local_through_the_shell`.

What the 27 tests cover: rail button next to Party and not an action; sizes from the snapshot (20/4, 30/6, 8/2, an entry past the size); tiles in their slots; names from rows, never an id; tile marks and five states; stack tile; placeholder marking; open-alone rule; pack panel without counts; party pack button and departure line; move button and drop actions with parameters; refused drops send nothing and show the reason; reason-key map; unchanged snapshot after a move; move plan table; path read-only and one discard; discard modal (focus, 0.25 s window, count picker, Esc, Back, outside tap, once); modal reaches both shells; party pack button through the shell; result row (one row, survivors, ghosts, no place word); row motion cap and Continue guard; reduced motion; the three result cards through the real `ResolveScreen`; leave confirmation; source grep (no save, `FlowContext`, `FlowRuntime`, core service in the new UI files; no `.new()` or `StyleBoxFlat` in them); theme colours.

## 8. What I verified visually

I rendered with `xvfb-run` and the GL Compatibility driver (Mesa llvmpipe) through `scripts/screenshot.gd`, and viewed these PNGs: `invs_both_panels`, `invs_both_full`, `invs_party_pack`, `invr_path` (1280x720 and 1920x1080), `invr_leave_result`, `invr_leave_confirm`, `invr_defeat_items`. The screenshots are in `/tmp/claude-0/shots/` and are not saved in the repo. Regenerate:

```
xvfb-run -a -s '-screen 0 1280x720x24' $GODOT_BIN --path <checkout> --rendering-driver opengl3 --resolution 1280x720 --script res://scripts/screenshot.gd -- <fixture> <out_dir>
```

Fixtures: `invs_sanctum`, `invs_sanctum_empty_details`, `invs_both_panels`, `invs_stack_selected`, `invs_both_full`, `invs_party_pack`, `invs_party_closed`, `invr_path`, `invr_path_used`, `invr_leave_confirm`, `invr_leave_result`, `invr_leave_result_midmotion`, `invr_defeat_items`, `invr_stage_clear_items`.

Seen and judged by me: tile construction, stack edge and capsule, gold at-limit capsule, carried leaf, selected ring on both beds, heavy pack tone with strap line and consequence word, soft-blocked `Move` with its reason line, ledger full state (gold with ink frame), pack to the right of party details with the party panels compressed, path HUD pack button, ghost tiles with dashed outline on the three cards, at-risk brackets in the confirmation.

NOT verified visually: any motion (screenshots are still frames; the 0.5 s fade, the lift and the stagger were checked only by state in tests); the stage-clear card render (the PNG was written, I did not view it); `invs_sanctum`, `invs_stack_selected`, `invr_path_used`; a grayscale pass; a real touch drag on a device; drag and drop with a real mouse (tests call `_can_drop_data` and `_drop_data` directly, as the engine does); controller focus order; any screen at 1600x900 or in a compact profile.

## 9. RUN REQUEST (main chat)

1. Command (one full mode only): `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"` with Bash `timeout` 3600000. The script carries its own per-shard alarms.
2. Expected duration: about 18 minutes on 4 cores, about 31 minutes on 2 cores.
3. Files the run edits: none in the checkout. It writes `/tmp/echoes-vnext-sharded/`. No `trap` is needed.
4. Verify: `git status --short` and `git diff --stat` are the same before and after. After the run, `git ls-files --others --exclude-standard | grep '\.import$'` must be empty (a Godot import writes `.png.import` files under `docs/`).
5. Read back: the `COMBINED:` line (expected total 2683 + 27 = 2710, 0 failed; the 2683 is the figure in `step7-backend-moves-slots.md`, QA round 4), any shard log without a `Tests:` line, the `movement_fallback` merge line, and the `TIMING_SUITE` line of `inventory_ui` (expected under 2 s).

## OPEN — questions and assumptions

BLOCKED: 1. The core returns no reason on a refused move or discard. `InventoryController._deny` (`core/runtime/controllers/InventoryController.gd`) puts the key in `error_code` and in the log, and `FlowRuntime` returns the unchanged snapshot. The brief asks for "the returned reason key". The UI cannot read it. Smallest UI-local alternative (built): the UI predicts the refusal from the snapshot with the same keys (`ItemMovePlan`), shows the line before it dispatches, and shows the generic line `R_UNKNOWN` when a dispatched move leaves the snapshot unchanged. Smallest core change if Jeff wants the real key: add a one-shot `data.inventory.refused = { reason_key }` to the rebuilt snapshot on a refusal. That is a core change and needs approval.

BLOCKED: 2. Item report rows carry no `name`. `data.items` rows, `items_at_risk` rows and the `packs_lost` rows hold `type_id` and `kind` only (`step6-fixes.md`, report row). Only `data.inventory` rows carry `name` (`InventoryService.snapshot`). So a result tile shows the kind word (`Gear`, `Relic`, ...) on focus or tap, never a name and never the type id. The UI already shows `row.name` when a row has one (`ItemUiText.display_name`), so adding `name` to the report rows in core needs no UI change. Core change, needs approval.

ASSUMED: 1. The game rail has no `Sanctum` button (only Party, Summon, Choose Realm, Vows, Weaving; the prototype drew a `Sanctum` button). I put `InventoryButton` first in the rail, before Party. It is enabled on `flow.sanctum` and `flow.echo_party` only. Core allows moves in those two screens only (`InventoryRules.mode`).

ASSUMED: 2. The rail has no selected look today. Unselected rail buttons fall back to the default (gold) button style, because `ButtonSecondary` has no entry in the theme. I added `RailButtonSelected` (cream fill, ink text, gold underline) and use it only on `InventoryButton` while its panel is open. I did not restyle Party or the other buttons.

ASSUMED: 3. `grade` is a string such as `g2`. Pips = the digits, clamped to 1 to 3. A grade without a digit shows no pips (`ItemTile.pips_of` :92).

ASSUMED: 4. In party prep the pack column docks at the right edge, and the three party panels give up its width, with their minimum width lowered from 300 to 200. At 1280 the echo list and detail panel are narrow while the pack is open. If Jeff wants the pack over the panels instead, only `set_content_inset_right` changes.

ASSUMED: 5. The path pack button sits under the HUD strip at the left (x 16, y 80), and in path mode the column starts 64 units lower than in the Sanctum so it clears the directive badge. The `StageWhyCard` (opened from a stop mark) can overlap the button while it is open.

ASSUMED: 6. A Sanctum screen with a live path (encounter Back route, Continue into a live path) behaves as the Sanctum (D-40): `data.inventory` has no `path` key there, so moves and unlimited discard show as allowed.

ASSUMED: 7. A slot past the container size (an entry written past the size) is drawn as an extra slot (`drawn_slots`, step 7 ASSUMED 1).

ASSUMED: 8. The 0.6 s lock after confirm is applied to the details `Let it go` button for 0.6 s after the discard modal closes, from either button. It stops a double tap from opening a second confirmation. The modal itself closes at once on confirm.

ASSUMED: 9. The leave confirmation `Confirm` waits 0.25 s only when item tiles show (D-32). With no items it is immediate, as before, so the existing payout tests are unchanged.

ASSUMED: 10. The first press on a result card finishes the item motion and the Continue press that the same tap produces is ignored by the 0.25 s guard. The motion of the Ase and Echo lines (existing `skip_motion`) still never blocks Continue when no item row shows.

ASSUMED: 11. The stage-clear row plays the same sequence as the leave card, with the `Preview. Read-only.` mark. I did not view that card in a screenshot.

ASSUMED: 12. The dim layer behind open panels does not take input (it only dims). A tap on a panel background inside the Sanctum board can still reach the board tap handler (existing `SanctumShell._classify_press` treats a panel as tappable). Tiles and buttons are interactive and are protected.

Not built, by the brief: encounter-card tile row (parked), pack-shrink rule (D-41), controller focus order beyond Godot defaults.

## Fixes after UI QA (D-48)

Source: `step8-qa-report.md`, D-48, backend section `Refusal key (D-48)`. UI only. No `core/` change. No commit. Compile check (`--quit`): 0 `SCRIPT ERROR` lines.

### Changes

| Item | Change | File |
|---|---|---|
| F8-01 | `_pack_hud` guarded with `if _pack_hud != null`; the test sets `_pack_hud` like the other nodes | `ui/screens/venture/StageExploreScreen.gd` (layout block, `_apply_responsive_layout`); `tests/Stage004SeamTests.gd` (line after `_hud_strip`) |
| Refusal key | `set_snapshot` reads `data.inventory.refused.reason`; shows its line (placeholder per key, unknown key gives `R_UNKNOWN`); every snapshot first clears both lines, so the key is never kept. The prediction still drives the button looks; the key wins on screen. Line shows in the target box of a move, else the selected box | `ui/components/InventoryPanels.gd` (`set_snapshot`, `_clear_lines`, `_refusal_box`) |
| New lines | `R_NO_CHANGE`, `R_GONE`, `R_BAD_SLOT`, `R_COUNT`, `PATH_HINT`; `reason_text` maps `no_change`, `unknown_entry`, `not_found`, `bad_slot`, `count_range` | `ui/components/ItemUiText.gd` |
| Names | No change needed: `ItemUiText.display_name` already prefers `row.name`. Tests cover named, unnamed, at-risk, and the real leave confirmation | tests only |
| F8-03 | Blocked `Move` and `Let it go` use new variation `ItemButtonBlocked` (muted text, thin border, no fill) | `assets/theme/LivingTreeSystem.tres` (end of file); `InventoryPanels.gd` (`_refresh_selection`) |
| F8-04 | On a path the pack and details sit side by side (`Column` is a `BoxContainer`, vertical off in path mode); the panels stop 112 above the bottom edge of the bottom HUD | `InventoryPanels.tscn`, `InventoryPanels.gd` (`_apply_visibility`); `ui/shells/RealmShell.gd` (`_PATH_BUTTONS_CLEARANCE`) |
| F8-05 | Path details hint: `PATH_HINT` | `InventoryPanels.gd` (`_refresh_selection`) |
| F8-06 | Brackets on a dark card: cream, 3 wide, ink keyline, outside the bed; row and lines centred in the confirmation. Cream `#F5E6D3` on the card `#10 0E 1A` measures 15.7:1 | `ui/components/ItemTileGlyphs.gd` (`_draw_brackets`), `ItemResultRow.gd` (`set_on_dark`) |
| F8-07 | A snapshot with no `data.inventory` resets and closes the panels; `toggle_pack` does nothing without inventory; the HUD pack button hides | `InventoryPanels.gd` (`set_snapshot`, `toggle_pack`); `StageExploreScreen.gd` |
| Leak | The ObjectDB warning came from my code: `_flash` awaited a `SceneTreeTimer`. Now a node Tween. `--verbose` shows no leaked instance | `InventoryPanels.gd` (`_flash`) |
| Refusal line on dark | Pack panel refusal line uses the light text variation | `InventoryPanels.tscn` |
| Screenshots | Fixtures `invs_refusal`, `invs_refusal_slot` | `scripts/screenshot.gd` |
| F8-02 | DEFERRED by Jeff (D-48). Not built. Known gap: on a path the pack can read full with empty sockets because finds are open rows, not listed in `data.inventory.pack` | none |

### Tests

`inventory_ui` now has 35 tests (8 new, 1 repaired). F8-09: the step "stack at its limit" now drops a same-type stack on a stack at 20 of 20 and expects `R_STACK_LIMIT`.

| Mutation (restored, `cmp` equal) | Test that fails |
|---|---|
| Directive badge width 204 to 300 | `realm_ui/target_minima_and_spatial_caps` (badge not capped). Without the fix round change it proved nothing |
| Lock check removed (`Time.get_ticks_msec() < _letgo_lock_until` to `false`) | `inventory_ui/let_it_go_lock_after_the_modal_closes` |
| `_pack_strap.pulse(...)` removed | `inventory_ui/pack_pulses_once_when_it_becomes_full` |
| `ResolveScreen._input` item finish disabled | `inventory_ui/a_tap_anywhere_finishes_the_card_motion` |

| Suites | Raw `Tests:` line |
|---|---|
| `=realm_ui` (after the fix, no `SCRIPT ERROR`) | `Tests: 20 total, 20 passed, 0 failed` |
| `=inventory_ui` | `Tests: 35 total, 35 passed, 0 failed` |
| `=inventory_ui,realm_ui,payout_ui,foundation_ui,sanctum.layout,sanctum.party,echo_party,stage_stop_ui,seam,inventory_paths,inventory_actions` | `Tests: 308 total, 308 passed, 0 failed` |

### Viewed (xvfb-run, `scripts/screenshot.gd`, 1280x720 and 1920x1080)

| Screen | Result |
|---|---|
| Path view, pack open (`invr_path`), both sizes | Details beside the pack; `To the Sanctum` clear |
| Path, discard used (`invr_path_used`), 1280 | Both buttons look disabled; reason lines show |
| Leave confirmation (`invr_leave_confirm`), 1280 | Cream brackets with keyline visible; row centred |
| Leave result (`invr_leave_result`), 1920 | Survivors and ghosts in one row |
| Refusal line in a panel (`invs_refusal`), 1280 | `The Sanctum is full. Free a slot first.` readable (viewed as a crop) |

NOT viewed: names appearing on focus or tap (tests only); `invr_leave_confirm` at 1920; `invs_refusal` at 1920; `invr_path_used` at 1920; the path view with the real bottom HUD buttons (the fixture draws a bar and the `To the Sanctum` button only); any motion.

### RUN REQUEST (main chat)

1. Command: `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"` with Bash `timeout` 3600000.
2. Duration: about 18 minutes on 4 cores, about 31 on 2.
3. Files edited by the run: none in the checkout (`/tmp/echoes-vnext-sharded/`). No `trap`.
4. Verify: `git status --short` unchanged; no untracked `.import` file.
5. Read back: `COMBINED:` (expected 2716 + 8 = 2724, 0 failed), any shard log without `Tests:`, the `movement_fallback` merge line, no `SCRIPT ERROR` in the `realm_ui` shard.

## OPEN — questions and assumptions

ASSUMED: 1. A refusal from the core shows in the target box of the last move, else the selected piece's box. After a refused move the selection points at the target slot (empty) and the details clear.
ASSUMED: 2. New wording (`R_NO_CHANGE`, `R_GONE`, `R_BAD_SLOT`, `R_COUNT`, `PATH_HINT`) is placeholder. `bad_payload`, `bad_box`, `bad_state`, `not_unique`, `no_stage` use the generic line.
ASSUMED: 3. On a path the details sit right of the pack (side by side), 360 wide each; at 1280 the pair spans x 536 to 1264.
BLOCKED: none.

## Fixes after UI QA round 2

Source: `step8-qa-report-2.md`. UI only. No `core/` change. No commit. Compile check (`--quit`): 0 `SCRIPT ERROR` lines.

### Root cause of F9-01

An autowrap label with no minimum width asks for a one-character column while the container lays out. Its height, and so the panel's, grows to hundreds of pixels (`PackRefuseLabel` measured 679 px). The path layout is side by side, so the tall panel pushed both panels off the top of the screen. It showed only when the refusal line was laid out, because the other wrapping labels had a width from their parents. Fix: every wrapping label in `InventoryPanels.tscn` keeps a minimum width (300, or 160 in the narrow details column). The line never changes the panel size: it wraps inside a width that exists.

### Changes

| Item | Change | File |
|---|---|---|
| F9-01 | `custom_minimum_size` on all 9 autowrap labels | `ui/components/InventoryPanels.tscn` |
| F9-02 | The `_refusal_box` branch on `_last_to` was dead code (a move already selects its target box). Removed. The mutation at the old :167 now fails a test | `ui/components/InventoryPanels.gd` (`_refusal_box`, `set_snapshot`) |
| F9-06 | `_last_to` reset with the screen state | `InventoryPanels.gd` (`_reset_local`) |
| F9-04 | Tile gap on a dark card 10 to 16, so the brackets of neighbours do not touch | `ui/components/ItemResultRow.gd` (`set_on_dark`) |
| F9-05 | Left as built. Existing disabled buttons use `disabled = true` (not focusable). A blocked `Move` and `Let it go` stay focusable on purpose, so a press or a screen reader reaches the reason line | none |
| Screenshots | Fixture `invr_path_refused` | `scripts/screenshot.gd` |

### Tests

Three new tests in `inventory_ui` (38 tests).

| Test | Pins |
|---|---|
| `refusal_line_never_resizes_or_moves_the_path_panels` | At 1280x720 and 1920x1080, path view with a selection, three refusal keys: every wrapping label needs at most 120 px, the panel row stays under 60 percent of the viewport and within 70 px of its height without the line, and returns to the same height when the line hides |
| `container_full_line_names_the_destination` | `container_full` after a move to the pack shows `R_PACK_FULL` in the pack panel only; after a move to the Sanctum shows `R_SANCT_FULL` in the Sanctum panel only; `_last_to` clears on a screen change |
| `hud_pack_button_hides_without_inventory` | A path snapshot without `data.inventory` hides `%PackHudButton` (real `StageExploreScreen`) |

| Mutation (restored, `cmp` equal) | Result |
|---|---|
| Old `InventoryPanels.tscn` (no label widths) | `refusal_line_never_resizes...`: `PackRefuseLabel needs 679 px of height` |
| `reason_text(reason, "")` (old :167) | `container_full_line_names_the_destination`: `pack line 'The Sanctum is full...'` |
| `_refusal_box` ignores `_last_to` (old :567) | Equivalent mutant: the move already selects its target, so no test can differ. The branch was removed instead |
| HUD pack button always visible | `hud_pack_button_hides_without_inventory` |

| Suites | Raw `Tests:` line |
|---|---|
| `=inventory_ui` | `Tests: 38 total, 38 passed, 0 failed` |
| `=inventory_ui,realm_ui,payout_ui,foundation_ui,sanctum.layout,sanctum.party,echo_party,seam,inventory_paths` | `Tests: 248 total, 248 passed, 0 failed` |

### Viewed (xvfb-run, `scripts/screenshot.gd`)

| Screen | Sizes | Result |
|---|---|---|
| Path view, pack open, a refusal snapshot (`invr_path_refused`) | 1280x720, 1920x1080 | Both panels stay in place (y 80 to 385, and 100 to 480); the line wraps inside the pack panel; `To the Sanctum` clear |
| Leave confirmation | 1920x1080 | Brackets of neighbour tiles no longer touch |

NOT viewed: the old broken render (the QA PNGs from `/tmp/claude-0/qaui2-shots/` were not reopened; the old code is proved by the failing test above); the leave confirmation at 1280 after the gap change; any motion; the compact profile.

### RUN REQUEST (main chat)

1. Command: `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"` with Bash `timeout` 3600000.
2. Duration: about 18 minutes on 4 cores, about 31 on 2.
3. Files edited by the run: none in the checkout (`/tmp/echoes-vnext-sharded/`). No `trap`.
4. Verify: `git status --short` unchanged; no untracked `.import` file.
5. Read back: `COMBINED:` (expected 2724 + 3 = 2727, 0 failed), any shard log without `Tests:`, the `movement_fallback` merge line.

## OPEN — questions and assumptions

ASSUMED: 1. The 300 and 160 minimum widths are layout numbers, not design values.
ASSUMED: 2. The refusal line may grow the pack panel by one or two text lines. The test allows 70 px. It cannot move the panels off screen.
BLOCKED: none.

## Strap line removed (D-49)

Source: D-49, K4 (Jeff: the line design was not agreed). UI only. No `core/` file and no non-UI test touched (the other changed files in the tree belong to another agent). No wording changed. Compile check (`--quit`): 0 `SCRIPT ERROR` lines.

### Changes

| Item | Change | File |
|---|---|---|
| Strap node | `PackStrap` removed | `ui/components/InventoryPanels.tscn` |
| Strap code | `_pack_strap` and its level removed; level kept as `_pack_level` | `ui/components/InventoryPanels.gd` (`_render_pack_state`, `_update_pulses`) |
| Strap drawing | `strap` mode and `_draw_strap` removed; the ledger gauge is unchanged | `ui/components/ItemMeter.gd` |
| Tone steps | Plain, near full and full are three tones: `ItemPanelPack`, new `ItemPanelPackNear` (`#3E2E1F`), `ItemPanelPackHeavy` (existing). Before, near full had the plain tone and only the line. The risk words are unchanged | `assets/theme/LivingTreeSystem.tres` (new `StyleBoxFlat_item_panel_pack_near`, variation at the end); `InventoryPanels.gd` (`_render_pack_state`) |
| Pulse | The pulse on a transition into full now acts on the panel tone only: a brightness flash of 0.4 s, once; reduced motion is a 0.15 s fade. The sanctum ledger pulse is unchanged | `InventoryPanels.gd` (`_pulse_pack_tone`, `_tone_tween`) |
| Screenshots | Fixtures `invs_party_lv0/2/3`, `invr_path_lv0/2/3` | `scripts/screenshot.gd` |

### Tests

Rewritten: `pack_panel_shows_no_counts_and_level_words` (checks the tone variation and the word at each level, and that no `PackStrap` node exists) and `pack_pulses_once_when_it_becomes_full` (checks the panel-tone tween). No strap assertion remains.

| Mutation (restored, `cmp` equal) | Result |
|---|---|
| Near full gets the full tone | `pack_panel_shows_no_counts_and_level_words`: `near full: tone=ItemPanelPackHeavy` |
| Full gets the near tone | same test: `a full pack needs the darkest tone` |
| Pulse call removed | `pack_pulses_once_when_it_becomes_full`: `did not pulse the panel tone` |

| Suites | Raw `Tests:` line |
|---|---|
| `=inventory_ui` | `Tests: 38 total, 38 passed, 0 failed` |
| `=inventory_ui,realm_ui,foundation_ui,sanctum.layout,sanctum.party,echo_party,payout_ui` | `Tests: 177 total, 177 passed, 0 failed` |

### Viewed (xvfb-run, `scripts/screenshot.gd`, 1280x720)

Pack panel at empty, near full (3 of 4) and full (4 of 4), in party details and on the path, in colour and in grayscale copies.

| Check | Result |
|---|---|
| Colour | The three levels read apart: plain brown, darker, darkest; the words `Nearly full.` and `Heavy. They may lose what they carry.` (path: `Full. Nothing more fits.`); the satchel mark fills its bands |
| Grayscale | The tone step alone is WEAK. Luma (0.299 R + 0.587 G + 0.114 B): plain 59.6, near 49.1, full 42.9. In the grayscale copies the near and full panels look almost the same, and the plain one only a little lighter. What still separates the levels in grayscale: the words, and the number of tiles. I added no decoration, as asked |

NOT viewed: the pulse (motion); 1920x1080; the Sanctum panel next to a full pack; a real display (xvfb only).

### RUN REQUEST (main chat)

1. Command: `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"` with Bash `timeout` 3600000.
2. Duration: about 18 minutes on 4 cores, about 31 on 2.
3. Files edited by the run: none in the checkout (`/tmp/echoes-vnext-sharded/`). No `trap`.
4. Verify: `git status --short` unchanged; no untracked `.import` file.
5. Read back: `COMBINED:` (no test added or removed by this change; the count is the other agent's count), any shard log without `Tests:`, the `movement_fallback` merge line.

## OPEN — questions and assumptions

ASSUMED: 1. "Keep the darker tone at near-full and full" means two darker steps. Near full had no tone step before; I added `ItemPanelPackNear`. If Jeff wants only one dark tone, delete the near variation and the near line in `_render_pack_state`.
ASSUMED: 2. The grayscale weakness is for Jeff to judge. A bigger tone step needs only a colour change in two styles (no new token is needed beyond the one already added).
BLOCKED: none.

## Approved copy and tone C (D-51)

Source: D-51, `copy-approval-jeff.md` (Pick column), D-50. UI only. No `core/` file touched. No commit. Compile check (`--quit`): 0 `SCRIPT ERROR` lines. Every shown string comes from Jeff's Pick column, with his four spelling fixes and his two answers (COUNT_LABEL "Count"; a refused button shows only the refusal line). A script cross-checked all 54 picks against `ItemUiText.gd`; the only differences are the confirmed fixes and the removed `ONE_PIECE`.

### Constants changed

| Id | Old | New |
|---|---|---|
| RAIL_LABEL | Stores | Storehouse |
| SANCT_TITLE | Sanctum storage | Storehouse |
| PACK_TITLE | Party pack | Travel pack |
| SHOW_PACK / HIDE_PACK | Show pack / Hide pack | Open pack / Close pack |
| CLOSE_SANCT / CLOSE_PACK | Close Sanctum storage / Close party pack | Close the storehouse / Close the pack |
| PARTY_PACK_BUTTON | Party pack | Travel pack |
| FULL_WORD | Full | Full (approved, same) |
| PACK_NEAR | Nearly full. | Almost full. |
| PACK_FULL_PATH | Full. Nothing more fits. | Pack is full. Nothing else fits. |
| DEPART_LINE | Carried pieces can be lost on a defeat or an early leave. | There are items in the travel pack. Items can be lost. |
| DETAILS_EMPTY | Select a piece to see its details. | Select an item to learn more. |
| WHERE_SANCT / WHERE_PACK | In the Sanctum / In the pack | Storehouse / Pack |
| KIND_LABEL, GRADE_LABEL | Kind, Grade | same |
| COUNT_LABEL | Count | Count (Jeff's answer; a single piece shows `Count: 1`) |
| AT_LIMIT | At the limit | Full stack |
| BTN_MOVE_PACK / BTN_MOVE_SANCT | Move to pack / Move to Sanctum | Put in pack / Place in storehouse |
| BTN_LET_GO | Let it go | Destroy |
| BTN_KEEP | Keep it | Keep |
| PATH_LEFT | Let it go: 1 left this path | 1 destroy action left on this path. |
| PATH_USED | Let it go: used | No destroy action left. |
| PATH_HINT | On a path, pieces cannot be moved. | While on the move you can't reorganize your pack. |
| KIND consumable | Consumable | Supply (gear, relic, material unchanged) |
| R_PATH | Moves are closed on a path. | While on the move you can't organize your pack. |
| R_PACK_FULL / R_SANCT_FULL | ...Free a socket first. / ...Free a slot first. | The pack is full. / The storehouse is full. |
| R_DISCARD_USED | The one discard of this path is used. | No destroy actions left. |
| R_OCCUPIED | That slot is taken. Drop on an empty slot. | This spot is taken. Choose an empty spot. |
| R_TYPE | Only the same kind of stack can merge. | Only similar items can be joined. |
| R_STACK_LIMIT | That stack is at its limit. | This stack is already full. |
| R_EQUIPPED | It is in use. | This is in use. |
| R_SANCTUM_ONLY, R_NO_CHANGE | unchanged | same |
| R_GONE | That piece is not there any more. | It's no longer there. |
| R_BAD_SLOT | That slot is not available. | That spot is not available. |
| R_COUNT | That count is not possible. | This is not possible. |
| R_UNKNOWN | That did not work. Nothing changed. | Nothing was changed. |
| DROP_REORDER / DROP_MERGE / DROP_PACK / DROP_SANCT | long forms | Drop to place / Drop to combine / Move to pack / Move to storehouse |
| MODAL_TITLE | Let this go? | Are you sure? |
| MODAL_PATH_LINE | This is the one discard of this path. | There is only 1 chance to destroy on this path. |
| MODAL_COUNT_LABEL, COUNT_FEWER, COUNT_MORE | How many? / Fewer / More | How many? / One less / One more |
| LEAVE_RISK_LABEL, CARD_SURVIVED, CARD_LOST, ITEMS_GROUP_LABEL | At stake / Survived / Lost / Pieces | At risk / Made it through. / Lost / Items. |
| slots_word, sockets_word | `3 / 20 slots`, `2 / 4 sockets` | `3 / 20 spots filled`, `2 / 4 spots filled` |
| pack_button | Party pack 2/4 | Travel pack 2/4 |
| stack_count | x3 of 20 | same |
| leave_risk | They may lose 3 pieces. | `3 items can be lost` and `1 item can be lost.` (as typed) |
| moved_toast | It is now in the pack. / ...Sanctum. | Placed in pack. / Placed in storehouse (as typed) |
| Refusal line pattern | `Put in pack: The pack is full...` | only the refusal line |

### Constants removed (and the element that showed them)

| Id | Element removed | File |
|---|---|---|
| SANCT_SUB, PACK_SUB | `SanctSub`, `PackSub` labels | `InventoryPanels.tscn`, `.gd` |
| PACK_HEAVY | The pack word in party details at full (tone and departure line only). `PackWord` shows only at near full, or at full on a path | `InventoryPanels.gd` (`_render_pack_state`) |
| AT_STAKE, AT_STAKE_LABEL | `StakeRow` (leaf and line) in the details area. The leaf on the tiles stays and has no spoken label | `InventoryPanels.tscn`, `.gd` |
| DETAILS_TITLE | `DetailsTitle` label | same |
| DETAILS_HINT | The hint line in the Sanctum details. `HintLabel` shows only on a path (`PATH_HINT`) | `InventoryPanels.gd` (`_refresh_selection`) |
| PATH_READONLY | `PathReadonly` label | same |
| PATH_RULE | `PathNote` label | same |
| PATH_PREVIEW, CARD_PREVIEW | `PreviewTag` on the result row; the `preview` argument of `ItemResultRow.show_report` and the `preview` key of `_item_blocks` | `ItemResultRow.tscn`, `.gd`; `ResolveScreen.gd` |
| R_NOT_IN_PACK | The key falls back to `R_UNKNOWN` | `ItemUiText.reason_text` |
| MODAL_LINE, MODAL_PACK_LINE, MODAL_SANCT_LINE | `LineLabel`, `WhereLabel` in the modal | `ItemDiscardModal.tscn`, `.gd` |
| ONE_PIECE | Details show `Count: 1` | `InventoryPanels.gd` |

Panels close up (viewed): no gap where a removed line was.

### Marker, fixture, tests

`ItemUiText.gd`: every string line ends with `# APPROVED (Jeff 2026-11-08)`; no `# PLACEHOLDER` remains. Leftover scan: no player-facing "discard", "let it go", "release", "stage", "home" in the new UI files (only code identifiers, action names and comments remain).

Fixture `tests/fixtures/ItemUiApprovedCopy.json` (65 keys: every constant, `KIND *`, and the built lines). New and rewritten tests in `inventory_ui` (41 tests):

| Test | Pins |
|---|---|
| `placeholder_strings_are_marked_and_scenes_hold_no_words` (rewritten) | Every string line has the approved marker; no `# PLACEHOLDER`; scenes hold no words |
| `approved_copy_matches_the_fixture_word_for_word` (new) | Every constant, kind name and built line equals the fixture; a constant missing from the fixture, or a fixture key missing from the code, fails |
| `pack_tones_are_the_approved_steps` (new, F10-03) | Three tones `#7A5B3E`, `#4F3B28`, `#120E0C`; near differs from plain and full; steps at least 1.3:1 and 1.5:1; cream text at least 4.5:1 on each |
| `pack_pulse_lengths_flash_and_reduced_fade` (new, F10-03) | Pulse 0.4 s with a brightness flash; reduced motion 0.15 s fade from transparent |
| Rewritten for removals | `pack_panel_shows_no_counts...` (no word at full in party details), `refusal_keys_map_to_text` (`not_in_pack` gives the unknown line), `blocked_buttons_look_disabled...` (no hint in the Sanctum, path hint without "drag"), `result_row_is_one_row...`, `resolve_cards_show_items...` (no preview mark on any card) |

| Mutation (restored, `cmp` equal) | Result |
|---|---|
| `Are you sure?` to `Are you certain?` | `approved_copy_matches...`: `MODAL_TITLE is 'Are you certain?', approved 'Are you sure?'` |
| Marker removed from `RAIL_LABEL` | marker test: `holds wording with neither marker` |
| `# PLACEHOLDER` put on `RAIL_LABEL` | marker test: `still holds a placeholder` |
| Flash 0.4 to 0.5 | `pack_pulse_lengths...`: `lasts 0.500 s, wanted 0.40 s` |
| Reduced fade 0.15 to 0.2 | same: `lasts 0.200 s, wanted 0.15 s` |
| Near tone set equal to plain | `pack_tones...`: `tone 1 is #7a5b3e, approved #4f3b28` |

| Suites | Raw `Tests:` line |
|---|---|
| `=inventory_ui` | `Tests: 41 total, 41 passed, 0 failed` |
| `=inventory_ui,realm_ui,payout_ui,foundation_ui,sanctum.layout,sanctum.party,echo_party,seam,stage_stop_ui` | `Tests: 262 total, 262 passed, 0 failed` |

### Tone C

Applied in `assets/theme/LivingTreeSystem.tres` (`StyleBoxFlat_item_panel_pack`, `_near`, `_heavy` `bg_color`). Tone only. No decoration.

| Tone | Hex | Cream `#F5E6D3` text contrast |
|---|---|---|
| Plain | `#7A5B3E` | 5.1:1 |
| Near full | `#4F3B28` | 8.6:1 |
| Full | `#120E0C` | 15.7:1 |

Sockets on the near-black tone: a full pack has no empty socket (all slots hold a tile), so no hole is ever drawn on `#120E0C`; the tiles sit on their own beds and read clearly (viewed in party details and on the path). The empty sockets (`#2B1F14`) show on the plain and near-full tones and read as holes there (viewed). The panel edge (`#241910`) on the dark path world is subtle but the panel is still clear. No token change needed. BLOCKED: none.

### Viewed (xvfb-run, `scripts/screenshot.gd`)

1280x720: Sanctum panel with the pack open; pack in party details at plain, near full and full (colour and grayscale); path view with the full pack; destroy confirmation for a stack with the count picker; leave confirmation; leave result card; a refusal line in the pack panel and in the details. 1920x1080 images were rendered for the same fixtures; I viewed none of them.

NOT viewed: any 1920x1080 image; motion (the flash and the reduced fade have tests only); the Sanctum panel refusal line; the stage-clear and defeat cards; a real display.

### RUN REQUEST (main chat)

1. Command: `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"` with Bash `timeout` 3600000.
2. Duration: about 18 minutes on 4 cores, about 31 on 2.
3. Files edited by the run: none in the checkout (`/tmp/echoes-vnext-sharded/`). No `trap`.
4. Verify: `git status --short` unchanged; no untracked `.import` file.
5. Read back: `COMBINED:` (expected 2730 + 3 = 2733, 0 failed), any shard log without `Tests:`, the `movement_fallback` merge line.

## OPEN — questions and assumptions

BLOCKED: none.
ASSUMED: 1. Typed forms kept as Jeff wrote them: `3 items can be lost` has no full stop while `1 item can be lost.` has one; `Placed in storehouse` has no full stop; `Made it through.` and `Items.` have one.
ASSUMED: 2. `R_PATH` ("organize") and `PATH_HINT` ("reorganize") differ as typed.
ASSUMED: 3. `WHERE_SANCT` is `Storehouse` and `WHERE_PACK` is `Pack` as picked, shown as the line under the tile in the details.
ASSUMED: 4. The leaf mark on tiles keeps no spoken label. The tile's own accessible name is its item name and kind, as before.
ASSUMED: 5. `DROP_*` hints show while dragging in the panel reason line; `moved_toast` has no on-screen use yet (approved text only).
ASSUMED: 6. The `ItemPanelPack*` theme names and the `last_pulse_seconds` test seam in `InventoryPanels.gd` are kept.

## Cleanup after QA round 10 (D-52)

Source: D-52, `step10-qa-report.md` F11-01 to F11-07. UI only. No `core/` file touched. No wording of a line that stays was changed. No commit. Compile check (`--quit`): 0 `SCRIPT ERROR` lines.

### Deleted (F11-01, Jeff: delete)

Grep of `ui/`, `tests/`, `scripts/`: none of the four was used by a screen. Only the fixture and the fixture test used them. The pack button's spoken name is unchanged: it is built in `PartyPackButton.gd:38` from `PARTY_PACK_BUTTON` and the count text, not from `pack_button()`.

| Id | Text | Also removed |
|---|---|---|
| `pack_button(count, total)` | Travel pack 2/4 | Fixture key `pack_button(2,4)`; its entry in the copy test |
| `moved_toast(to_box)` | Placed in pack. / Placed in storehouse | Fixture keys `moved_toast(pack)`, `moved_toast(sanctum)`; its entries in the copy test |
| `LEAVE_RISK_LABEL` | At risk | Fixture key |
| `ITEMS_GROUP_LABEL` | Items. | Fixture key |

Files: `ui/components/ItemUiText.gd`, `tests/fixtures/ItemUiApprovedCopy.json` (65 keys to 60), `tests/InventoryUITests.gd` (`_t_approved_copy`). The four lines stay in `copy-approval-jeff.md`. BLOCKED: none.

### Tests added (F11-02)

| Test | Pins |
|---|---|
| `inventory_ui/a_refused_button_shows_only_the_refusal_line` | On a path, `Move` and `Destroy` blocked: each reason line equals the bare refusal text and does not contain its button text; a full-storehouse refusal in the Sanctum shows the bare line |
| `inventory_ui/a_single_piece_shows_count_1_and_a_stack_its_count` | A single piece shows `Count: 1`, never `Count: 1 piece`; a stack shows `Count: x12 of 20` |

| Mutation (restored; `cmp` equal to the saved copy) | Result |
|---|---|
| Button name put back before the `Move` reason line | `a_refused_button_shows_only_the_refusal_line`: `%MoveReason shows 'Place in storehouse: While on the move...'` |
| `Count: 1` changed to `Count: 1 piece` | `a_single_piece_shows_count_1...`: `shows 'Count: 1 piece', wanted 'Count: 1'` |

| Suites | Raw `Tests:` line |
|---|---|
| `=inventory_ui` | `Tests: 43 total, 43 passed, 0 failed` |
| `=inventory_ui,realm_ui,payout_ui,foundation_ui,sanctum.layout,sanctum.party,echo_party` | `Tests: 182 total, 182 passed, 0 failed` |

Expected sharded total: 2733 (last verified) + 2 new tests = 2735. No test was removed (the copy test lost entries, not a test).

### Not changed

| Finding | Status |
|---|---|
| F11-03 (two refusal lines under two disabled buttons on a path) | Left for Jeff's UX redesign |
| F11-04 (full tone panel edge 1.31:1 on the dark path world) | Left for Jeff's UX redesign |
| F11-05 | Informational. No change |
| F11-06 | Informational. No change |
| F11-07 (pack button label looks dim in the screenshot harness) | Jeff checks it in his own play test |

### RUN REQUEST (main chat)

1. Command: `GODOT_BIN=/tmp/claude-0/godot-bin/godot scripts/run-tests-sharded.sh "$(git rev-parse --show-toplevel)"` with Bash `timeout` 3600000.
2. Duration: about 18 minutes on 4 cores, about 31 on 2.
3. Files edited by the run: none in the checkout (`/tmp/echoes-vnext-sharded/`). No `trap`.
4. Verify: `git status --short` unchanged; no untracked `.import` file.
5. Read back: `COMBINED:` (expected 2735, 0 failed), any shard log without `Tests:`, the `movement_fallback` merge line.

## OPEN — questions and assumptions

BLOCKED: none.
ASSUMED: 1. Deleting `pack_button()` does not change the spoken name; I confirmed the name is built in `PartyPackButton.gd`.
