# V2-ITEM-001a step 8 — QA report (UI build)

Status: COMPLETE. Reviewer: qa-verifier (independent; did not build this step). Written in STE.
Scope: the uncommitted tree against HEAD (17 changed tracked files, 35 untracked files). The backend (`core/`) is out of scope.

## 1. Verdict

**PASS WITH FINDINGS.**

| Count | Severity |
|---|---|
| 0 | Critical |
| 1 | High (F8-01: a new runtime `SCRIPT ERROR` makes an existing `realm_ui` guard blind) |
| 1 | Medium (F8-02: the path pack shows a wrong count and no tiles for finds of this path) |
| 7 | Low |
| 5 | Info |

The contract checks pass. The 27 new tests catch 16 of 19 mutations. F8-01 must be fixed before the commit. F8-02 needs a decision (UI fix or core field).

## 2. Findings (ranked)

| Id | Severity | Where | Failing scenario | Suggested fix |
|---|---|---|---|---|
| F8-01 | High | `ui/screens/venture/StageExploreScreen.gd:1651`; test `tests/Stage004SeamTests.gd:3274`, `:3343` | `realm_ui/target_minima_and_spatial_caps` builds the screen outside the tree. `_pack_hud` is null. `_apply_responsive_layout` stops with `SCRIPT ERROR` at :1651. The layout code after :1651 (back button, stage info, bottom HUD, directive badge) does not run in that test. Proof: badge width 204 to 300 gives NONE (M16). With the null access guarded, the same change fails the test (M16b). The suite still reports a pass. | Guard the four `_pack_hud` lines (`if _pack_hud != null:`), or move them to the end of the function. Set `_pack_hud` in the test like the other nodes (`stage_explore.set("_pack_hud", ...)`). |
| F8-02 | Medium | `ui/components/PartyPackButton.gd:30`; `ui/components/InventoryPanels.gd:349-366`; shot `/tmp/claude-0/qaui-shots/qa/invr_qa_path_found.png` | On a path, finds of this path are open item rows. Core counts them in `pack_load.carried` and `pack_free`, not in `pack_count`, and does not list them in `data.inventory.pack`. Pack 4, 1 carried piece, 3 finds: the button says `1 / 4 sockets`; the panel draws 3 empty sockets and says `Full. Nothing more fits.` The prototype (scenario 4) draws the finds in the pack with the whole leaf. | UI only: count `pack_load.carried` on the button; draw the `carry_home_preview.items_at_risk` rows with `source == "gathered"` as read-only tiles (whole leaf) in the free sockets. Alternative (core): list the open item rows in `data.inventory`. Jeff or the main chat decides. |
| F8-03 | Low | `InventoryPanels.gd:427-431`; shot `/tmp/claude-0/qaui-shots/1280/invr_path_used.png` | D-32 decision 5: a blocked discard shows `Let it go` disabled with a quiet reason line. The button keeps its normal look when blocked (`path_used`). Only the reason line shows. `Move` changes its look; `Let it go` does not. | Set a blocked look on `_letgo_button` when `_letgo_blocked` is not empty (same method as `_move_button`). |
| F8-04 | Low | `InventoryPanels.tscn` column in path mode; shot `/tmp/claude-0/qaui-shots/1280/invr_path.png` | At 1280x720 on the path view, the details area covers the `To the Sanctum` button and the right part of `Advance`. The panel stops the tap. The player must close the panel first. At 1920 the button is clear (`/tmp/claude-0/qaui-shots/1920/invr_path.png`). | In path mode, stop the column above `BottomHudRegion`, or let the column scroll. |
| F8-05 | Low | `InventoryPanels.gd:115`; shot `/tmp/claude-0/qaui-shots/qa/invr_qa_path_found.png` | On the read-only path view the empty details area says `Drag a piece to the other panel, or select it and press a Move button.` No drag and no move is possible there. | Show a path hint (for example `PATH_RULE`) in path mode. Wording is Jeff's. |
| F8-06 | Low | `ItemTileGlyphs.gd` at-risk brackets; crop `/tmp/claude-0/qaui-shots/crop_atrisk.png`; shot `1920/invr_leave_confirm.png` | On the dark leave confirmation the at-risk brackets are ink on a near-black card. They are almost invisible. The leaf is the only clear cue. The tile row and the risk line are left-aligned in a centred card. | Draw the brackets in cream on a dark surface (the row knows `set_on_dark`). Centre the row and the line. |
| F8-07 | Low | `InventoryPanels.gd:150-154`, `:195-202`; `StageExploreScreen.gd:635-638` | Probe f: a path snapshot without `data.inventory`, after one with it, keeps the pack panel open with the old 4 tiles. Probe f2: on a fresh path snapshot without it, `toggle_pack` opens an empty panel frame. The HUD pack button is never hidden in explore mode once shown. D-43 says the path view always carries the key, so this is a defensive gap only. | Close the panels and hide the HUD button when `data.inventory` is absent or empty. |
| F8-08 | Low (tests) | `tests/InventoryUITests.gd` | Three behaviours have no failing test: the 0.6 s `Let it go` lock (M8), the pulse on a transition into full (M15), and "a tap anywhere on the card finishes the item motion" (`ResolveScreen._input`, M19). | Add one assert for each: press `Let it go` inside 0.6 s after `note_discard_modal_closed()`; check `pulse()` is called on the empty-to-full snapshot change; send an `InputEventMouseButton` to `ResolveScreen._input` and check `is_running()` is false. |
| F8-09 | Low (tests) | `tests/InventoryUITests.gd:498-501`; suite exit | The step "A stack at its limit takes no more" drops a potion on a fibre stack and asserts `R_TYPE`. It tests a type mismatch twice; the stack-limit refusal through the panel is not tested (only `ItemMovePlan` at :593). The suite also prints `WARNING: ObjectDB instances leaked at exit` (not seen in `payout_ui` or `foundation_ui` alone). | Use a same-type stack at its limit and assert `R_STACK_LIMIT`. Find and free the leaked object (the test mounts or the lambdas of `_capture`). |
| F8-10 | Info | `ItemMovePlan.gd:75-78` | Probe c: a drop on a stack that sits past the container size predicts `merge`. Core checks `to_slot >= size` first and refuses `bad_slot`. The player sees the generic line. Only a malformed save can cause this. | Check `to_slot >= capacity` before the target check, as core does. |
| F8-11 | Info | `ItemUiText.gd:145-149`; shot `/tmp/claude-0/qaui-shots/qa/invs_qa_odd.png` | A row with an unknown `kind` and no `name` shows an empty name line and `Kind:` with no value. No crash. Core never sends an unknown kind (`check_entry`). | None needed now. |
| F8-12 | Info | `InventoryPanels.gd:232`; builder ASSUMED 8 | The 0.6 s lock also runs after `Keep it`. The source (mockup proposal 3) says "after confirm". The effect is small. | Jeff may accept as built. |
| F8-13 | Info | `ItemResultRow.tscn` `PreviewTag`; shot `/tmp/claude-0/qaui-shots/1280/invr_stage_clear_items.png` | The stage-clear `Preview. Read-only.` mark sits below the row. The prototype puts it as a tag at the card title. It is readable. | Jeff may accept as built. |
| F8-14 | Info | `InventoryPanels.gd:233`, `ItemResultRow.gd:187` | The UI guards use `Time.get_ticks_msec()`; the open windows use Tweens. `AGENTS.md` forbids wall clock in `core/` only, so this is allowed. The two time sources are mixed. Tests reach the guards by setting private fields. | None needed. |

