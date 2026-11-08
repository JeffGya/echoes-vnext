# Step 9 QA report — D-49 changes (finds stay in the pack, strap line removed)

Agent: qa-verifier (independent; I did not build these changes). Scope: the uncommitted tree against HEAD.
I changed no source, test, data, scene, theme or doc file. This report is the only file I wrote.

## Verdict

**PASS WITH FINDINGS.**

The core rule of D-49 holds in all 65 probe cases and in 9 of 9 core mutations. The strap line is gone. Three
pack tones exist, and the pulse acts on the panel tone only. One Medium finding needs Jeff's decision: a big stack
find now loses units while the Sanctum has free room (F10-01). The other findings are Low.

## Findings (ranked)

| ID | Severity | Where | Failing scenario (inputs and result) | Suggested fix |
|---|---|---|---|---|
| F10-01 | Medium (design consequence; Jeff decides) | `core/inventory/InventoryService.gd:493-531` (`_intake_stack`, steps 1 and 2 skipped for `pack_only`) | Sanctum size 4, empty. Pack size 4, empty. One find `ph_consumable_a` 20 (stack limit 3) through `record_found_items`, then path end. Result: pack stacks 3,3,3,3; kept row `quantity` 12, `reason_key` `overflow`, `lost_quantity` 8. The Sanctum stays empty with 4 free slots. The old order (mode `gathered`, same tree) stores all 20. Pack size 2 with finds [C20, relic] (probe P10): 3 stored, 17 lost. D-49 says "a find is not lost for lack of room"; this is true for a unique piece and for a stack up to one stack, NOT for a stack larger than the limit. D-47 accepted "a few units" (F4-02, rare); with D-49 the loss is larger and does not depend on the Sanctum. Today only the debug producer makes such finds (finds are not configured yet, D-48 F8-02). | Ask Jeff: (a) accept as built (a find keeps what one row-owned slot plus free pack slots hold); or (b) another rule for the rest of a big find. Record the answer before the finds story (ITEM-002) configures stack finds. |
| F10-02 | Low | `core/inventory/InventoryService.gd:580-582` (`_intake_unique`), `:514-520` (`_intake_stack`, first chunk) | A row written past the seam (`EarningsService.record_item` directly) with a full pack: pack size 2 holds 2 carried pieces; rows relic and C2; Sanctum size 4, empty. Path end and leave `all`: both finds go to slots 2 and 3. `validate` = `pack: 4 entries above pack_capacity`. Before D-49 the empty Sanctum took them. Not reachable in play: `record_found_items` caps finds at `pack_free(open rows)`, and `move_entry` and the `direct` producer count open rows. Only a config change of `pack_capacity` or a hand-made save reaches it. | None needed now. Note it for the pack-shrink story (D-41), which changes `pack_capacity`. |
| F10-03 | Low (test gap) | `tests/InventoryUITests.gd:1257-1272` (`_t_pack_pulse`), `:380-397` (`_t_pack_panel`) | Mutations U4 (reduced-motion fade 0.15 s made 0.9 s), U5 (near-full colour made equal to the plain colour) and U6 (flash 0.4 s made 3.2 s) fail no test. The tests check only that a tween exists and which variation name is set. HEAD had the same gap for the strap tween. | Pin the tween duration of both branches, and assert that the three style boxes have three different `bg_color` values. |
| F10-04 | Low (report only, as asked) | `assets/theme/LivingTreeSystem.tres:1076-1091`; screenshots `/tmp/claude-0/qa9-shots/party_compare.png`, `path_compare.png` | Panel colour and luma: plain (75,56,38) luma 59.6; near (62,46,31) luma 49.1; full (55,40,26) luma 42.9. WCAG contrast ratio: plain/near 1.17, near/full 1.09, plain/full 1.28. In the grayscale copies, near full and full cannot be told apart by the tone. They are told apart by the words (`Nearly full.` against `Heavy. They may lose what they carry.` / `Full. Nothing more fits.`), by the empty socket and by the satchel mark bands. | No new decoration proposed (brief). Jeff judges the tone step. |
| F10-05 | Low | `core/inventory/InventoryService.gd:37` (`MODE_GATHERED`), comment `:510-512` | `gathered` mode has no production caller now (grep: only `MODE_DIRECT` in `DebugController.gd:630` and `MODE_PACK_ONLY` in `StageSettlementService.gd:548`). Tests still use the string `"gathered"`. The comment at `:510-512` names only `gathered` for the row-owned first chunk; `pack_only` uses the same rule (`gathered := mode != MODE_DIRECT`). | Jeff decides keep or delete the unwired mode (CLAUDE.md: unwired feature). Add `pack_only` to the comment at `:510-512`. |
| F10-06 | Low (test gap) | `tests/InventoryPathTests.gd:1083-1105` (`_t_find_player_move`) | The test puts the finds in the pack with `intake(... "pack_only")`, not through a settlement. My probe 3 closes the gap by hand: after a real path end, `move_entry` moves the relic and the stack to the Sanctum (`moved`/`moved`, `validate` empty). | Optional: start the test from `_settle_path`. |
| F10-07 | Low (doc) | `docs/stories/v2-item-001/step7-backend-moves-slots.md` (D-49 section, "expected sharded total is 2692") | The main chat's sharded run gave `COMBINED: 2730`. The difference is 38, which equals the `inventory_ui` suite count. Probably the builder's total left out the UI suite. No test is missing: the per-file counts match (see Test integrity). | Correct the expected total in the builder report. |

