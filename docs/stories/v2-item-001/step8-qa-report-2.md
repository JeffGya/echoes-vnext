# V2-ITEM-001a step 8 — QA report 2 (UI fix round, D-48)

Status: COMPLETE. Reviewer: qa-verifier (independent; did not build this step). Written in STE.
Scope: the uncommitted tree against HEAD `eada9e7` (12 changed tracked files, 0 untracked files before this report). The core is out of scope.

## 1. Verdict

**PASS WITH FINDINGS.**

| Count | Severity |
|---|---|
| 0 | Critical |
| 0 | High |
| 1 | Medium (F9-01: a refusal snapshot on the path view moves both panels above the top edge of the screen) |
| 2 | Low (F9-02, F9-03: test gaps) |
| 4 | Info |

All round-1 items in scope are fixed. 16 of 20 mutations fail a test. The 4 that survive are listed. F9-01 is new in this round. Fix it before the commit, or Jeff accepts it as rare.

## 2. Round-1 findings status

| Id | Status | Evidence |
|---|---|---|
| F8-01 | FIXED | `realm_ui`: `Tests: 20 total, 20 passed, 0 failed`, 0 `SCRIPT ERROR`. M01 (badge 204 -> 300) fails `realm_ui/target_minima_and_spatial_caps` ("StageExplore directive badge is not capped"). The `tests/Stage004SeamTests.gd` change is the one `_pack_hud` setup line (+1, -0). |
| F8-03 | FIXED | `ItemButtonBlocked` on `Move` and `Let it go` (`InventoryPanels.gd:446`). Grayscale: blocked label 3.98:1, active label 11.4:1, thin light border on the blocked button (`/tmp/claude-0/qaui2-shots/gray_path_buttons_1280.png`). The reason lines stay at full contrast. M06 fails a test. See F9-05 (Info). |
| F8-04 | FIXED | The path panels sit side by side (`InventoryPanels.gd:300`). 1280: panels y 80 to 385, bottom HUD top y 548. 1920: panels y 100 to 480, bottom HUD top y 865. `To the Sanctum` is clear at both sizes. M08 and M09 fail a test. See F9-01. |
| F8-05 | FIXED | `PATH_HINT` "On a path, pieces cannot be moved." on the path. The Sanctum keeps `DETAILS_HINT`. M07 fails a test. |
| F8-06 | FIXED | Cream brackets with an ink keyline outside the bed. The row and the lines are centred. Measured cream (245,230,211) on card (16,14,26): **15.59:1** (claim 15.7:1; the difference is rounding). The ink keyline (61,40,23) is present. The brackets are not gold, so the gold keyline rule does not apply. No test (M18, M19 survive; visual only). See F9-04 (Info). |
| F8-07 | FIXED | Probe render `qa/qa_path_noinv_1280x720.png`: after a path snapshot without `data.inventory`, the pack panel is closed, `toggle_pack` opens nothing, and the HUD pack button is hidden. M10 and M11 fail a test. The HUD button hide has no test (M12 survives, F9-03). |
| F8-08 | FIXED | Three new tests. M13 (lock), M14 (pulse), M15 (tap finish) each fail their test. |
| F8-09 | FIXED | The stack step uses a same-type stack at 20 of 20 and expects `R_STACK_LIMIT`. M16 fails 2 tests. Leak: `=inventory_ui --verbose` prints no leak line. M20 (old `await create_timer` put back) prints `ObjectDB instances leaked at exit` with 2 `SceneTreeTimer` instances. This proves the cause and the fix. |
| F8-02 | DEFERRED by Jeff (D-48) | Not checked. |
| Refusal key (D-48) | PASS with F9-01, F9-02 | Section 4. |
| Names (D-48) | PASS | Section 4. |

## 3. New findings (ranked)