## 3. Prototype conformance (D-33 to D-47, prototype v2)

| Rule | Result | Evidence |
|---|---|---|
| Rail button: next to the (absent) Sanctum button, before Party | PASS (builder ASSUMED 1) | test `rail_button_sits_before_party...`; shots `1280/invs_sanctum.png` |
| Rail button enabled only on `flow.sanctum`, `flow.echo_party`; selected look while open | PASS | same test; shots show `RailButtonSelected` |
| Each panel opens alone; no screen starts with a panel open (D-35) | PASS | test `panels_start_closed_and_open_alone`; M1 fails it |
| Pack opens only from the party pack button or `Show pack`; side by side only when both are opened | PASS | `_t_party_shell`, `_t_open_alone`; shot `qa/invs_qa_party_both.png` |
| Pack panel: no counts, no bead gauge (D-39); single count on the pack button | PASS (but see F8-02 on a path) | `_t_pack_panel`; M2 fails it |
| Heavy tone, strap line, consequence word at near-full and full (D-36) | PASS | shots `1280/invs_both_full.png`, `qa/invs_qa_small.png` |
| Pulse into full (0.4 s; reduced 0.15 s) | PASS by reading; untested (F8-08) | `InventoryPanels.gd:370-386` |
| Departure line only with a non-empty pack | PASS | `_t_pack_button`; M12 fails it |
| Moves both ways | PASS | `_t_move_button`, `_t_drops` |
| Reorder into an empty slot only; no swap | PASS | `_t_refused_drops`; M4 fails it |
| Merge onto a same-type stack with room; refused at the limit | PASS | `_t_move_plan`; probe a (partial merge predicted as `merge`, core keeps the rest) |
| Across containers: first free slot, or the target slot when empty | PASS | `_t_drops`; core `_move_entry` agrees |
| `Move to ...` and `Let it go` buttons with reason lines | PASS | shots `1280/invs_both_full.png` |
| Path view read-only; one discard on a pack piece with its reason line | PASS (F8-03 look) | `_t_path_view`; M7 fails it |
| `Let it go` modal: default focus `Keep it` | PASS | M13 fails `_t_discard_modal` |
| Esc, Back, B, outside tap = `Keep it` | PASS | `_t_discard_modal` (Esc via `ui_cancel`, which includes joypad B by Godot default) |
| 0.25 s open window | PASS | M3 fails `_t_discard_modal` |
| 0.6 s lock after confirm | PASS by probe k; untested (F8-08) | probe k |
| Count picker: default whole stack, min 1, max count | PASS | M14 fails `_t_discard_modal`; shot `qa/invs_qa_modal.png` |
| No hold, swipe or drag confirms | PASS | modal has only press handlers |
| Result cards: one row, survivors then lost ghosts; no place word; no lane title (D-42) | PASS | M5 fails `_t_result_row`; shots `1280/invr_leave_result.png`, `invr_defeat_items.png` |
| First tap finishes the motion; Continue guarded 0.25 s | PASS (tap-anywhere untested, F8-08) | M10 fails 2 tests; M19 NONE |
| Sequence cap 2.4 s | PASS | `_t_row_motion` checks 1 to 14 tiles |
| Reduced motion 0.15 s fade via `StopMarkMotion.reduced` | PASS | M11 fails `_t_reduced_motion` |
| Stage-clear preview with read-only mark | PASS (F8-13) | M18 fails `_t_resolve_cards`; shot `invr_stage_clear_items.png` |
| Leave confirmation at-risk row; 0.25 s Confirm window only with tiles | PASS (F8-06 look) | M17 fails `_t_leave_confirm` |

