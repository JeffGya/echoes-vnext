# V2-ITEM-001a step 11: docs report (docs writer)

Written in STE. Date: 2026-11-08. No commit. No code, test, data, GDD, ANSWERS, Notion or existing story file was changed. `git diff --stat` shows only the files in "Done".

## Done

| File | What | Lines |
|---|---|---|
| `docs/MEMORY.md` | Four new rows in the Systems Inventory table: `InventoryService`, `InventoryRules`, `InventoryController`, Inventory UI (files under `ui/components/` and `ui/overlays/ItemDiscardModal.*`). | 150 to 153 |
| `docs/MEMORY.md` | Old dispatch count kept as history and extended: "V2-ITEM-001a raised it to 82" and the new guard name `dispatch_action_count_is_82`. | 408 (was 404) |
| `docs/MEMORY.md` | "Guard count 79" became "Guard count 79 (82 since V2-ITEM-001a)". | 429 (was 425) |
| `docs/MEMORY.md` | New dated entry "Status 2026-11-08" for V2-ITEM-001a: what it is, code locations, slot rules, decided rules, config, save, snapshots, actions including the debug producer `inventory produce [direct\|gather]`, UI rules, tests and fixtures, suite counts, not built. Link to the story folder. | 437 to 448 |
| `docs/integration-map.md` | Line 37 (ECONOMY-004 Part A): "Phase 7 made it 79" extended with "V2-ITEM-001a made it 82", the three actions and the new guard name. | 37 |
| `docs/integration-map.md` | New row for V2-ITEM-001a in the Economy table, with ten numbered seams: containers on the Sanctum, party prep and path snapshots; the two actions and the debug action; the one-shot key `data.inventory.refused`; item rows `source: item`; settlement placement `pack_only`; the held-pieces rule; discard rules by screen; result rows; UI-local panels; keys reserved for Part B. | 38 |
| `CONVENTIONS.md` | New last section "Item Containers, Item Text and One-Shot Snapshot Fields (V2-ITEM-001a)". No earlier section covers these topics (grep for `inventory`, `one-shot`, `APPROVED`, `pending_return_confirm` found none). Subsections: player-facing item text, slot model, one-shot snapshot field pattern, panels are UI-local. | 1319 to 1359 |
| `docs/LESSONS.md` | Three new entries at the top of the list, numbers 44, 45 and 46, in the file's format (Rule, Why, How to apply, Mistake count). | 16 to 41 |
| `docs/stories/v2-item-001/handoff.md` | New file. Sections: what shipped, final rules, play-test pointer, known gaps, inputs for ECONOMY-004 Part B, report index, open items for Jeff. | whole file |
| `docs/stories/v2-item-001/step11-docs-report.md` | This report. | whole file |

