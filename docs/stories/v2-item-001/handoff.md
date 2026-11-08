# V2-ITEM-001a handoff

Written in STE. Date: 2026-11-08. Status: built, tested and approved by Jeff after his play test (`decisions.md` D-53). The main chat commits, pushes and marks the PR ready; Jeff merges (D-53). Each statement below cites a file or a decision. Where a fact comes only from the task brief, the text says so.

Terms. Player words: Storehouse (the Sanctum inventory) and Travel pack (the party pack). Code words: `sanctum` container and `pack` container. A held piece is an entry that was already in the pack before the path started (D-19).

## 1. What shipped

| Feature | Where | Decision |
|---|---|---|
| Item model: unique pieces (gear, relics) and stacks (consumables, materials) | `core/inventory/InventoryService.gd` | D-01, D-05, D-06 |
| Two containers: Sanctum inventory and party pack | `InventoryService.gd`; config `data.inventory`; save block `inventory` | D-13, D-16, D-33 |
| Saved slot per entry, first free slot, no swap, merge on a same-type stack | `InventoryService.gd` (`move_entry`, `_layout`) | D-34, D-37 |
| Moves between containers and inside a container | `inventory.move.apply`, `core/runtime/controllers/InventoryController.gd` | D-33, D-34, D-40 |
| Destroy (discard) with a count for stacks; one per path on a path | `inventory.discard.apply`, `InventoryController.gd`, `core/inventory/InventoryRules.gd` | D-11, D-21, D-33, D-34 |
| Item rows in the earnings packs (`source: item`) | `core/economy/EarningsService.gd` (`record_item`) | D-13, D-18 |
| Early-leave draw per item and held piece; defeat loses both; path end places new finds in the pack | `core/economy/StageSettlementService.gd`, `core/realms/ActiveStageService.gd` | D-03, D-19, D-20, D-22, D-42, D-49 |
| One-shot refusal key `data.inventory.refused` | `FlowContext.pending_inventory_refusal`, `InventoryRules.projection`, `FlowRuntime.dispatch` | D-48 |
| Item `name` on at-risk rows and result rows | `EarningsService.at_risk_row`, `report_row` | D-48 |
| Storehouse panel (rail button), Travel pack panel (party details and path HUD), destroy modal | `ui/components/InventoryPanels.*`, `PartyPackButton.*`, `ui/overlays/ItemDiscardModal.*`, shells | D-33, D-34, D-35, D-39 |
| Item row inside the leave, defeat and stage-clear cards; at-risk row in the leave confirmation | `ui/components/ItemResultRow.*`, `ResolveScreen`, `ReturnHomeModal` | D-23, D-30, D-32, D-42 |
| Approved item text, one file, fixture guard | `ui/components/ItemUiText.gd`, `tests/fixtures/ItemUiApprovedCopy.json` | D-51, ANSWERS #89 |
| Pack tone C (plain `#7A5B3E`, near full `#4F3B28`, full `#120E0C`), no decoration | `assets/theme/LivingTreeSystem.tres` | D-36, D-49, D-50, D-51 |
| Debug producer `inventory produce [direct\|gather]` (debug builds only) | `ui/AppRoot.gd`, `DebugController.handle_inventory_produce`, `tests/fixtures/inventory_placeholders.json` | D-27, D-28 |
| Tests: 8 new suites, 189 tests (counted from `register_test` lines) | `tests/Inventory*Tests.gd`, `tests/ItemPacks*Tests.gd` | D-25 |
| Dispatch guard 79 to 82 | `tests/FlowTransactionTests.gd` (`EXPECTED_ACTION_COUNT` 82) | none |
| Registered suites 137 (base commit `047c7ec`) to 145 | `ui/AppRoot.gd`, `scripts/test-shard-map.sh`, AGENTS.md | none |

Verified build: sharded suite 2735 of 2735 (task brief; `step8-ui-build.md` last section expects 2735). The raw `COMBINED:` line is not in the repo.

## 2. Final rules