## 4. Rendered screens

Command: `xvfb-run -a -s '-screen 0 WxHx24' godot --path . --rendering-driver opengl3 --resolution WxH --script res://scripts/screenshot.gd -- <fixture> <dir>`. Every run: rc 0, 0 `SCRIPT ERROR`. Paths are under `/tmp/claude-0/qaui-shots/`.

| Screen | Size | Path | Result | Defects |
|---|---|---|---|---|
| Sanctum panel alone, piece selected | 1280, 1920 | `1280/invs_sanctum.png`, `1920/invs_sanctum.png` | PASS | none |
| Sanctum panel, empty details | 1280 | `1280/invs_sanctum_empty_details.png` | PASS | none |
| Sanctum + pack side by side | 1280, 1920 | `1280/invs_both_panels.png`, `1920/invs_both_panels.png` | PASS | Text of the card behind shows in the gap between panels (cosmetic) |
| Stack with count capsule | 1280 | `1280/invs_stack_selected.png`, `crop_capsule1280.png` | PASS | Capsule text 12 px: at the limit |
| Both full (heavy, strap, word, `Full`, gold with ink keyline) | 1280, 1920 | `1280/invs_both_full.png`, `1920/invs_both_full.png` | PASS | none |
| Party prep, pack closed | 1280 | `1280/invs_party_closed.png` | PASS | none |
| Party prep, pack open | 1280, 1920 | `1280/invs_party_pack.png`, `1920/invs_party_pack.png` | PASS | Party panels 200 wide at 1280 (ASSUMED 4) |
| Party prep, Sanctum + pack (QA) | 1280 | `qa/invs_qa_party_both.png` | PASS | Sanctum panel covers the echo list |
| Path view, pack open | 1280, 1920 | `1280/invr_path.png`, `1920/invr_path.png` | FINDING | F8-04 |
| Path view, discard used | 1280 | `1280/invr_path_used.png` | FINDING | F8-03 |
| Path view, finds of this path (QA) | 1280 | `qa/invr_qa_path_found.png` | FINDING | F8-02, F8-05 |
| Leave confirmation | 1280, 1920 | `1280/invr_leave_confirm.png`, `1920/invr_leave_confirm.png` | FINDING | F8-06 |
| Leave result; mid motion | 1280, 1920 | `1280/invr_leave_result.png`, `1280/invr_leave_result_midmotion.png`, `1920/invr_leave_result.png` | PASS | none |
| Defeat card | 1280, 1920 | `1280/invr_defeat_items.png`, `1920/invr_defeat_items.png` | PASS | none |
| Stage-clear card (not viewed by the builder) | 1280, 1920 | `1280/invr_stage_clear_items.png`, `1920/invr_stage_clear_items.png` | PASS | F8-13 |
| Empty Sanctum and pack (QA) | 1280 | `qa/invs_qa_empty.png` | PASS | none |
| Sanctum 30 / pack 8 (QA) | 1280 | `qa/invs_qa_big.png` | PASS | 6 columns, 2 socket rows, nothing clipped |
| Sanctum 8 / pack 2 (QA) | 1280 | `qa/invs_qa_small.png` | PASS | none |
| Nameless row, unknown kind (QA) | 1280 | `qa/invs_qa_odd.png` | PASS | F8-11 |
| Discard modal with count picker (QA) | 1280 | `qa/invs_qa_modal.png` | PASS | none |
| Lost ghost tiles | 1280 | `1280/invr_leave_result.png`, `1280/invr_defeat_items.png` | PASS | dashed outline only on lost tiles |
| Grayscale copies | 1280 | `1280_gray_invs_both_full.png`, `1280_gray_invr_leave_result.png`, `1280_gray_invr_path.png`, `1280_gray_invr_defeat_items.png` | PASS | Pack and Sanctum differ without colour; ghosts read by the dashed outline |

