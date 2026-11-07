# V2-ITEM-001a step 8: inventory UI build (ui-ux-designer)

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