| Topic | Rule | Source |
|---|---|---|
| Containers | Sanctum: `inventory.items` and `inventory.stacks`, size `data.inventory.unique_cap` (shipping 20). Pack: `inventory.pack` and `inventory.pack_stacks`, size `pack_capacity` (shipping 4). Both numbers are PROVISIONAL and may grow. The Sanctum never shrinks. | D-25, D-34, D-40; `data/balance.json` |
| Slots | Each entry (piece or stack) has a saved `slot` and fills one slot. A move or an intake takes the first free slot unless a target slot is given. | D-37, D-40 |
| Move | Allowed on `flow.sanctum` and `flow.echo_party`, also while a saved path is live. Refused on the path view (`path_open`). Nothing moves by itself, at path end or after a leave. | D-40, D-42; `InventoryRules.mode` |
| No swap | A move onto an occupied slot is refused (`slot_taken`). The player reorders into an empty slot. | D-34, D-40 |
| Merge | A stack dropped on a same-type stack merges up to the stack limit. A merge needs no free slot. | D-34, D-40 |
| Destroy in the Storehouse (Sanctum and party prep screens) | Unlimited. Any entry, either container. A stack takes a count from 1 to its quantity. The player confirms each time. | D-21, D-34, D-40 |
| Destroy on a path | ONE per path, on a pack entry only. The mark is the saved stage field `discard_used`. A successful early leave, a defeat and the path-end settlement clear it. | D-21, D-33, D-34; `InventoryRules.gd` |
| New finds | Each find is an item row that owns one reserved pack slot. At a path end or after a kept early leave, a surviving find goes to the pack, never to the Sanctum. A find that finds no pack slot is lost (`overflow`). | D-17, D-46, D-47, D-49 |
| Early leave | Outcome none: items lost. Outcome all: items kept. Outcome some: one seeded draw per item and per held piece, at the share of the "some" outcome. Held pieces are drawn again on every early leave, also on a repeat leave. | D-03, D-19, D-22 |
| Defeat | Gathered finds and held pieces are all lost (reason `defeat`). | D-20 |
| Path end | New finds are placed in the pack. Held pieces are not drawn. | `step4-packs-rules.md` (Defeat, path end); D-49 |
| Carried means at risk | A find that survives a path sits in the pack as a held piece. A later early leave draws it again and a defeat loses it. The player moves it to the Storehouse to make it safe. | D-53 |
| Pack penalty | None. The cost is lost room and the risk to held pieces. The pack shows a heavier tone as it fills. | D-36, D-51 |
| Stack finds | A find larger than one stack can lose units under pack-only placement. Nothing is minted and the pack never exceeds its size. | D-50 (F10-01) |
| Draw keys | `inventory.leave.<stage_id>.<run_count>.<settle_count>.<row\|held>.<id>`. A held stack is named by its type and its order among held stacks of that type, not by its slot. The `stage.settle` stream is unchanged. | D-43; `step7-backend-moves-slots.md` (Fixes after QA) |
| Saved values | Block `inventory { version, next_seq, items, stacks, pack, pack_stacks }`; `slot` on each entry; stage fields `held_fates` and `discard_used`; item rows in `stage.earnings`. No repair for old saves. | `step2-config-save.md`; `step7-backend-moves-slots.md`; D-38 |
| Not saved | `FlowContext.pending_inventory_refusal` and the panel open state. | D-48, D-33 |
| Text | All item text is in `ItemUiText.gd`. Each line is approved by Jeff and guarded by a fixture test. | D-51, ANSWERS #89 |

## 3. How to play-test

Use `playtest-plan.md` (second round). It sets up a separate copy of the branch `claude/vibrant-tesla-x3ejvi`, build `a59a23d`. It has Parts 0 and A to K. Jeff marked Parts A to K approved and Part F passed (D-53). The debug producer `inventory produce direct` puts placeholder items in the containers; `inventory produce gather` writes item rows on a live path (`DebugController.gd:561`).

## 4. Known gaps and deferred work