Visual rules: text 12 px or more at 1280 (theme sizes 12 to 20; no override below 12 in the new scenes). Tap targets 48 px or more (close 48x48, buttons 96x48, picker 48x48, modal buttons 160x56, rail 48x56, slots 72). Gold only with an ink keyline (gold `Move`, gold at-limit capsule, gold full ledger). No forbidden colour in the item styles (`_t_theme_colours`; glyphs read theme colours only). At most 3 marks per tile (pips, notch, leaf; a stack has capsule and leaf). Dashed outline only for lost.

QA fixtures were added to `scripts/screenshot.gd` for one batch only, then restored (`cp`, `cmp` equal).

## 5. Contract checks

| Check | Result | Evidence |
|---|---|---|
| `ui/` reads no save, `FlowContext`, `FlowRuntime`, core service | PASS | grep of new files and of the `+` lines of the changed ui files: 0 hits; `_t_source_grep` |
| Snapshot-driven | PASS | panels read `data.inventory`; cards read `data.items` and `packs_lost` params; leave modal reads `carry.items_at_risk` |
| UI-local open state only; no new flow state, no snapshot type, no `actions` slot | PASS | `InventoryPanels.gd:83-102`; `AGENTS.md` Shell Routing note matches |
| Dispatch path | PASS | panels and modal emit `action_requested`; shells forward to `AppRoot._on_ui_action_selected` -> `runtime.dispatch` |
| `inventory.move.apply` payload `{ from, slot, to, to_slot }` | PASS | `InventoryController.handle_move` :85-102 reads exactly these; `to_slot` -1 = lowest free |
| `inventory.discard.apply` payload `{ from, slot }` + `count` for a stack | PASS | `handle_discard` :43-82; count 1..quantity, absent = whole stack |
| No per-piece actions in the snapshot | PASS | actions built in UI; `_t_move_button` checks no `slot` key on the action |
| `ui.toggle_pack_panel` never reaches `FlowRuntime` | PASS | intercept `SanctumShell.gd:476`, `RealmShell.gd:572`; `_t_party_shell`, `_t_discard_shells` |
| UI move prediction equals core rules | PASS except F8-10 | `ItemMovePlan.plan` vs `InventoryService._move_entry` :629-682 |
| `scripts/screenshot.gd` change additive | PASS | one condition widened (`invs_` prefix), new fixtures, new `inv:` step, two helpers |
| `scripts/test-shard-map.sh`, `AGENTS.md` counts | PASS | 144 -> 145 in 3 places; `inventory_ui` in shard13; shard map OK |
| Changed existing test files | none | `git diff --stat` lists no file under `tests/` |
| Theme change | PASS | about 766 added lines; no new colour token (builder); colour scan passes |