| Id | Severity | Where | Concrete scenario | Suggested fix |
|---|---|---|---|---|
| F9-01 | Medium | `ui/components/InventoryPanels.gd:162-172` (refusal branch, then `_render()`); `Work` node, `InventoryPanels.tscn:32`; shots `/tmp/claude-0/qaui2-shots/qa/qa_path_refused_1280x720.png`, `/tmp/claude-0/qaui2-shots/qa/qa_path_refused_1920x1080.png` | Path view, pack open, a piece selected. A snapshot arrives with `data.inventory.refused` (tested with `path_used` and `bad_state`). `Work` grows to 1213 px tall at y = -246.5 (1280x720). Both panels move to y = -166.5. The panel titles, the tiles and the close button go above the screen edge. At 1920 the shift is about 222 px. The state stays after the line hides (dump 4 s later: no change). The next snapshot restores the layout. Controls without the shift: a second plain path snapshot; a local press on the blocked `Let it go`; a refusal with no selection; Sanctum and party prep refusals in the Sanctum harness. | Find why `Work` takes a large size during the refusal render. Candidates: `_flash` shows the line before `_render()` rebuilds the grid; an autowrap label is measured at width 0 in the new horizontal path column. Try `_render()` before `_flash`, or reset the `Work` size after the render. Add a test: after a path refusal snapshot, the `Work` rect stays inside the viewport. |
| F9-02 | Low (test) | `InventoryPanels.gd:167` (`reason_text(reason, _last_to)`); `tests/InventoryUITests.gd` `_t_refused_key` | M05 (`_last_to` replaced by `""`) passes all tests. A core `container_full` refusal on a move to the pack then says "The Sanctum is full". The test computes the expected line with the same `_last_to`, which is empty at that point, so it cannot see the wrong box. M04 (`_refusal_box` ignores `_last_to`) also passes, because `_do_move` already sets `_sel_box` to the target. | Add one assert: after a move to the pack, a `container_full` refusal shows `R_PACK_FULL` in the pack panel. |
| F9-03 | Low (test) | `ui/screens/venture/StageExploreScreen.gd:636` | M12 (HUD pack button always visible) passes `inventory_ui,realm_ui,seam` (99 tests). The F8-07 HUD hide has no test. The probe render shows that the behaviour is correct today. | Add one assert in a path-view test: a snapshot without `data.inventory` hides `%PackHudButton`. |
| F9-04 | Info | `ItemTileGlyphs.gd:204`; crop `/tmp/claude-0/qaui2-shots/crop_brackets_1920.png` | On the leave confirmation the brackets of neighbour tiles touch. Between two tiles they read as one double bracket "][". The risk is still clear. | Increase the tile gap on dark, or reduce `out` from 3 to 1. Jeff may accept as built. |
| F9-05 | Info | `InventoryPanels.gd:446` | A blocked button is a style only. The button stays enabled and focusable, so a press shows the reason line (correct). A screen reader or a focus ring treats it as active. Label contrast is 3.98:1 (WCAG exempts inactive controls). | None needed now. |
| F9-06 | Info | `InventoryPanels.gd:103` | `_last_to` is never reset (not in `_reset_local`). It holds a box name, not a refusal or a name. No wrong result found, because every move sets it first. | Reset it in `_reset_local` for clarity. |
| F9-07 | Info | `objective/skipped_pays_completed_only`, `core/economy/EarningsService.gd:316` | `SCRIPT ERROR ... 'warn' in base 'Nil'` prints in `=objective` (`Tests: 26 total, 26 passed, 0 failed`). PRE-EXISTING on the base commit (the main chat proved it). Not part of this round. | Out of scope. |

## 4. Refusal key and names (D-48)