## Core verification

### 1. Rule and callers

| Caller of `InventoryService.intake` | Mode | Use | Result |
|---|---|---|---|
| `StageSettlementService._settle_item_row` (`StageSettlementService.gd:546-548`) | `pack_only` | path end (`settle` → `_bank_item_rows` → `_bank_rows`), preview (`preview` → `_bank_rows` on a deep copy), kept early leave (`_settle_leave_items`) | Finds go to the pack only. Sanctum byte-equal in every probe. |
| `DebugController.handle_inventory_produce` (`DebugController.gd:630`) | `direct` | debug producer, mode `direct` | Unchanged: Sanctum first, then a free pack slot. Debug mode `gather` writes rows through `record_found_items`; they settle as `pack_only`. |
| (none) | `gathered` | tests only | Sanctum first, unchanged (`inventory_moves/pack_only_intake_never_touches_the_sanctum`, last block). See F10-05. |

Unique piece: lowest free pack slot. Stack: merge into a same-type pack stack with room, then new pack stacks; first chunk on the row-owned slot; further chunks need `pack_free(later_rows) > 0`, `later_rows` includes other Realms (P8). A lost remainder reports `overflow` (never `stack_limit`, M5 proves the pin).

### 2. Probes (through `ActiveStageService.record_found_items`)

Script `/tmp/claude-0/qa9/probe.gd`, raw output `/tmp/claude-0/qa9/p1.txt`. Each case ran with 5 outcomes: path end (seed 2), leave `all` (seed 2), leave `some` (seed 1), leave `nothing` (seed 0), defeat. Checks per case: Sanctum byte-equal; conservation (in = stored + lost, per stack type and for pieces); pack count and pack + open rows not above the size; `validate` empty; preview equals payout (path end); kept gathered `reason_key` in {`ok`, `overflow` with `lost_quantity`}; no `to_pack` and no `stack_limit` anywhere.

| Case | Sanctum | Pack | Finds | Result (5 outcomes) |
|---|---|---|---|---|
| P1 | 4, empty | 4, empty | relic, C2 | PASS |
| P2 | 2, full | 4, carried armor | relic, C2 | PASS |
| P3 | 4, empty | 4, carried C1 | C2 (merge) | PASS (one stack of 3) |
| P4 | 4, holds C1 (room 2) | 4, empty | C2 | PASS (new pack stack; Sanctum stack not merged) |
| P5 | 4, empty | 4, empty | C20 | PASS (12 kept, 8 lost `overflow`; see F10-01) |
| P6 | 4, empty | 4, empty | C8, M12 (two rows, two types) | PASS |
| P7 | 2, full | 8, empty | relic, C20 | PASS |
| P8 | 1, full | 3, open row in another Realm | C8 | PASS (2 stacks, 1 slot left for Realm B) |
| P9 | 4, empty | size 2, carried weapon | relic, armor (seam takes 1) | PASS |
| P10 | 4, empty | size 2, empty | C20, relic | PASS (3 kept, 17 lost; see F10-01) |
| P11 | 2, full | 8, 3 carried + C2 stack | C20, relic, M7 | PASS |
| P12 | 4, empty | size 2, full of carried | relic (seam takes 0) | PASS |
| P13 | 2, full | 8, carried C2 | C2, relic, C2, M3 | PASS (merge chain) |