## 6. Wording check

| Check | Result |
|---|---|
| Every new string in `ui/components/ItemUiText.gd`, each line `# PLACEHOLDER` | PASS (`_t_placeholders`; read by hand) |
| Literal text in the new `.tscn` files | Only `×`, `−`, `+`, `x1` (test-enforced) |
| String literals in the new `.gd` files | Only format strings (`x%d`, `%s: %s`) and chevrons `<` `>`; no words |
| No item id or type id as text | PASS (`_t_no_ids`, `_t_slots_and_names`; probe of nameless row) |
| No place word on result cards; no "home" or "stage" in the new strings | PASS (M5 fails the test; grep of `ItemUiText.gd` for home/stage: 0 hits) |
| Path hint wording in empty details | F8-05 |

## 7. Probes (temporary probe test in `tests/InventoryUITests.gd`; restored and `cmp` equal)

| Probe | Result |
|---|---|
| a. Merge 15 onto 10 of 20 (same type) | `merge` to slot 0. Core merges 10 and keeps 5. Correct. |
| b. Target slot 25 of 20; to_slot -5 same box; from slot -3 | `bad_slot`; `none`; `unknown_entry`. No dispatch. |
| c. Merge onto a stack past the size | `merge` predicted; core `bad_slot` (F8-10) |
| d. Cross-container drop on an occupied slot | `slot_taken` (core agrees) |
| Empty slot / occupied refusal / merge at limit / across / same slot / path read-only | covered by `_t_move_plan` and `_t_path_view` (all asserted) |
| Count picker bounds | 1 to count_max (`_t_discard_modal`) |
| e. Modal presented twice | window resets (`armed` false), count back to whole stack, focus `Keep it` |
| Double confirm | one action only (`_t_discard_modal`; `_sent` guard) |
| j. Two `Move` presses before the snapshot | one dispatch; second press silent |
| Timers time source | UI uses `Time.get_ticks_msec` and Tweens; allowed in `ui/` (F8-14) |
| i. Snapshot change with selection | slot emptied: selection cleared, empty details; other piece in the slot: selection follows the slot |
| Sizes 2/8 and 8/30 | `_t_sizes` (8/2, 20/4, 30/6, past-size slot); renders `qa/invs_qa_big.png` (30/8), `qa/invs_qa_small.png` (8/2) |
| Missing `name` | kind word shown (`_t_slots_and_names`, `_t_result_row`) |
| Unknown `kind` | no crash; blank name (F8-11) |
| g. Empty snapshot `{}` | panels closed, column hidden |
| f. Path view without `data.inventory` | no crash; stale or empty pack panel (F8-07) |
| u. Party prep, Sanctum panel only | right inset 388; details column shows at the right |
| k. `Let it go` inside 0.6 s after the modal closed | no second modal |