| Check | Result | Evidence |
|---|---|---|
| UI key list equals the core list | PASS | Core keys (`InventoryController.gd`, `InventoryRules.gd`, `InventoryService.gd`): `bad_payload`, `not_in_sanctum`, `not_found`, `not_unique`, `bad_box`, `unknown_entry`, `path_open`, `not_in_pack`, `no_stage`, `path_used`, `bad_state`, `count_range`, `equipped`, `bad_slot`, `no_change`, `slot_taken`, `type_mismatch`, `stack_limit`, `container_full` (19). `_t_refused_key` sends all 19. 14 have their own line. `bad_payload`, `bad_box`, `bad_state`, `not_unique`, `no_stage` and unknown keys use `R_UNKNOWN`. |
| Every snapshot clears the line first | PASS | `InventoryPanels.gd:162`; M03 fails the test |
| Key present, then absent | PASS | `_t_refused_key` (19 keys, both panels open); M02 and M03 fail it |
| Key on the path view | PASS (line), FINDING (layout) | The line shows in the pack panel (`qa/qa_path_refused_*.png`). The light line on the dark pill measures 6.26:1 at 1920. Layout: F9-01 |
| Both panels open | PASS | `/tmp/claude-0/qaui2-shots/1920/invs_refusal.png`, `/tmp/claude-0/qaui2-shots/1280/invs_refusal_slot.png` |
| UI stores no refusal | PASS | The line is label text. It clears at the next snapshot or after 3.2 s. Only the box name `_last_to` is kept (F9-06) |
| Names on result tiles (tap) | PASS | `qa/qa_leave_result_named.png`, `qa/qa_leave_result_lost.png` ("Test gear D, Gear, Grade 1: Lost") |
| Names on defeat and stage clear | PASS | `qa/qa_defeat_named.png` ("Test relic B, Relic, Grade 3: Lost"), `qa/qa_stage_clear_named.png` ("Test potion C, Consumable, x5: Survived") |
| Names on the leave confirmation | PASS | `1920/qa_leave_confirm_named.png` ("Test relic B, Relic, Grade 3") |
| Fallback to the kind word | PASS | `qa/qa_leave_confirm_nameless.png` ("Consumable, x5"), `qa/qa_leave_result_nameless.png`; M17 fails 4 tests |
| UI stores no name | PASS | `ItemUiText.display_name` reads `row.name` from the snapshot row each time |

## 5. Rendered screens (all under `/tmp/claude-0/qaui2-shots/`; every run rc 0, 0 `SCRIPT ERROR`)

Command: `xvfb-run -a -s '-screen 0 WxHx24' godot --path . --rendering-driver opengl3 --resolution WxH --script res://scripts/screenshot.gd -- <fixture> <dir>`. The `qa_*` and `invs_qa_*` fixtures were added to `scripts/screenshot.gd` for one batch at a time, then restored (`cp`, `cmp` equal, 7 batches).

| Screen | Size | Path | Result |
|---|---|---|---|
| Path, pack open, details beside | 1280, 1920 | `1280/invr_path.png`, `1920/invr_path.png` | PASS. Info: the dark pack panel stretches to the details height (empty dark area below the tiles) |
| Path, discard used, disabled `Let it go` | 1280, 1920 | `1280/invr_path_used.png`, `1920/invr_path_used.png` | PASS |
| Leave confirmation | 1280, 1920 | `1280/invr_leave_confirm.png`, `1920/invr_leave_confirm.png` | PASS (F9-04) |
| Leave confirmation, name on tap | 1920, 1280 | `1920/qa_leave_confirm_named.png`, `qa/qa_leave_confirm_named.png`, `qa/qa_leave_confirm_nameless.png` | PASS |
| Leave result with names | 1920, 1280 | `1920/invr_leave_result.png`, `qa/qa_leave_result_named.png`, `qa/qa_leave_result_lost.png`, `qa/qa_leave_result_nameless.png` | PASS |
| Defeat, stage clear with names | 1280 | `qa/qa_defeat_named.png`, `qa/qa_stage_clear_named.png` | PASS |
| Stage-clear result card | 1920 | `1920/invr_stage_clear_items.png` | PASS |
| Refusal line, both panels (Sanctum) | 1280, 1920 | `1280/invs_refusal.png`, `1920/invs_refusal.png`, `1280/invs_refusal_slot.png`, `1920/invs_refusal_slot.png` | PASS |
| Refusal line on the path | 1280, 1920 | `qa/qa_path_refused_1280x720.png`, `qa/qa_path_refused_1920x1080.png` | **F9-01** |
| Path snapshot without inventory | 1280, 1920 | `qa/qa_path_noinv_1280x720.png`, `qa/qa_path_noinv_1920x1080.png` | PASS |
| Grayscale buttons | 1280 | `gray_path_buttons_1280.png` | PASS |

