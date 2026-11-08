# Step 10 QA report (D-51 copy, removals, tone C)

Status: COMPLETE. QA agent: qa-verifier (independent; did not build the change). No source, test, data, scene, theme or doc file was edited (only this report).

## Verdict: PASS WITH FINDINGS

The approved wording is applied word for word (0 DIFF in 65 fixture keys and 79 table rows). All removals are gone from code, scenes and screens, and the layouts close up. Tone C values are exact. Every mutation was caught except two (F11-02: two of Jeff's answers have no test). No finding blocks the story. Medium: 1. Low: 4. Info: 3.

## 1. Wording table (script: /tmp/claude-0/qa10/cmp.py, probe: /tmp/claude-0/qa10/probe.gd)

Method: the script parses the last column of every table row of `copy-approval-jeff.md` and every `const` of `ui/components/ItemUiText.gd`. It also compares each constant to `tests/fixtures/ItemUiApprovedCopy.json`. A Godot probe ran the number-built functions. Result: 0 DIFF, 0 fixture mismatch, 0 constants outside Jeff's file, 0 fixture keys without code.

| Row | Jeff's pick | Code text | Result |
|---|---|---|---|
| RAIL_LABEL | Storehouse | Storehouse | MATCH |
| SANCT_TITLE | Storehouse | Storehouse | MATCH |
| SANCT_SUB | [remove] | (absent) | REMOVED-OK |
| PACK_TITLE | Travel pack | Travel pack | MATCH |
| PACK_SUB | [remove] | (absent) | REMOVED-OK |
| SHOW_PACK | Open pack | Open pack | MATCH |
| HIDE_PACK | Close pack | Close pack | MATCH |
| CLOSE_SANCT | Close the storehouse | Close the storehouse | MATCH |
| CLOSE_PACK | Close the pack | Close the pack | MATCH |
| PARTY_PACK_BUTTON | Travel pack | Travel pack | MATCH |
| FULL_WORD | Full | Full | MATCH |
| PACK_NEAR | Almost full. | Almost full. | MATCH |
| PACK_HEAVY | [remove] | (absent) | REMOVED-OK |
| PACK_FULL_PATH | Pack is full. Nothing else fits. | Pack is full. Nothing else fits. | MATCH |
| DEPART_LINE | There are items in the travel pack. Items can be lost. | There are items in the travel pack. Items can be lost. | MATCH |
| AT_STAKE | [remove] | (absent) | REMOVED-OK |
| AT_STAKE_LABEL | [remove] | (absent) | REMOVED-OK |
| DETAILS_TITLE | [Remove] | (absent) | REMOVED-OK |
| DETAILS_EMPTY | Select an item to learn more. | Select an item to learn more. | MATCH |
| DETAILS_HINT | [Remove ] | (absent) | REMOVED-OK |
| WHERE_SANCT | Storehouse | Storehouse | MATCH |
| WHERE_PACK | Pack | Pack | MATCH |
| GRADE_LABEL | Grade | Grade | MATCH |
| COUNT_LABEL | Amount | Count | OVERRIDDEN-BY-ANSWER |
| ONE_PIECE | One | (absent) | OVERRIDDEN-BY-ANSWER (not shown) |
| AT_LIMIT | Full stack | Full stack | MATCH |
| BTN_MOVE_PACK | Put in pack | Put in pack | MATCH |
| BTN_MOVE_SANCT | Place in storehouse | Place in storehouse | MATCH |
| BTN_LET_GO | Destroy | Destroy | MATCH |
| BTN_KEEP | Keep | Keep | MATCH |
| PATH_READONLY | [Remove] | (absent) | REMOVED-OK |
| PATH_LEFT | 1 destroy action left on this this path. | 1 destroy action left on this path. | MATCH-WITH-CONFIRMED-FIX |
| PATH_USED | No destroy action left. | No destroy action left. | MATCH |
| PATH_HINT | While on the move you can't reorganize your pack. | While on the move you can't reorganize your pack. | MATCH |
| PATH_RULE | [Remove] | (absent) | REMOVED-OK |
| PATH_PREVIEW | [remove] | (absent) | REMOVED-OK |
| CARD_PREVIEW | [remove] | (absent) | REMOVED-OK |
| R_PATH | While on the move you can't organize your pack. | While on the move you can't organize your pack. | MATCH |
| R_PACK_FULL | The pack is full. | The pack is full. | MATCH |
| R_SANCT_FULL | The storehouse is full. | The storehouse is full. | MATCH |
| R_DISCARD_USED | No destroy actions left. | No destroy actions left. | MATCH |
| R_NOT_IN_PACK | [should not be possible remove] | (absent) | REMOVED-OK |
| R_OCCUPIED | This spot is taken. Choose an empty spot. | This spot is taken. Choose an empty spot. | MATCH |
| R_TYPE | Only similar items can be joined. | Only similar items can be joined. | MATCH |
| R_STACK_LIMIT | This stack is already full. | This stack is already full. | MATCH |
| R_EQUIPPED | This is in use. | This is in use. | MATCH |
| R_SANCTUM_ONLY | This can only be done in the Sanctum. | This can only be done in the Sanctum. | MATCH |
| R_NO_CHANGE | Nothing changed. | Nothing changed. | MATCH |
| R_GONE | It's no longer there. | It's no longer there. | MATCH |
| R_BAD_SLOT | Thatspot is not availble. | That spot is not available. | MATCH-WITH-CONFIRMED-FIX |
| R_COUNT | This is not possible. | This is not possible. | MATCH |
| R_UNKNOWN | Nothing was changed. | Nothing was changed. | MATCH |
| DROP_REORDER | Drop to place | Drop to place | MATCH |
| DROP_MERGE | Drop to combine | Drop to combine | MATCH |
| DROP_PACK | Move to pack | Move to pack | MATCH |
| DROP_SANCT | Move to storehouse | Move to storehouse | MATCH |
| MODAL_TITLE | Are you sure? | Are you sure? | MATCH |
| MODAL_LINE | [remove] | (absent) | REMOVED-OK |
| MODAL_PATH_LINE | There is only 1 chance to destory on this path. | There is only 1 chance to destroy on this path. | MATCH-WITH-CONFIRMED-FIX |
| MODAL_PACK_LINE | [remove] | (absent) | REMOVED-OK |
| MODAL_SANCT_LINE | [remove] | (absent) | REMOVED-OK |
| MODAL_COUNT_LABEL | How many? | How many? | MATCH |
| COUNT_FEWER | One less | One less | MATCH |
| COUNT_MORE | One more | One more | MATCH |
| LEAVE_RISK_LABEL | At risk | At risk | MATCH |
| CARD_SURVIVED | Made it through. | Made it through. | MATCH |
| CARD_LOST | Lost | Lost | MATCH |
| ITEMS_GROUP_LABEL | Items. | Items. | MATCH |

The four KIND rows (gear, relic, consumable, material) are in Jeff's "Approved" table with no Pick column. Code: Gear, Relic, Supply, Material. They equal the suggestion column. Result: MATCH.

### Lines built from numbers (real output of the functions)

| Function | Sample | Output (between the bars) | Jeff's pick | Result |
|---|---|---|---|---|
| slots_word | 3, 20 | `3 / 20 spots filled` | 3 / 20 spots filled | MATCH |
| sockets_word | 2, 4 | `2 / 4 spots filled` | 2 / 4 spots filled | MATCH |
| pack_button | 2, 4 | `Travel pack 2/4` | Travel pacl 2/4 | MATCH-WITH-CONFIRMED-FIX |
| stack_count | 3, 20 | `x3 of 20` | x3 of 20 | MATCH |
| leave_risk | 3 | `3 items can be lost` (no full stop) | 3 items can be lost | MATCH |
| leave_risk | 1 | `1 item can be lost.` (full stop) | 1 item can be lost. | MATCH |
| moved_toast | pack | `Placed in pack.` | Placed in pack. | MATCH |
| moved_toast | sanctum | `Placed in storehouse` (no full stop) | Placed in storehouse | MATCH |
| reason_text | not_in_pack | `Nothing was changed.` (R_UNKNOWN) | row removed, falls back | REMOVED-OK |
| reason_text | container_full, pack / sanctum | `The pack is full.` / `The storehouse is full.` | same | MATCH |
| Detail pattern (`InventoryPanels.gd:428-437`) | single piece | `Kind: Gear`, `Grade: 3`, `Count: 1` | Kind: Gear / Grade: 3 / Count: 1 | OVERRIDDEN-BY-ANSWER (Count) |
| Detail pattern | stack 3 of 20 | `Count: x3 of 20`, plus ` Full stack` at the limit | not in Jeff's file (stack_count x3 of 20) | MATCH (composition) |
| Refusal pattern (`InventoryPanels.gd:445,449`) | pack full | `The pack is full.` only (no button name) | Jeff's answer: refusal only | OVERRIDDEN-BY-ANSWER (rendered check in section 4) |

Notes for section 1:
- Jeff's `CARD_SURVIVED`, `ITEMS_GROUP_LABEL` end in a full stop as typed. Code equals. OK.
- Dead approved strings: `LEAVE_RISK_LABEL`, `ITEMS_GROUP_LABEL`, `moved_toast()` have no use in `ui/` (grep). They were unused at HEAD too (only the old definition). They are approved, never shown. See finding F11-01.

## 3 and 5 (part). Mutation checks (all on the tree, one at a time, suite `=inventory_ui`, 41 tests; each restored with `cp` and proved with `cmp`)

Baseline: `Tests: 41 total, 41 passed, 0 failed`. Compile check `--check-only --quit`: 0 `SCRIPT ERROR`.

| Id | Mutation | File:line | Failing test (message) | Restored and cmp |
|---|---|---|---|---|
| M1 | R_GONE "It's no longer there." to "It is no longer there." | ItemUiText.gd:58 | `approved_copy_matches_the_fixture_word_for_word`: R_GONE is 'It is no longer there.', approved "It's no longer there." | yes |
| M2 | marker removed on CARD_LOST | ItemUiText.gd:79 | `placeholder_strings_are_marked_and_scenes_hold_no_words`: line 79 holds wording with neither marker | yes |
| M3 | marker replaced by `# PLACEHOLDER` on CARD_LOST | ItemUiText.gd:79 | same test: still holds a placeholder | yes |
| M4 | fixture entry "R_GONE" deleted | ItemUiApprovedCopy.json | `approved_copy...`: R_GONE is not in the approved fixture | yes |
| M5 | leave_risk many gets a full stop | ItemUiText.gd:134 | `approved_copy...`: leave_risk(3) is '3 items can be lost.' | yes |
| M6 | KIND consumable "Supply" to "Supplies" | ItemUiText.gd:KIND_NAMES | `approved_copy...`: KIND consumable | yes |
| M7 | marker date changed to 2026-11-07 | ItemUiText.gd:79 | marker test: neither marker | yes |
| M8 | marker removed from the `moved_toast` return line | ItemUiText.gd:138 | marker test: line 138 | yes |
| M9 | new const with marker, no fixture entry | ItemUiText.gd | `approved_copy...`: NEW_LINE is not in the approved fixture | yes |
| M10 | trailing space in R_NO_CHANGE | ItemUiText.gd | `approved_copy...`: R_NO_CHANGE | yes |
| M11 | `text = "Heavy pack"` added to PackTitle node | InventoryPanels.tscn:209 | marker test: holds player text outside ItemUiText.gd | yes |
| M12 | PATH_HINT replaced by literal "Cannot move" | InventoryPanels.gd | `blocked_buttons_look_disabled_and_path_hint_has_no_drag` | yes |
| T1 | near full tone set to the plain tone | LivingTreeSystem.tres:1081 | `pack_tones_are_the_approved_steps`: tone 1 is #7a5b3e, approved #4f3b28 | yes |
| T2 | full tone set to the near tone | LivingTreeSystem.tres:1064 | `pack_tones...`: tone 2 is #4f3b28, approved #120e0c | yes |
| T3 | plain tone red 0.4784 to 0.4900 | LivingTreeSystem.tres:1047 | `pack_tones...`: tone 0 is #7d5b3e, approved #7a5b3e | yes |
| T4 | PULSE_SECONDS 0.4 to 0.5 | InventoryPanels.gd:28 | `pack_pulse_lengths_flash_and_reduced_fade`: pulse lasts 0.500 s, wanted 0.40 s | yes |
| T5 | reduced fade 0.15 to 0.2 | InventoryPanels.gd:384 | same test: reduced=true lasts 0.200 s | yes |

Mutations with result NONE: none. (A first T3 try, red 0.4784 to 0.4800, changed no byte: both give 0x7A. It is not a mutation.)

## 2. No other player-facing text

Method: `git diff --name-only 047c7ec -- ui` (46 files) plus the working tree (8 files); grep of every `text =`, `tooltip_text`, `.text = "..."` and quoted literal in the new and changed `.gd` and `.tscn`; grep for the words discard, let it go, release, home, stage.

| Hit | Where | Judgement |
|---|---|---|
| `×`, `x1`, `−`, `+`, `<`, `>` | InventoryPanels.tscn:104,215; ItemTile.tscn:104; ItemDiscardModal.tscn:105,119; PartyPackButton.gd:60 | Symbols only. Jeff excluded them. OK. |
| `"Continue"` | ReturnHomeModal.gd:92, ReturnHomeModal.tscn:120 | Pre-existing (not in this story). OK. |
| `"Nothing is in their packs."` | CarriedHomePresentation.gd:12 (`GATHERED_EMPTY`), used at ReturnHomeModal.gd:69 | Pre-existing text at 047c7ec. The story changed only the condition (hidden when pieces are at risk). It says "packs", not "travel pack". See F11-06. |
| `"Return to the Sanctum"`, `RISK_LINE`, `CONFIRM_WARNING`, `KEEPS_LINE` | CarriedHomePresentation.gd:7-14 | Pre-existing. OK. |
| `"Stage Complete"`, `"stage"` in StageExploreScreen, EchoPartyScreen texts | other `.tscn` files | Pre-existing screens, not changed by the story (the diff to them adds only the pack button and `RAIL_LABEL`). OK. |
| `inventory.discard`, `inventory.discard.apply`, `DISCARD_MODAL`, `stage.*`, `flow.stage*` | RealmShell.gd, SanctumShell.gd, ItemDiscardModal.gd, AppRoot.gd | Identifiers and action names. Never shown. OK. |
| Words "discard", "let it go", "release", "home" in a player string of a story file | none | Clean. |
| Comment text "at-stake mark" | ItemTileGlyphs.gd:43,181 | Comment only. OK. |

Result: 0 player-facing literal from the story that is not in `ItemUiText.gd`. The test `placeholder_strings_are_marked_and_scenes_hold_no_words` also catches a new literal in an item scene (M11) and the path hint (M12).

Removed node names (`SanctSub`, `PackSub`, `DetailsTitle`, `StakeRow`, `PathReadonly`, `PathNote`, `PreviewTag`, modal `LineLabel` and `WhereLabel`): grep of `ui/`, `scripts/`, `tests/` finds none. The remaining `HintLabel` (path hint only) and the details `WhereLabel` (WHERE_SANCT, WHERE_PACK, Jeff's picks) are kept on purpose. Removed constants (ONE_PIECE, PACK_HEAVY, SANCT_SUB, PACK_SUB, AT_STAKE, AT_STAKE_LABEL, DETAILS_TITLE, DETAILS_HINT, PATH_READONLY, PATH_RULE, PATH_PREVIEW, CARD_PREVIEW, R_NOT_IN_PACK, MODAL_LINE, MODAL_PACK_LINE, MODAL_SANCT_LINE): no reference remains in `ui/`, `tests/`, `scripts/`.

## 3. Markers and the copy test

Every string line carries `# APPROVED (Jeff 2026-11-08)`; no `# PLACEHOLDER` remains (grep and test). The fixture `tests/fixtures/ItemUiApprovedCopy.json` (65 keys) equals the code and, through the script, Jeff's file. Mutations M1 to M10 are in the table above: all caught. A copy change with the marker kept (M1) is caught by the fixture. A fixture-only edit cannot pass, because the fixture is checked against the code.

## 4. Rendered screens (xvfb-run, GL Compatibility, llvmpipe; PNG files outside the repo; all VIEWED)

Command base: `xvfb-run -a -s '-screen 0 1280x720x24' godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://scripts/screenshot.gd -- <fixture> <dir>`. For the unique-piece destroy confirmation I used a copy of the script in `/tmp/claude-0/qa10/shot2.gd` with two added fixtures (the repo file is not changed).

| Screen | Fixture | Size | PNG | Result |
|---|---|---|---|---|
| Sanctum panel, pack open, piece selected | invs_both_panels | 1280 | /tmp/claude-0/qa10-shots/1280/invs_both_panels.png | No sub line, no details title. Panel and details close up. `7 / 20 spots filled`. Pass. |
| Same | invs_both_panels | 1920 | /tmp/claude-0/qa10-shots/1920/invs_both_panels.png | Pass. |
| Sanctum, nothing selected | invs_sanctum_empty_details | 1280 | /tmp/claude-0/qa10-shots/1280/invs_sanctum_empty_details.png | One line `Select an item to learn more.` No hint line, no title. No gap. Pass. |
| Sanctum, piece and stack selected | invs_sanctum, invs_stack_selected | 1280 | /tmp/claude-0/qa10-shots/1280/invs_sanctum.png, invs_stack_selected.png | `Kind: Gear / Grade: 2 / Count: 1`; stack `Count: x12 of 20`; `Storehouse` under the tile. Pass. |
| Pack in party details, plain | invs_party_lv0 | 1280 | /tmp/claude-0/qa10-shots/1280/invs_party_lv0.png | Tone #7A5B3E. No pack word. Pass. |
| Pack, near full | invs_party_lv2 | 1280 | /tmp/claude-0/qa10-shots/1280/invs_party_lv2.png | Tone #4F3B28, `Almost full.`, departure line. Pass. |
| Pack, full | invs_party_lv3 | 1280, 1920 | /tmp/claude-0/qa10-shots/1280/invs_party_lv3.png, /tmp/claude-0/qa10-shots/1920/invs_party_lv3.png | Tone #120E0C. No word, no strap line, no decoration. Departure line shows. Pass. |
| Three tones, colour and grayscale | strip of the three | 1280 | /tmp/claude-0/qa10-shots/tone_strip.png | Three steps are clear in grayscale. Pass. |
| Path view, pack open (plain with items) | invr_path | 1280 | /tmp/claude-0/qa10-shots/1280/invr_path.png | No lock line, no rule line. `1 destroy action left on this path.` Path hint in the empty details. Pass. |
| Path view, pack full | invr_path_lv3 | 1280, 1920 | /tmp/claude-0/qa10-shots/1280/invr_path_lv3.png, /tmp/claude-0/qa10-shots/1920/invr_path_lv3.png | `Pack is full. Nothing else fits.` Panel edge weak on the dark world: F11-04. |
| Path, destroy used | invr_path_used | 1280 | /tmp/claude-0/qa10-shots/1280/invr_path_used.png | Two refusal lines under both disabled buttons: F11-03. |
| Refusal lines (Sanctum, path) | invs_refusal, invr_path_refused | 1280 | /tmp/claude-0/qa10-shots/1280/invs_refusal.png, invr_path_refused.png | Line shows only `The storehouse is full.` and `Nothing was changed.` No button name. Pass. |
| Destroy confirmation, stack with count picker | invr_discard_stack | 1280, 1920 | /tmp/claude-0/qa10-shots/1280/invr_discard_stack.png, /tmp/claude-0/qa10-shots/1920/invr_discard_stack.png | Title, name, path line, `How many?`, `One less`/`One more` (`−`/`+`), `x12 of 12`, Keep, Destroy. No where line, no consequence line. Pass. |
| Destroy confirmation, unique piece, pack, on a path | qa_discard_unique (temp copy) | 1280 | /tmp/claude-0/qa10-shots/1280/qa_discard_unique.png | Name and `There is only 1 chance to destroy on this path.` Card closes up. Pass. |
| Destroy confirmation, unique piece, Sanctum | qa_discard_unique_sanct (temp copy) | 1280 | /tmp/claude-0/qa10-shots/1280/qa_discard_unique_sanct.png | Title and name only. No gap. See F11-05. |
| Leave confirmation | invr_leave_confirm | 1280 | /tmp/claude-0/qa10-shots/1280/invr_leave_confirm.png | `3 items can be lost` (no full stop) under the tiles. Pass. |
| Leave result card | invr_leave_result | 1280 | /tmp/claude-0/qa10-shots/1280/invr_leave_result.png | Tile row, no preview mark. Blank line space under the row (the empty tile-name line, pre-existing design). Pass. |
| Defeat card | invr_defeat_items | 1280 | /tmp/claude-0/qa10-shots/1280/invr_defeat_items.png | Lost tiles as ghosts. No mark. Pass. |
| Stage-clear card | invr_stage_clear_items | 1280, 1920 | /tmp/claude-0/qa10-shots/1280/invr_stage_clear_items.png, /tmp/claude-0/qa10-shots/1920/invr_stage_clear_items.png | The `Preview. Read-only.` mark is GONE. Tiles show. Pass. Re-rendered with 240 settle frames (`/tmp/claude-0/qa10-shots/settled/`): same image. |

Layout checks (at 1280x720): no overlap, no clipped text, no empty gap where a removed line was. Smallest text: 13 px (`ItemTextLightMuted`, path hint) and 12 px (stack capsule, not copy). Hint text contrast 5.10:1. Tap targets: the theme and scene minimums are 48 px or more (close 48x48, move and destroy 96x48, modal buttons 160x56, picker 48x48, pack button 48x64). Not verified: motion, a real device, a compact profile.

Observation (pre-existing, not changed by this story): in the harness the path HUD and the result cards look translucent, and the pack button label and departure line render at about 60 percent brightness (text colour 143,133,122, contrast 3.75:1 and 4.12:1 on the HUD). `ItemTextDark` is cream. I could not find the cause in 10 minutes; `PartyPackButton.gd` is unchanged in the working tree. See F11-07.

## 5. Tone C

| Check | Result |
|---|---|
| Theme values (`LivingTreeSystem.tres:1047,1081,1064`) | plain `Color(0.4784,0.3569,0.2431)` = #7A5B3E; near `(0.3098,0.2314,0.1569)` = #4F3B28; full `(0.0706,0.0549,0.0471)` = #120E0C. Exact. |
| Rendered pixels (PNG sample inside the panel) | #7A5B3E, #4F3B28, #120E0C. Equal to the theme. |
| Cream #F5E6D3 text contrast, computed | 5.05:1, 8.62:1, 15.67:1. Builder claim 5.1, 8.6, 15.7: the first is 5.05 (rounded up). OK. |
| Step ratios | plain to near 1.71:1; near to full 1.82:1. Tests need 1.3 and 1.5. |
| Colour and grayscale view | `/tmp/claude-0/qa10-shots/tone_strip.png`. Three steps are readable in grayscale. |
| Sockets | Empty socket #2B1F14 on plain 2.59:1, on near full 1.52:1. A full pack has no empty socket. Tiles sit on their own beds. See F11-04. |
| Panel edge on the full tone | Edge #241910 against the path world (50,48,47): 1.31:1. Panel against world 1.46:1. Panel against the Sanctum green 1.55:1. See F11-04. |
| Strap line, decoration | None in the three style boxes (only bg, same border colour/width and corner values). No strap node in the scene. Screens show none. |
| Mutations T1 to T5 | All caught. See the mutation table. |

## 6. Regression and contract

| Check | Result |
|---|---|
| `--check-only --quit` | 0 `SCRIPT ERROR` |
| `scripts/check-shard-map.sh` (with `GODOT_BIN` set) | `SHARD MAP CHECK: OK (145 registered suites, each in exactly one of 13 shards or the merge step).` (A first run without `GODOT_BIN` printed `FATAL: the runner listed no suite names`: my own mistake, not a defect.) |
| Suites | inventory_ui 41/41; realm_ui 20/20; foundation_ui 17/17; payout_ui 58/58; snapshot_fingerprint 2/2 (raw lines below) |
| `ui/` reads no save, FlowContext or core service | grep of the story files for SaveService, FlowContext, FlowRuntime, core/, user://, FileAccess: 0 hits |
| `core/` or `data/` in the working-tree diff | None (`git diff --name-only` has no core or data path). The committed core change since 047c7ec (25 files) belongs to earlier steps, not to this change. |
| Test hook `last_pulse_seconds` (`InventoryPanels.gd:97-98,396`) | Public var with a comment "a test reads it". Production code only assigns one float per pulse. It is read only by `_t_pulse_lengths`. It changes no behaviour and no state that is saved. Harmless. |

### Test integrity (HEAD vs working tree, `tests/InventoryUITests.gd`; the only modified test file)

| Item | Result |
|---|---|
| Registered tests | HEAD 38, now 41. Diff of the registration lines: 3 added, 0 removed, 0 renamed. |
| Added | `approved_copy_matches_the_fixture_word_for_word`, `pack_tones_are_the_approved_steps`, `pack_pulse_lengths_flash_and_reduced_fade` |
| Rewritten | `placeholder_strings_are_marked_and_scenes_hold_no_words`: marker changed to `# APPROVED (Jeff 2026-11-08)`; adds a `# PLACEHOLDER` check; also scans `else "`; the string minimum is 60 to 50 (50 is below the old 60 because strings were removed; 65 fixture keys remain). Judged: not weakened (M2, M3, M7, M8, M11 are caught). |
| Rewritten | `pack_panel_shows_no_counts_and_level_words`: asserted PACK_HEAVY visible at full; now asserts the word is NOT visible. Tightened. |
| Rewritten | `refusal_keys_map_to_text`: `not_in_pack` moved from the plain list to the unknown-line list. Correct for D-51. |
| Rewritten | result-row tests: `show_report(..., false)` becomes `show_report(...)`; preview checks changed from "visible" to "node absent". Correct for the removal. Not weakened. |
| Rewritten | `blocked_buttons_look_disabled_and_path_hint_has_no_drag`: path hint must be visible; Sanctum hint must be hidden. Tightened. |
| Removed assertions | Only those of deleted elements (PACK_HEAVY text, DETAILS_HINT, PreviewTag text, CARD_PREVIEW). No re-pinned number. |
| Gaps (new) | The refusal-only line and the `Count: 1` detail line are not pinned. See F11-02. |

## Mutation checks, part 2 (extra, on the removals; each restored with `cp`, proved with `cmp`)

| Id | Mutation | File | Failing test | Result |
|---|---|---|---|---|
| R1 | refusal line prefixed with the button name | InventoryPanels.gd:445 | none (`Tests: 41 total, 41 passed`) | NONE (F11-02) |
| R2 | pack word shown at full in party details | InventoryPanels.gd (`_pack_word.visible`) | `pack_panel_shows_no_counts_and_level_words` | caught |
| R4 | single piece shows `Count: 1 piece` | InventoryPanels.gd:437 | none | NONE (F11-02) |
| R5 | hint shown in the Sanctum details | InventoryPanels.gd (`_hint_label.visible`) | `blocked_buttons_look_disabled_and_path_hint_has_no_drag` | caught |

After all mutations: `cmp` of every touched file against its backup in `/tmp/claude-0/qa10-backup/` was equal, and the diff hash and untracked list match the start (see Evidence).

## Findings (ranked)

| Id | Severity | Where | Scenario | Suggested fix |
|---|---|---|---|---|
| F11-01 | Low | `ItemUiText.gd` `pack_button()` (line ~124), `moved_toast()` (~137), `LEAVE_RISK_LABEL` (line 77), `ITEMS_GROUP_LABEL` (line 80); real label at `PartyPackButton.gd:38-40` | Jeff approved these four lines (the spoken label of the pack button `Travel pack 2/4`, the toasts, the spoken labels `At risk` and `Items.`). No `ui/` code uses them. The screen-reader and tooltip name of the pack button is built as `Travel pack, 2 / 4 spots filled`. The unused code was the same at HEAD. | Ask Jeff: wire them (use `pack_button()` for the name, set the two row labels) or delete them with their fixture keys. Do not leave approved text that no player can meet. |
| F11-02 | Medium (test gap) | `tests/InventoryUITests.gd` | Two of Jeff's answers have no test: (a) a refused button shows only the refusal line (mutation R1: prefix the button name, all 41 pass); (b) a single piece shows `Count: 1` (mutation R4: `Count: 1 piece`, all 41 pass). A later edit can bring the old text back with no failure. | Add one assertion each: `_move_reason.text == ItemUiText.reason_text(...)` exactly; the details labels for a single piece equal `Kind: Gear`, `Grade: 3`, `Count: 1`. Add the three detail lines to the fixture as built lines. |
| F11-03 | Low | /tmp/claude-0/qa10-shots/1280/invr_path_used.png | On a path with the destroy action used, the details show two refusal lines together (`While on the move you can't organize your pack.` and `No destroy actions left.`). With the button name gone, a player may not know which line belongs to which button. The meaning makes it readable. This follows Jeff's answer. | Info for Jeff. Optional: place each line under its own button. |
| F11-04 | Low | `LivingTreeSystem.tres:1064-1069`; /tmp/claude-0/qa10-shots/1280/invr_path_lv3.png | Full tone #120E0C with edge #241910 on the dark path world: panel against world 1.46:1, edge against world 1.31:1 (below the 3:1 level for a UI boundary). The near full tone makes the empty socket 1.52:1 (plain: 2.59:1). The tiles and the cream text stay clear, so the panel is still readable. The builder noted this. | Jeff's call (tone only was ordered). Optional: lighten the full-tone border; that needs his approval because it changes the look. |
| F11-05 | Low (info) | /tmp/claude-0/qa10-shots/1280/qa_discard_unique_sanct.png | With MODAL_LINE and MODAL_SANCT_LINE removed, the Sanctum destroy confirmation shows only `Are you sure?` and the piece name. Nothing says the piece is gone for good. Jeff chose this. | None. Record for the UX redesign. |
| F11-06 | Low (info) | CarriedHomePresentation.gd:12; defeat card text `The party fell, and the packs were lost.` | Pre-existing lines use "packs"; Jeff's term is "Travel pack". Not in scope. | Ask Jeff in the copy pass of the UX redesign. |
| F11-07 | Info | `PartyPackButton`, harness screens | Pack button label and departure line render at about 60 percent brightness (3.75:1 on the HUD; 4.12:1 on the button) and HUD and cards look translucent in the harness. Not changed by this story. Cause not found. | Check on a real display (Jeff's in-game test). |
| F11-08 | Info | InventoryPanels.gd:97 | `last_pulse_seconds` hook is harmless. | None. |

## Evidence

Raw `Tests:` lines (each from a run with `ECHOES_TEST_SAVE_DIR=/tmp/echoes-vnext-tests/qa10-ITEM001`):

```
inventory_ui          Tests: 41 total, 41 passed, 0 failed   (baseline, and after every restore)
realm_ui              Tests: 20 total, 20 passed, 0 failed
foundation_ui         Tests: 17 total, 17 passed, 0 failed
payout_ui             Tests: 58 total, 58 passed, 0 failed
snapshot_fingerprint  Tests: 2 total, 2 passed, 0 failed
mutations             Tests: 41 total, 40 passed, 1 failed   (each caught mutation; 3 mutation runs gave 41 passed: R1, R4 and the no-op T3 try)
```

| Check | Before | After |
|---|---|---|
| `git diff \| sha256sum` | 20931d8ac6cd7fc03fa84d119fc6331aa7b6d45b7e605fe7926d305acd33102f | 20931d8ac6cd7fc03fa84d119fc6331aa7b6d45b7e605fe7926d305acd33102f (equal; checked after the mutations, after the renders and at the end) |
| Untracked files | `tests/fixtures/ItemUiApprovedCopy.json` sha256 8d6296ba25f517b0fab6654ff7b6c5cc67a04bf1b120d232a1f83ba19f639a28 | the same hash. The only added untracked file is this report. |
| Mutated files restored | n/a | `cmp` equal for ItemUiText.gd, the fixture, LivingTreeSystem.tres, InventoryPanels.gd and .tscn |

Scripts (outside the repo): `/tmp/claude-0/qa10/cmp.py` (wording compare), `/tmp/claude-0/qa10/probe.gd` (built lines), `/tmp/claude-0/qa10/shot2.gd` (screenshot copy with two added fixtures and 240 settle frames).

## OPEN — questions and assumptions

ASSUMED: 1. Jeff's `Pick` text for the KIND rows is the suggestion column, because his "Approved" table has no Pick column. Code equals it.
ASSUMED: 2. Jeff's "Detail line patterns" pick `Kind: Gear / Grade: 3 / Count: 1` is for a single piece. A stack shows `Count: x12 of 20` (from `stack_count`) and ` Full stack` at the limit. Jeff has not seen that exact composition in his file.
ASSUMED: 3. The mid-brightness look of the HUD in the harness is a harness effect, not a theme defect (F11-07).
BLOCKED: none.
Questions for Jeff (through the main chat): (a) F11-01: wire or delete the four approved lines that have no consumer. (b) F11-04: accept the weak edge of the full tone on the dark path world, or allow a lighter border. (c) F11-06: change "packs" in older lines to "travel pack" in a later copy pass?