## 8. Mutation checks (one at a time; each restored with `cp` and proved with `cmp`)

| # | Mutation | File | Failing test | Restored |
|---|---|---|---|---|
| M1 | `toggle_sanctum` also opens the pack | `InventoryPanels.gd:191` | `panels_start_closed_and_open_alone` (+2) | cmp OK |
| M2 | Count in the pack panel title | `InventoryPanels.gd:354` | `pack_panel_shows_no_counts_and_level_words` | cmp OK |
| M3 | No 0.25 s modal window | `ItemDiscardModal.gd:74` | `discard_modal_focus_window_count_and_cancel_keys` | cmp OK |
| M4 | Predicted refusal sent anyway (swap allowed) | `InventoryPanels.gd:525` | `refused_drops_send_nothing_and_show_the_reason` | cmp OK |
| M5 | Place word on result card | `ItemUiText.gd:87` | `result_row_is_one_row_with_survivors_and_ghosts` | cmp OK |
| M6 | Pack size hard-coded 4 | `ItemMovePlan.gd:17` | `panel_sizes_come_from_the_snapshot_and_grow` | cmp OK |
| M7 | Plan ignores the path (path view would move) | `ItemMovePlan.gd:68` | `move_plan_follows_the_core_rules`, `path_view_is_read_only_with_one_discard` | cmp OK |
| M8 | No 0.6 s `Let it go` lock | `InventoryPanels.gd:500` | **NONE** (F8-08) | cmp OK |
| M9 | No mode check in `_do_move` | `InventoryPanels.gd:518` | NONE (expected: the plan still refuses; redundant guard) | cmp OK |
| M10 | No 0.25 s Continue guard after final | `ItemResultRow.gd:187` | `result_row_motion_cap...`, `resolve_cards_show_items...` | cmp OK |
| M11 | Reduced fade 0.5 s | `ItemResultRow.gd:21` | `reduced_motion_is_a_short_fade` | cmp OK |
| M12 | Departure line always | `PartyPackButton.gd:36` | `party_pack_button_count_and_departure_line` | cmp OK |
| M13 | Default focus `Let it go` | `ItemDiscardModal.gd:81` | `discard_modal_focus_window...` | cmp OK |
| M14 | Picker default 1 | `ItemDiscardModal.gd:64` | `discard_modal_focus_window...` | cmp OK |
| M15 | No pulse into full | `InventoryPanels.gd:378` | **NONE** (F8-08) | cmp OK |
| M16 | Directive badge width 300 | `StageExploreScreen.gd:57` | **NONE** in `realm_ui` (F8-01) | cmp OK |
| M16b | M16 plus null guard on `_pack_hud` | `StageExploreScreen.gd:57`, `:1651` | `realm_ui/target_minima_and_spatial_caps` fails (proves F8-01) | cmp OK |
| M17 | Leave Confirm without window | `ReturnHomeModal.gd:73` | `leave_confirmation_shows_at_risk_tiles_and_guards_confirm` | cmp OK |
| M18 | Preview flag inverted | `ResolveScreen.gd:840` | `resolve_cards_show_items_and_guard_continue` | cmp OK |
| M19 | Tap anywhere does not finish the item motion | `ResolveScreen.gd:826` | **NONE** in `inventory_ui,payout_ui` (F8-08) | cmp OK |