The exact CONVENTIONS text is in `CONVENTIONS.md` lines 1319 to 1359. Summary of its four conventions:
- (a) Text: all item text is in `ui/components/ItemUiText.gd`; approved lines end with `# APPROVED (Jeff <date>)`; the fixture `tests/fixtures/ItemUiApprovedCopy.json` and the test `inventory_ui/approved_copy_matches_the_fixture_word_for_word` fail on an unapproved change (ANSWERS #89, D-51); to change a line, get Jeff's approval, then change string, fixture and marker date.
- (b) Slots: table with containers, slot, placement (first free slot), no swap (`slot_taken`), merge on a same-type stack, reads never repair, owners.
- (c) One-shot field: five steps (volatile `FlowContext` field, controller sets it, builder adds the key, `FlowRuntime.dispatch` spends it after publish, tests prove one snapshot only and never saved); reference `pending_inventory_refusal`; earlier case `pending_return_confirm`.
- (d) Panels: UI-local state, no flow state, no snapshot type, no `snapshot.actions` slot; `ui.toggle_pack_panel` is intercepted by the shell; moves and discards are per-row actions.

## Numbers checked

| Number | Where verified |
|---|---|
| Dispatch guard 82 | `tests/FlowTransactionTests.gd:30` (`EXPECTED_ACTION_COUNT := 82`) and test `dispatch_action_count_is_82`. Base commit `047c7ec` had `dispatch_action_count_is_79`. |
| 79 to 82 = three actions | `step5-actions.md:15` (79 to 81: discard, producer) and `step7-backend-moves-slots.md` (81 to 82: move). Arms in `core/runtime/FlowRuntime.gd` lines 570, 573, 618. |
| 145 registered suites now, 137 at base | I counted the suite names in `scripts/test-shard-map.sh`: 144 in the 13 shards plus 1 merge suite (`movement_fallback`) = 145. Base commit: 136 plus 1 = 137. AGENTS.md says 137 at `047c7ec` and 145 now (lines 87 and 273). |
| "142 registered suites before the story" (task brief) | NOT correct. 142 was the count after step 6 (`step7-backend-moves-slots.md` row for `scripts/test-shard-map.sh`: "142 to 144"). The count at the base commit is 137. I wrote 137 to 145. |
| `grep -c "register(runner)" ui/AppRoot.gd` = 138 | It counts registration lines, not suites. One line can register several suites. Base commit: 130 lines for 137 suites. I did not use it as the suite count. |
| 8 new suites, 189 new tests | `grep -c runner.register_test` per file: `InventoryActionTests` 25, `InventoryMoveTests` 14, `InventoryPathTests` 29, `InventorySaveTests` 15, `InventoryServiceTests` 22, `InventoryUITests` 43, `ItemPacksCharacterizationTests` 11, `ItemPacksTests` 30. Sum 189. Suite names also in AGENTS.md line 87. |
| Sharded total 2735 of 2735 | Task brief. `step8-ui-build.md:538` and `:556` give 2735 as the expected total. No raw `COMBINED:` line for 2735 is in the repo. |
| Approved copy fixture: 60 keys; 60 lines with the marker | `python3 json.load` of `tests/fixtures/ItemUiApprovedCopy.json` gives 60; `grep -c "APPROVED (Jeff 2026-11-08)" ui/components/ItemUiText.gd` gives 60. `step8-ui-build.md` says 65 keys then 60 after D-52. |
| Shipping config: `unique_cap` 20, `pack_capacity` 4, `stack_limit_default` 20, `warn_room_at` 2, `warn_pack_free_at` 1, `mark_count` 6, `grades` `[]`, `recycle_yield_ekwan` `{}`, `definitions` `{}` | Read from `data/balance.json` with `json.load`. |
| Tone C hex values | `step8-ui-build.md` "Tone C" table. I did not open the `.tres` file. |
| Contrast numbers 1.72:1, 1.45:1, 3.66:1, 4.8:1, 5.2:1 | `mockup-proposal-2-artist.md` lines 11 and 12. |
| Pack tones, edge 1.31:1 | `step10-qa-report.md` line 197 and D-52. |
| Reason keys in the handoff | I grepped each key in `core/inventory/InventoryService.gd`, `InventoryRules.gd`, `InventoryController.gd` and `StageSettlementService.gd`. |
| Fingerprint projection erases `data.inventory` for the Sanctum and `flow.stage_explore` | `tests/FlowSnapshotFingerprintTests.gd` lines 209 to 213. |

## Not verified

- I did not run Godot, the suite or `scripts/check-shard-map.sh` (it needs Godot). The suite count comes from counting names in the shard map, not from the runner.
- The sharded 2735 line itself (see above).
- Lesson 45: "a process started by hand in the background was killed within about a minute, on 2026-11-07 and 2026-11-08". The repo holds no log of this. I wrote it as "reported by the main chat" and marked the source. `step6-fixes.md:82` shows only a different event (the tool moved a run to the background at 120 s).
- Lesson 46 uses different examples from the brief. The brief named "stack draw keyed on slot (step7-qa-report-2 F2-03)". In the report, key-by-slot (mutation M4) IS caught by a test; F2-03 is a design residual found by probe P6. I used the cases where all tests stayed green: F2-04 and F2-05 (all 134 pass), F3-01 (mutation M9 passes; found by probes P10, P11) and F11-02 (all 41 pass).
- The owners "V2-CONTINUITY-002" (pack size by progression) and "V2-ITEM-003" (pack per Echo) come from the task brief. `decisions.md` D-34 only says "note in Notion on the stories that own them". I wrote the story ids as "the task brief names ...". I did not check Notion.
- Whether Jeff looked at the F11-07 label (dim pack button label) during his play test. D-53 approves every part; the record does not say.
- Tone C values were read from `step8-ui-build.md`, not from the theme file.
- Items in the handoff table "Gaps shown only as still frames" repeat the "NOT viewed" lines of `step8-ui-build.md`; I did not re-check them.
- Wording in the new docs: no player-facing "home" or "stage" wording was written. The words appear only as code identifiers (`flow.stage_explore`, `StageSettlementService`, `ReturnHomeModal`, `carry_home_preview`) and as the internal card name "stage-clear card" (the name used by D-30). Player words quoted are Jeff's approved ones: Storehouse, Travel pack, Destroy.

## OPEN — questions and assumptions

ASSUMED: 1. I kept the old dispatch count 79 in `MEMORY.md` and `integration-map.md` as history and added "82 since V2-ITEM-001a", and did not overwrite it. The brief said "update the stale numbers". If you want 79 replaced and not extended, say so.
ASSUMED: 2. The suite count at the base commit is 137, not 142 (see "Numbers checked"). I used 137 to 145. `MEMORY.md` carries no current suite count except the historical line "133 registered suites" (a dated entry), which I left.
ASSUMED: 3. I put the two inventory actions and the debug action into the `integration-map.md` row and the `MEMORY.md` entry, not into the CONVENTIONS "Action Type Registry" table (lines 1043 to 1118). The brief limited CONVENTIONS to the four named conventions. The registry now lacks `inventory.move.apply`, `inventory.discard.apply` and `debug.inventory.produce`. Decide whether a later docs task adds them.
ASSUMED: 4. The handoff says the stale header comment at `core/inventory/InventoryService.gd:23` (invariant 3: "`intake` never puts a piece in `pack` while the Sanctum has room") contradicts mode `pack_only` (D-49). I did not change it (no code edits allowed). It needs a small comment fix by `mechanics-developer`.
ASSUMED: 5. The PR and branch state: I wrote "commit, push and merge are pending" (D-53 says these remain). If the main chat has already committed, update the status line in `MEMORY.md` line 437 and the first row of the `integration-map.md` entry.
BLOCKED: None.