NOT covered: any motion in real time (the pulse, the card sequence and the 0.6 s lock have tests only); the real bottom HUD labels (the fixture snapshot has no actions, so `Advance` is an empty gold bar; its rectangle is real); the compact profile; F9-01 on a real device.

Pre-existing, not this round: at 1280 the result cards and the leave confirmation overlap the top of the echo cards by about 8 to 40 px.

## 6. Mutation checks (one at a time; each restored with `cp` and proved with `cmp`)

| # | Mutation | File:line | Failing test | Restored |
|---|---|---|---|---|
| M01 | badge width 204 -> 300 | `StageExploreScreen.gd:57` | `realm_ui/target_minima_and_spatial_caps` | cmp EQ |
| M02 | refused branch disabled | `InventoryPanels.gd:163` | `core_refusal_key_shows_its_line_for_one_snapshot` | cmp EQ |
| M03 | `_clear_lines()` removed | `InventoryPanels.gd:162` | same | cmp EQ |
| M04 | `_refusal_box` ignores `_last_to` | `InventoryPanels.gd:567` | NONE (redundant; F9-02) | cmp EQ |
| M05 | `reason_text(reason, "")` | `InventoryPanels.gd:167` | NONE (F9-02) | cmp EQ |
| M06 | no blocked look on `Let it go` | `InventoryPanels.gd:446` | `blocked_buttons_look_disabled_and_path_hint_has_no_drag` | cmp EQ |
| M07 | path hint off | `InventoryPanels.gd:413` | same | cmp EQ |
| M08 | column always vertical | `InventoryPanels.gd:300` | `path_column_is_side_by_side_and_clears_the_bottom_buttons` | cmp EQ |
| M09 | `_PATH_BUTTONS_CLEARANCE` 0 | `RealmShell.gd:30` | same | cmp EQ |
| M10 | no `_reset_local()` on empty inventory | `InventoryPanels.gd:156` | `a_path_snapshot_without_inventory_closes_the_pack` | cmp EQ |
| M11 | `toggle_pack` inventory guard removed | `InventoryPanels.gd:211` | same | cmp EQ |
| M12 | HUD pack button always visible | `StageExploreScreen.gd:636` | NONE in `inventory_ui,realm_ui,seam` (F9-03) | cmp EQ |
| M13 | 0.6 s lock removed | `InventoryPanels.gd:519` | `let_it_go_lock_after_the_modal_closes` | cmp EQ |
| M14 | strap pulse removed | `InventoryPanels.gd:396` | `pack_pulses_once_when_it_becomes_full` | cmp EQ |
| M15 | tap-anywhere finish removed | `ResolveScreen.gd:826` | `a_tap_anywhere_finishes_the_card_motion` | cmp EQ |
| M16 | `stack_limit` -> `type_mismatch` | `ItemMovePlan.gd:97` | `refused_drops_send_nothing_and_show_the_reason`, `move_plan_follows_the_core_rules` | cmp EQ |
| M17 | `display_name` ignores `name` | `ItemUiText.gd:159` | 4 tests, including `result_and_at_risk_tiles_show_the_row_name_or_the_kind_word` | cmp EQ |
| M18 | `bracket_light` not set | `ItemResultRow.gd:127` | NONE in `inventory_ui,payout_ui` (visual only) | cmp EQ |
| M19 | row not centred on dark | `ItemResultRow.gd:53` | NONE (visual only) | cmp EQ |
| M20 | old `await create_timer` in `_flash` | `InventoryPanels.gd:583-585` | no test; `--verbose` prints the leak (2 `SceneTreeTimer`) | cmp EQ |

## 7. Test integrity