## 9. Test integrity (27 tests in `inventory_ui`)

| Judgement | Tests |
|---|---|
| Can fail, proved by a mutation | `panels_start_closed...`, `pack_panel_shows_no_counts...`, `discard_modal_focus_window...`, `refused_drops...`, `result_row_is_one_row...`, `panel_sizes...`, `move_plan...`, `path_view...`, `result_row_motion_cap...`, `resolve_cards...`, `reduced_motion...`, `party_pack_button_count...`, `leave_confirmation...`, `unchanged_snapshot_after_a_move...` (fails under M1) |
| Can fail by reading (asserts on values the code sets) | `rail_button...`, `tiles_sit_in_their_slots...`, `no_id_or_core_text...`, `tile_marks_shapes...`, `stack_tile...`, `placeholder_strings...`, `move_button_dispatches...`, `drops_reorder_merge...`, `refusal_keys_map...`, `discard_flows_...both_shells`, `party_pack_button_is_ui_local...`, `new_ui_files_never_read...`, `theme_additions...` |
| Weak spots | F8-08 (3 behaviours untested); F8-09 (stack-limit step tests a type mismatch); drag tests call `_can_drop_data`/`_drop_data` directly, not a real engine drag; guards are reached by setting private fields (`_armed`, `_final_msec`, `_letgo_lock_until`) |
| Effect on existing tests | F8-01: an existing `realm_ui` guard became blind. No existing test file changed. |

## 10. BLOCKED items of the builder

| Item | Real? | Evidence | Player impact | Smallest core change (not made) |
|---|---|---|---|---|
| 1. No refusal reason key reaches the UI | Yes | `InventoryController._deny` :118-122 returns `FlowActionOutcome.error_outcome(reason)`; `FlowRuntime._apply_action_outcome` :1163 never reads `error_code`; `AppRoot._on_ui_action_selected` renders the unchanged `last_snapshot` | Low. The UI predicts every refusal that the snapshot can show (path, full, slot taken, type, limit, used, not in pack). Only core-only cases (`bad_state`, `equipped`, `count_range`, past-size `bad_slot`) show the generic `That did not work. Nothing changed.` | In `InventoryController._deny`, return a rebuilt snapshot of the current screen (the `_rebuilt` path) with a one-shot `data.inventory.refused = { "action": <type>, "reason_key": <key> }`, no save request. The key appears only on a refusal, so no recorded hash moves. |
| 2. Report rows carry no `name` | Yes | `EarningsService.at_risk_row` :236-238 and `report_row` :243-248 hold `type_id, kind, grade, quantity, source, mark_index`; only `InventoryService.snapshot` :173, :184 adds `name` via `_name_of(cfg, type_id)` | Medium once real items exist. On the leave confirmation and the result cards, a tap shows `Gear` or `Relic`, while the panel shows the piece name. With two gear pieces the player cannot tell which one was lost. Placeholder items today. | Add an optional `item_name: String = ""` to `at_risk_row` (and pass it through `report_row`); callers pass a public `InventoryService.name_of(cfg, type_id)`. Write `name` only when not empty. Rows exist only with items, so item-free snapshots and hashes do not change. The UI already reads `row.name`. |

## 11. Regression