| Item | State | Owner or decision |
|---|---|---|
| F8-02: finds gathered on a path are not drawn in the pack panel and not counted by the pack button. The pack can read full with empty sockets. | Deferred. Jeff: finds are not handled here. A player sees no sign of a find until the path ends. | D-48, D-49. Finds story ITEM-002 and 001b |
| Real drops, `loot_results` delivery, replay rule for items | Not built | ITEM-002 (`design-round1-sr-game-designer.md` line 160) |
| Echo choice at pickup, left list, keeper swap, path packs view | Not built. The default seam fills the pack in find order | 001b (D-12, D-14, D-15, D-18). A Notion row needs Jeff's yes |
| Pack shrink rule (pieces in closing slots move to the Storehouse; surplus lost; player chooses at party prep) | Designed, deferred. Core builds nothing. The tolerant read of a stored slot above the size is not a shrink rule | D-41. The story that contains shrinking packs |
| F10-02: a pack-size change can overfill the pack when rows are written by hand | Recorded, no change | D-50. The pack-shrink story |
| Pack size by progression (Sanctum progression sets the party's maximum pack size) | Out of scope | D-34; the task brief names V2-CONTINUITY-002 for a note |
| Pack size per Echo (each Echo adds 1 slot, more with progression) | Out of scope | D-34; the task brief names V2-ITEM-003 for a note |
| Recycle and "discard or recycle as many times as wanted" | Not built. Config key `recycle_yield_ekwan` is reserved and empty | D-02, D-21. ITEM-004 |
| Item catalogue (names, categories, grades, art, descriptions) | No Notion row owns it. `data.inventory.definitions` and `grades` are empty | `decisions.md` OPEN. Needs Jeff's decision |
| Crafting with materials | Not built | D-07. A Notion row needs Jeff's yes |
| F10-01: a big stack find loses units | Accepted | D-50. ITEM-002 decides the rule for leftover units |
| F11-03: two refusal lines under two disabled buttons on a path | Left for the UX redesign | D-52 |
| F11-04: the full-tone panel edge is 1.31:1 on the dark path world | Left for the UX redesign | D-52; `step10-qa-report.md` |
| K1 (the pack feels hidden), K2 (text very small), Parts A and C (placement and hierarchy of the two panels) | Left for Jeff's larger UX redesign of everything. Buttons and panels work | D-49 |
| K6 reduced motion | Ignored. No reduced-motion option exists yet | D-49 |
| F11-07: the pack button label looks dim in the screenshot harness | Assigned to Jeff's play test. D-53 approves every part; the record does not say he looked at this label | D-52, D-53 |
| Stale header comment: `InventoryService.gd:23` says `intake` never puts a piece in `pack` while the Sanctum has room. Mode `pack_only` does the opposite on purpose. | Found while writing this handoff. Not changed (this task edits no code) | D-49 |
| Gaps shown only as still frames: motion, 1920x1080 views of the later fixtures, a real touch drag | Not verified visually | `step8-ui-build.md` section 8; last "NOT viewed" lines |

## 5. Inputs for ECONOMY-004 Part B (item costs)

What 001a provides:

| Input | State today | Source |
|---|---|---|
| Cost shape | `cost: { ekwan: int, ase: int }` on an item definition. It is described in the key `_definitions_comment` of `data.inventory`. The shipping `definitions` block is empty. The test fixture sets every cost to 0. No code in `core/` or `ui/` reads `cost`. | `data/balance.json`; `tests/fixtures/inventory_placeholders.json`; grep of `core/` and `ui/` |
| Recycle yield | `data.inventory.recycle_yield_ekwan` is `{}`. It has one key per grade, Ekwan only. No code reads it. | `data/balance.json`; D-02, D-06 |
| Grades | `data.inventory.grades` is `[]`, an ordered list, lowest first. | D-26 |
| Item rows in the packs | `source: item`, id `item:<situation_id>:<find_id>`, `ase` 0, `ekwan` 0, `scaled` false, `items` holds one entry. `EarningsService.plan` returns `sources.item` with `ase` 0. Currency sums are unchanged. | `core/economy/EarningsService.gd`; `step4-packs-rules.md` |
| Materials | Materials stack like consumables. They are crafting inputs only: never a price, never sold, never shown as a balance. | D-06 |
| Capacity and slots | Container sizes `unique_cap` and `pack_capacity`; stack limit `stack_limit_default` (a definition may override with `stack_limit`). | `data/balance.json` |

Reason keys now in use in `core/inventory/InventoryService.gd` (result `reason_key`):

| Group | Keys |
|---|---|
| Intake | `ok`, `bad_entry`, `unknown_kind`, `kind_disabled`, `unknown_type`, `overflow`, `to_pack` (a result; the settlement no longer produces it), `bad_state` |
| Move | `unknown_entry`, `bad_box`, `bad_slot`, `no_change`, `slot_taken`, `type_mismatch`, `stack_limit`, `container_full`, `bad_state` |
| Discard | `unknown_entry`, `bad_box`, `not_found`, `not_unique`, `count_range`, `equipped`, `bad_state`, `not_in_sanctum` |

Keys from other files: `InventoryRules.gd` also gives `not_in_sanctum`, `path_open`, `not_in_pack`, `path_used`, `no_stage`; `InventoryController.gd` gives `bad_payload`; `StageSettlementService` and `ActiveStageService` give the result-row reasons `leave_none`, `leave_some`, `defeat`. The UI maps them in `ItemUiText.reason_text`.

What Part B must decide (these are questions for Jeff and the designer; 001a decides none):
1. The Ase and Ekwan cost of each item type, and where a cost is charged. 001a charges nothing.
2. The recycle yield in Ekwan for each grade, after the catalogue story defines the grades.
3. Whether an item row carries a currency value in the packs. Today it carries none.
4. How a cost relates to materials (D-06 and D-07: crafting inputs, not a price).
5. Whether Part B needs a Notion row. `decisions.md` OPEN says no row exists for ECONOMY-004 Part B.

## 6. Reports in this folder

| File | Purpose |
|---|---|
| `decisions.md` | D-01 to D-53. The later decision wins. |
| `research-comparison.md` | How other games handle shared inventory, loot, loss and cap pressure (D-10). |
| `research-ui-best-practices.md` | UI best-practice research for the item screens (web summaries only, weak evidence). |
| `design-round1-sr-game-designer.md` | Design round 1: model, rules, scope, open questions. |
| `design-round2-game-feel-developer.md` | Feel design round 2. |
| `design-sr-game-designer-v2.md` | Consolidated design, corrected for D-17 to D-21. |
| `design-feel-game-feel-developer-v2.md` | Feel design v2, corrected for D-17 to D-21. |
| `mockup-proposal-1-ui-ux.md` | UI/UX proposal: structure, layout, flows. |
| `mockup-proposal-2-artist.md` | Artist proposal: look, marks, colour. Holds the measured contrast numbers. |
| `mockup-proposal-3-game-feel.md` | Game-feel proposal: motion, timing, feedback. |
| `mockup-proposal-merged.md` | Merged proposal with Jeff's answers (D-31, D-32). |
| `pack-debuff-options-designer.md`, `pack-debuff-options-feel.md` | Options for a full-pack penalty. Jeff chose no penalty (D-36). |
| `pack-shrink-options-designer.md`, `pack-shrink-options-feel.md` | Options for a pack shrink with a full Sanctum. Jeff chose feel option B (D-41). |
| `step1-characterization.md` | Characterization of the item-free packs before any change. |
| `step2-config-save.md` | Config block `data.inventory` and the save block. |
| `step3-inventory-service.md` | The inventory service API and invariants. |
| `step4-packs-rules.md` | Item rows, leave draws, defeat and path end. |
| `step5-actions.md` | The discard action, the debug producer and the snapshot field. |
| `step6-fixes.md` | Fix pass after the first combined QA. |
| `step6-qa-report.md` | Combined-tree QA of steps 1 to 5. |
| `step7-backend-moves-slots.md` | Slots, moves, count discards, one discard per path, and every later core fix round. Its last sections win. |
| `step7-qa-report.md`, `step7-qa-report-2.md`, `step7-qa-report-3.md`, `step7-qa-report-4.md` | QA rounds 1 to 4 of the step 7 core work. |
| `step8-ui-build.md` | UI build and every later UI fix round, including the approved copy and tone C. Its last sections win. |
| `step8-qa-report.md`, `step8-qa-report-2.md` | QA of the UI build and of its first fix round. |
| `step9-qa-report.md` | QA of the D-49 changes (finds stay in the pack, strap line removed). |
| `step10-qa-report.md` | QA of the approved copy, the removals and tone C. |
| `copy-approval.md` | Every player line with a suggestion, sent to Jeff. |
| `copy-approval-jeff.md` | Jeff's marked-up picks. The source of the approved wording (D-51). |
| `playtest-plan.md` | The second-round play-test plan. |
| `step11-docs-report.md` | Report of the docs pass that wrote this file. |

Also in the repo: the prototype `docs/visual-plans/inventory-ui-mockup-v2.html` (the UI contract, D-44).

## 7. Open items for Jeff

| Item | Detail |
|---|---|
| Notion rows | None is written for 001b (Echo choice, left list, keeper swap; D-18). None is written for the Echo decision model (D-15). None is written for the crafting follow-up (D-07). None is written for the item catalogue or for ECONOMY-004 Part B (`decisions.md` OPEN). Each needs Jeff's yes. |
| Pack debuff idea | Closed by D-36. There is no rule to own. |
| Notion duplicates | ITEM-005 (Order 249.2 and 259) and ECONOMY-002 (Order 242 and 360). Which row is open? (`decisions.md` OPEN) |
| Design-system contrast numbers | After this story, fix the design-system file. It states gold on a warm panel as 4.8:1 and warm tan `#8B7355` as 5.2:1. Measured: gold on `#F5E6D3` is 1.72:1 (1.45:1 on `#E0D5C3`) and tan is 3.66:1. Source: `mockup-proposal-2-artist.md` lines 11 and 12. |
| UX redesign | K1, K2, parts A and C of the play test, F11-03 and F11-04 (D-49, D-52). |
| Merge | Commit, push, mark the PR ready (main chat), then Jeff merges (D-53). |