| File | HEAD | Tree | Judgement |
|---|---|---|---|
| `tests/InventoryUITests.gd` | 27 tests | 35 tests | 8 added, 0 removed, 0 renamed. One step repaired (F8-09: now a real stack-limit drop; stronger). In `_t_reason_keys` the "generic line" loop lost `unknown_entry`, `bad_slot`, `count_range`, `no_change`, because they now have their own lines. Each one is now asserted against its own constant. `not_unique` and `no_stage` were added to the generic list. Not weakened. |
| `tests/Stage004SeamTests.gd` | 64 | 64 | One line added: the `_pack_hud` setup in `_t_realm_target_minima_and_spatial_caps`. Nothing else. M01 proves that the guard sees the badge again. |
| Weak spots | | | F9-02, F9-03. F8-06 is visual only. Guards are still reached by setting private fields (`_letgo_lock_until`, strap `_tween`). |

## 8. Contract

| Check | Result |
|---|---|
| No `core/` file in the diff | PASS (0 files) |
| Added `ui/` lines read no save, `FlowContext`, `FlowRuntime`, core service, `user://`, `FileAccess` | PASS (grep: 0 hits) |
| New player-facing text only in `ItemUiText.gd`, each with `# PLACEHOLDER` | PASS (5 new `const` lines, 0 without the mark; no `text =` added to `.tscn`; no word literal in the added `.gd` lines) |
| UI stores no refusal and no name beyond the snapshot | PASS (F9-06 Info) |
| Theme addition | `ItemButtonBlocked` reuses existing sub-resources. Its colours are the existing ink tone with alpha. |
| `--check-only --quit` | rc 0, 0 `SCRIPT ERROR` |
| `scripts/check-shard-map.sh` | `SHARD MAP CHECK: OK (145 registered suites, each in exactly one of 13 shards or the merge step).` |

## 9. Evidence

| Run | Raw line |
|---|---|
| `=realm_ui` | `Tests: 20 total, 20 passed, 0 failed` (0 `SCRIPT ERROR`) |
| `=inventory_ui` | `Tests: 35 total, 35 passed, 0 failed` (0 `SCRIPT ERROR`) |
| `=inventory_ui` `--verbose` | `Tests: 35 total, 35 passed, 0 failed`; no leak line |
| `=inventory_ui,realm_ui,foundation_ui,payout_ui,snapshot_fingerprint` | `Tests: 132 total, 132 passed, 0 failed` (0 `SCRIPT ERROR`) |
| `=objective` | `Tests: 26 total, 26 passed, 0 failed` (1 pre-existing `SCRIPT ERROR`, F9-07) |

| Tree state | Value |
|---|---|
| `git diff \| sha256sum` at start | `1d088794f04d1b787b170ea835d8bafbe7eba6aa1aeb32f1b9219bc4b6b56c30` |
| `git diff \| sha256sum` after each render batch and at the end | `1d088794f04d1b787b170ea835d8bafbe7eba6aa1aeb32f1b9219bc4b6b56c30` |
| Untracked files at start | 0 (checksum list `/tmp/claude-0/qaui2-untracked-before.txt` is empty) |
| Untracked files at end | 0, apart from this report |
| Backups proved equal at the end | `/tmp/claude-0/qaui2-backup/*`: 7 source files and 7 copies of `scripts/screenshot.gd`, all `cmp` equal to the tree |
| Commits, stash, checkout | none |

## OPEN — questions and assumptions

- ASSUMED: F9-01 is Medium, not High. The UI predicts `path_used`, so a core refusal on the path needs a stale prediction or a core-only reason (`bad_state`, `no_stage`). It is rare. But the panels and their close button leave the screen until the next snapshot.
- ASSUMED: F9-01 is new in this round. The refusal-key branch and the horizontal path column are both new. I did not render HEAD (no checkout allowed).
- ASSUMED: the root cause of F9-01 is a large transient minimum size during the refusal render. I measured the effect (`Work` 1213 px tall, y -246.5), not the exact cause.
- ASSUMED: one early probe used the Realm harness with a `flow.echo_party` snapshot and showed a 32 px shift. That harness is wrong for party prep. The correct Sanctum harness shows no shift. I discarded that result.
- BLOCKED: none.