| Run | Raw line |
|---|---|
| `--check-only --quit` (start and end) | 0 `SCRIPT ERROR` |
| `scripts/check-shard-map.sh` | `SHARD MAP CHECK: OK (145 registered suites, each in exactly one of 13 shards or the merge step).` |
| `=inventory_ui,snapshot_fingerprint,foundation_ui,realm_ui,payout_ui` (start and end) | `Tests: 124 total, 124 passed, 0 failed` (plus 2 runtime `SCRIPT ERROR`, F8-01) |
| `=stage_stop_ui,sanctum.layout,sanctum.party,sanctum.summon,summon_price_ui,combat_ui,pending_result,snapshot_contract,snapshot_purity` | `Tests: 204 total, 204 passed, 0 failed` |
| `=inventory_ui` alone | `Tests: 27 total, 27 passed, 0 failed` (plus `ObjectDB instances leaked at exit`, F8-09) |
| `=payout_ui`; `=foundation_ui` | `Tests: 58 total, 58 passed, 0 failed`; `Tests: 17 total, 17 passed, 0 failed` |

## 12. Evidence — tree state

| Item | Value |
|---|---|
| `git diff \| sha256sum` before | `ef77ae3ba11db88e18aad5fa3ce5a6cf2308c53112f96721245706e907805d78` |
| `git diff \| sha256sum` after the resume (re-proof) | `ef77ae3ba11db88e18aad5fa3ce5a6cf2308c53112f96721245706e907805d78` |
| `git diff \| sha256sum` at the end | `ef77ae3ba11db88e18aad5fa3ce5a6cf2308c53112f96721245706e907805d78` |
| Untracked files (excluding this report) | 35 before, 35 after; checksum lists `/tmp/claude-0/qaui_untracked_before.txt` and `/tmp/claude-0/qaui_untracked_now.txt` are identical (`diff` empty) |
| Untracked `.import` files | 0 |
| Files changed and restored, each proved with `cmp` at restore | `scripts/screenshot.gd`; `ui/components/InventoryPanels.gd` (M1, M2, M4, M8, M9, M15); `ui/overlays/ItemDiscardModal.gd` (M3, M13, M14); `ui/components/ItemUiText.gd` (M5); `ui/components/ItemMovePlan.gd` (M6, M7); `ui/components/ItemResultRow.gd` (M10, M11); `ui/components/PartyPackButton.gd` (M12); `ui/screens/venture/StageExploreScreen.gd` (M16, M16b); `ui/overlays/realm/ReturnHomeModal.gd` (M17); `ui/screens/venture/ResolveScreen.gd` (M18, M19); `tests/InventoryUITests.gd` (probe) |
| Re-proof after the resume | `cmp tests/InventoryUITests.gd /tmp/claude-0/qaui-backup/iut.orig`: equal. The tracked hash equal and the untracked checksum list equal prove that every other file is back to its original. |
| Commits, stash, checkout | none |

## OPEN — questions and assumptions

- BLOCKED: F8-02 needs a decision. Option A (UI only): the path pack draws finds of this path from `carry_home_preview.items_at_risk` and counts `pack_load.carried`. Option B (core): list open item rows in `data.inventory`. I made no change.
- BLOCKED: the two builder BLOCKED items need Jeff's approval for a core change (section 10). Item 2 (`name` on report rows) has the larger player impact.
- ASSUMED: F8-01 is High because it silently disables an existing layout guard, not because the game breaks. In the running game `_pack_hud` is never null.
- ASSUMED: the rail button position (first, before Party) is acceptable, because the game rail has no `Sanctum` button (builder ASSUMED 1). Jeff did not see it rendered.
- ASSUMED: the 1280 overlap of the path details area over `To the Sanctum` (F8-04) matters, because the prototype path stand-in had no bottom action bar to compare with.
- ASSUMED: the ObjectDB leak warning (F8-09) is new with `inventory_ui`. I did not run the suite at HEAD (no checkout allowed); `payout_ui` and `foundation_ui` alone show no warning.
- ASSUMED: font size 12 for the count capsule meets "12 px or more at 1280". It is at the limit.