Total: 65 of 65 PASS. Determinism: a second run is byte-equal (`cmp`, 26818 bytes).

Result rows: a kept gathered find has `source` `gathered`, `reason_key` `ok` (or `overflow` with `lost_quantity` when part was lost, the stored part in `quantity`). `to_pack` is not produced for gathered finds. Lost gathered rows carry `leave_none`, `leave_some` or `defeat`, `mark_index` -1. Lost carried rows carry `source` `held` and their `mark_index`.

### 3. D-42

Grep of every writer: Sanctum `items` gets a piece only in `_intake_unique` when `to_items` (never for `pack_only`) and in `_move_entry` (`:692`). Sanctum `stacks` gets a stack only in intake step 2 (skipped for `pack_only`) and in `_move_entry`. `move_entry` has one caller, `InventoryController.handle_move` (`inventory.move.apply`). `remove_held` (leave, defeat) only removes. Probe 3: after a real path end the player moves both finds to the Sanctum (`moved`, `moved`, `validate` empty).

### 4. A kept find is a carried piece (builder assumption 2) — CONFIRMED

Probe 2 (`/tmp/claude-0/qa9/p2.txt`), same stage record, two leaves:

| Seed | Leave 1 | Kept after leave 1 | Leave 2 | Leave 2 result |
|---|---|---|---|---|
| 2 | all | relic, C2 (pack) | none | relic and C2 lost, `leave_none`, `source` `held` |
| 7 | all | relic, C2 | some | both lost, `leave_some`, `held` |
| 5 | all | relic, C2 | all | both kept, `ok`, `held` |
| 1 | some | C2 | none | C2 lost, `held` |

Defeat after a path end: the kept relic and C2 are lost with `defeat`, `source` `held`. So a find is at risk until the player moves it to the Sanctum (D-19, D-20, D-22). This is a direct result of D-49 plus D-42.

### 5. Unchanged things

| Check | Result |
|---|---|
| Leave draw code | `git diff -U0` hunks in `StageSettlementService.gd` are only at lines 167, 457, 530 (comments) and 548 (mode). `_keeps`, the `stage.settle` outcome stream and the draw keys are not changed. |
| Leave and settle characterization | `=econ_char`: 103/103; `=item_packs_char,seam,stop_short`: 104/104 (includes `item_packs/some_draws_do_not_depend_on_order_or_other_entries` in the core run). |
| `snapshot_fingerprint` | 2/2 pass with the recorded hashes. |
| Dispatch guard | `flow_transaction/dispatch_action_count_is_82` passes (9/9 in the suite). |
| Compile check | `--headless --check-only --quit`: 0 `SCRIPT ERROR`. |
| Shard map | `SHARD MAP CHECK: OK (145 registered suites, each in exactly one of 13 shards or the merge step).` |

## Mutation checks

All mutations: copy to `/tmp/claude-0/qa9-backup`, edit, one short suite, restore with `cp`, `cmp` equal. Core suite set `=inventory_paths,inventory_moves,item_packs,inventory_actions` (98 tests). UI suite `=inventory_ui` (38 tests).

| ID | Mutation | File:line | Failing tests (count; first names) | Restored, `cmp` |
|---|---|---|---|---|
| M1 | Settlement routes finds to `gathered` again | `StageSettlementService.gd:548` | 8; `new_finds_land_in_the_pack_and_stay_there`, `item_only_pack_draws_the_outcome_roll`, `report_rows_carry_source_and_mark_index` | yes |
| M2 | `pack_only` off in `_intake_stack` | `InventoryService.gd:485` | 5; `pack_only_intake_never_touches_the_sanctum`, `new_finds_land_in_the_pack_and_stay_there` | yes |
| M3 | `pack_only` off in `_intake_unique` | `InventoryService.gd:554` | 9; `path_end_banks_item_rows_once`, `pack_only_intake_never_touches_the_sanctum` | yes |
| M4 | Later-rows reservation ignored (`pack_free(…, 0)`) | `InventoryService.gd:514` | 4; `a_big_stack_find_stays_within_the_pack_through_the_real_seam`, `a_big_stack_find_leaves_the_slots_of_rows_in_other_realms`, `pack_only_intake_never_touches_the_sanctum` | yes |
| M5 | Lost remainder reports `stack_limit` | `InventoryService.gd:531` | 4; `partial_stack_keeps_the_stored_quantity`, `pack_only_intake_never_touches_the_sanctum` | yes |
| M6 | Kept leave uses the old placement (`gathered` when `lost_reason` is set) | `StageSettlementService.gd:548` | 7; `new_finds_land_in_the_pack_and_stay_there` (leave cases), `leave_item_report_reaches_the_card_and_survives_a_reload` | yes |
| M7 | Preview uses the old placement (`gathered` when `logger` is null) | `StageSettlementService.gd:548` | 2; `path_end_preview_equals_the_payout_report`, `a_big_stack_find_leaves_the_slots_of_later_rows` | yes |
| M8 | `pack_only` stack reports `to_pack` again | `InventoryService.gd:529` | 6; `pack_only_intake_never_touches_the_sanctum`, `new_finds_land_in_the_pack_and_stay_there` | yes |
| M9 | `pack_only` piece reports `to_pack` again | `InventoryService.gd:583` | 11; `item_only_pack_draws_the_outcome_roll`, `stage_clear_card_carries_the_item_preview` | yes |
| U1 | Near full gets the full tone | `InventoryPanels.gd:374` | 1; `pack_panel_shows_no_counts_and_level_words` (`near full: tone=ItemPanelPackHeavy`) | yes |
| U2 | Full gets the near tone | `InventoryPanels.gd:374` | 1; same test (`a full pack needs the darkest tone`) | yes |
| U3 | Pulse call removed | `InventoryPanels.gd:397` | 1; `pack_pulses_once_when_it_becomes_full` | yes |
| U4 | Reduced-motion fade 0.15 s × 6 | `InventoryPanels.gd:410` | **NONE** (F10-03) | yes |
| U5 | Near style colour = plain colour | `LivingTreeSystem.tres:1081` | **NONE** (F10-03) | yes |
| U6 | Flash 0.4 s × 8 | `InventoryPanels.gd:413` | **NONE** (F10-03) | yes |

## Test integrity

| File | Tests HEAD → now | Change | Judgement |
|---|---|---|---|
| `tests/InventoryMoveTests.gd` | 13 → 14 | added `pack_only_intake_never_touches_the_sanctum` | Good; kills M2 to M5, M8. |
| `tests/InventoryPathTests.gd` | 27 → 29 | added `new_finds_land_in_the_pack_and_stay_there`, `a_find_in_the_pack_is_moved_by_the_player_only`; `a_new_stack_find_is_kept_in_the_pack_when_the_sanctum_is_full` re-pinned `to_pack` → `ok` | Re-pin follows D-49. The move test does not use a settlement (F10-06). |
| `tests/ItemPacksTests.gd` | 30 → 30 | re-pinned `item_only_pack_draws_the_outcome_roll` (find in pack; repeat leave now draws when kept), `survivor_stays_held_when_the_sanctum_is_full` (`to_pack` → `ok`), `path_end_banks_item_rows_once` (relic and stack in the pack), `path_end_with_a_full_sanctum_keeps_pieces_held` (`ok`), `report_rows_carry_source_and_mark_index` (`ok`) | All re-pins follow D-49. In `item_only_pack_draws_the_outcome_roll` the "save unchanged on repeat leave" check now runs only when nothing was kept; the kept branch checks one new leave log instead. Not weakened: the old assertion is false under D-49. |
| `tests/InventoryActionTests.gd` | 25 → 25 | `leave_item_report_reaches_the_card_and_survives_a_reload` armor `to_pack` → `ok` | Follows D-49. |
| `tests/InventoryUITests.gd` | 38 → 38 | strap assertions replaced by tone variation and a `PackStrap` absence check; pulse test reads `_tone_tween` | Good for U1 to U3; gaps U4 to U6 (F10-03). |

No test removed or renamed. Names were compared with `git show HEAD:tests/<file>` (`register_test` lines).

## UI verification

| Check | Result |
|---|---|
| Strap removed | No `PackStrap` node; `grep -i strap` over `ui/` and `assets/theme/` finds nothing. `ItemMeter.gd` keeps only `_draw_ledger`; no `.tscn` sets the removed `mode` property. |
| Sanctum ledger | `_draw_ledger` and `pulse()` unchanged in the diff. |
| Pack panel counts | No count and no bead gauge in the pack panel (screenshots). `n / 4 sockets` shows only on the party-details and path pack button (allowed by D-39). |
| Three tones | `ItemPanelPack`, `ItemPanelPackNear` (new), `ItemPanelPackHeavy`, chosen in `InventoryPanels.gd:374`. |
| Wording | `git diff -- ui/components/ItemUiText.gd` is empty. New `+` lines under `ui/` hold no player-facing literal (only theme names and tween property paths). |
| Pulse | `_pulse_pack_tone` (`InventoryPanels.gd:403-413`): flash `modulate` 1.3 → 1.0 over `PULSE_SECONDS` 0.4; reduced motion: alpha 0 → 1 over 0.15. Called once on a transition into full (`_update_pulses`, test passes). Motion not viewed. |
| Contract | `InventoryPanels.gd` and `ItemMeter.gd` reference no `SaveService`, `FlowContext`, `ConfigService` or core service. No `core/` file under `ui/`. |

### Rendered screens

`xvfb-run`, GL Compatibility (`opengl3`), 1280x720, `scripts/screenshot.gd`, fixtures `invs_party_lv0/2/3` and `invr_path_lv0/2/3`. I viewed every PNG and the two comparison sheets.

| File | Seen |
|---|---|
| `/tmp/claude-0/qa9-shots/invs_party_lv0.png` | Party details, pack panel empty: plain tone, 4 empty sockets, no word, no line. |
| `/tmp/claude-0/qa9-shots/invs_party_lv2.png` | 3 of 4: darker tone, `Nearly full.`, no line. |
| `/tmp/claude-0/qa9-shots/invs_party_lv3.png` | 4 of 4: darkest tone, `Heavy. They may lose what they carry.`, no line. |
| `/tmp/claude-0/qa9-shots/invr_path_lv0.png`, `_lv2.png`, `_lv3.png` | Path view, same three tones; full says `Full. Nothing more fits.`; read-only and let-go lines present. |
| `/tmp/claude-0/qa9-shots/party_compare.png`, `path_compare.png` | Colour row above, grayscale row below. Near full and full look the same in grayscale (F10-04). |
| `*_gray.png` | Grayscale copies of each screen. |

## Evidence

| Item | Value |
|---|---|
| `git diff \| sha256sum` before | `c66cdaa597ed88909a2a67856b26fed58debc8d9b2921e7318f4497639a1928d` |
| `git diff \| sha256sum` after (and after each mutation pair) | `c66cdaa597ed88909a2a67856b26fed58debc8d9b2921e7318f4497639a1928d` |
| Untracked before | none |
| Untracked after | only `docs/stories/v2-item-001/step9-qa-report.md` (this report) |
| `.import` files created | none |
| `=inventory_paths,inventory_moves,item_packs,inventory_actions` | `Tests: 98 total, 98 passed, 0 failed` |
| `=inventory_ui,flow_transaction,snapshot_fingerprint` | `Tests: 49 total, 49 passed, 0 failed` |
| `=item_packs_char,seam,stop_short` | `Tests: 104 total, 104 passed, 0 failed` |
| `=econ_char` | `Tests: 103 total, 103 passed, 0 failed` |
| Mutation logs | `/tmp/claude-0/qa9/M1.log` … `M9.log`, `U1.log` … `U6.log` |
| Probes | `/tmp/claude-0/qa9/probe.gd` (`p1.txt`, `p1b.txt`), `probe2.gd` (`p2.txt`), `probe3.gd` (`p3.txt`) |

## OPEN — questions and assumptions

ASSUMED: 1. Probes run by `--script` from `/tmp/claude-0/qa9/` exercise the same code as tests; they changed no tree file.
ASSUMED: 2. "HEAD behaviour" for F10-01 comes from mode `gathered` on the current tree. That code path is byte-identical to HEAD apart from the bool-to-string parameter change; I did not check out HEAD.
ASSUMED: 3. The defeat probe calls `ActiveStageService.lose_unsettled_packs` directly with a fresh `EncounterContext`, not through `FlowRuntime`.
BLOCKED: 1. F10-01 needs Jeff: accept that a stack find larger than one stack loses its rest while the Sanctum has room, or set another rule.
BLOCKED: 2. F10-04 needs Jeff: is a grayscale contrast of 1.09:1 between near full and full acceptable when the words differ?
BLOCKED: 3. F10-05 needs Jeff: keep or delete the unused `gathered` intake mode.
