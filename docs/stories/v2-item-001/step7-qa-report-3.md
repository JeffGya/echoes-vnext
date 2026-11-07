# Step 7 — QA report, round 3 (D-45 fix round)

Status: COMPLETE.

Scope: the uncommitted tree on top of `cae2ff4` (7 files, `255 insertions, 100 deletions`). The verifier changed no
source, test, data or doc file. Diff hash before, after every mutation, after the restart and at the end:
`1e804a317b0d0effa8418c3f61e96406cc26adc522d72596f32ba014a061c73b`.

## Verdict

**FAIL** (one High finding, F3-01). The D-45 intake order is correct for one find in isolation. All conservation
checks hold. But a `gathered` stack find larger than one stack takes several pack slots and ignores the slots that
other open item rows reserve. In play, the pack then holds more entries than its size, and later finds go to slots
above the size. The real seam (`ActiveStageService.record_found_items` then path end, or a leave) reaches it.
No test covers it. The candidate fix (M9) breaks no test, so this is also a test gap.

If Jeff accepts F3-01 as a follow-up, the rest of the round is PASS WITH FINDINGS.

## Findings (most severe first)

| Id | Severity | File:line | Failing scenario (inputs, result) | Suggested fix |
|---|---|---|---|---|
| F3-01 | High | `core/inventory/InventoryService.gd:502` (step 4 loop condition `gathered or pack_free(...)`), `:504-507`; caller `core/economy/StageSettlementService.gd:494`, `:184-187` | Probe P11. Sanctum size 1, full (one weapon). Pack size 3, empty. Real seam `record_found_items` takes 3 finds (3 free slots, one slot per row): `ph_consumable_a` 8 (limit 3), `ph_relic_a`, `ph_armor_a`. Path end (P11, P10 path) or leave with outcome all (P10 leave). Result: pack stacks 3@0, 3@1, 2@2; relic@3; armor@4. Five entries in a pack of 3. `validate` = `pack: 5 entries above pack_capacity`, `pack[0]: slot 3 at or above the size 3`, `pack[1]: slot 4 at or above the size 3`. Probe P13 (Sanctum 2, pack 2, find 13 + relic) gives the same defect, and `preview` shows it too (preview == payout). Cause: a gathered chunk never checks `reserved`, so the first row takes the slots that the later rows own. Before D-45 a stack find started at most one stack, so this was not reachable. | Smallest fix: the FIRST new pack stack of a gathered find keeps its owned slot (as now). Every further chunk needs `pack_free(save, cfg, later_rows) > 0`, where `later_rows` = open item rows not yet settled after this one. `_bank_rows` and `_settle_leave_items` pass `rows.size() - index - 1` for gathered intake. Do NOT ship M9 as it is: it passes the constant `rows.size()`, which also counts rows already in the pack, so it over-reserves (rows [relic, consumable 8], pack 4 empty: M9 keeps 3 and loses 5, but slots 2 and 3 are free and could hold 5; traced by reading the code, not run). Add a test: the P11 scenario through `record_found_items`, assert pack count <= size, `validate` empty, and the stack remainder lost with its reason. |
| F3-02 | Low (decision for Jeff) | `core/inventory/InventoryService.gd:519` | Probe P5b: Sanctum and pack full, direct find of 8 (limit 3): `lost/stack_limit`, 0 kept, 8 lost. D-45 says "lost (`overflow`; or `stack_limit` for a surplus above the limit when no slot can hold it)" and F2-01 says "a find is lost only when both containers are full". Under D-45 every loss is caused by no free slot, because a surplus can always start a new stack. So the split "find above the limit = `stack_limit`" (builder ASSUMED 1) is a choice, not a rule. Probe P2b: 8 of 20 lost for lack of slots also reports `stack_limit`. | Ask Jeff. Option A: keep the builder rule. Option B: `overflow` for every loss caused by no slot; `stack_limit` only when the limit itself is 0 or invalid. Option B changes `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full`, `item_packs/partial_stack_keeps_the_stored_quantity` and the M5 set. |
| F3-03 | Low (stale text) | `data/balance.json:3743`; `tests/ItemPacksTests.gd:660-661` | (1) `_stack_limit_comment`: "Surplus above the limit is lost." Since D-45 a surplus starts a new stack; only what no slot holds is lost. (2) The docstring of `_t_preview_equals_payout` says "a full Sanctum (two pieces, cap 2), a stack at its limit (4 of 5, a find of 3 loses 2)". The test now uses cap 3, consumable limit 3 and a find of 12. | Rewrite both comments. Comment text only (the balance comment is a data file: Jeff or the mid designer owns it). |
| F3-04 | Info (coverage drift) | `tests/InventoryServiceTests.gd:487`, `:494` | The pinned script call 11 (`discard(save, cfg, "it.4", true)`) now gives `refused/not_found/it.4`. The pinned script no longer covers a successful discard of a pack piece. `inventory_service/discard_outcomes` (`:381`) still covers it, so nothing is unprotected. | Optional: discard `it.3` (now in the pack) so the pinned script keeps a pack-piece discard, then re-pin. |
| F3-05 | Info | `docs/stories/v2-item-001/step7-backend-moves-slots.md:36`, `:134-135` | Earlier sections of the builder report still say "never starts a second stack for a surplus" and "A new stack into a full Sanctum is lost with `overflow`". The D-45 section later replaces them. | None needed (history). Optionally mark them "superseded by D-45". |

## Rules verified

| # | Rule | Evidence | Result |
|---|---|---|---|
| 1 | D-45 order 1-2-3-4-5 for one find | P1-P4c, P7; M1, M2, M3 each fail tests | HOLDS |
| 1a | A find can span several steps | P3 (merge 1, new Sanctum 3, pack 3 and 2), P4 | HOLDS |
| 1b | Conservation (in = stored + lost) | Every integer probe P1-P13: OK | HOLDS |
| 1c | Both containers full: nothing changes | P5: save JSON equal before and after | HOLDS |
| 1d | `direct` respects reserved item-row slots (F-05) | P6; M4 fails a test | HOLDS |
| 1e | `gathered` respects slots reserved by OTHER rows | P6b, P10, P11, P13 | FAILS (F3-01) |
| 1f | Bad quantity / unknown / disabled type is rejected, save unchanged | P8, P9, P12 | HOLDS |
| 2 | Reason keys: builder rule (`stack_limit` iff find > limit, else `overflow`) | P2b, P3b, P5, P5b; M5 fails 5 tests | HOLDS as built; rule itself open (F3-02) |
| 2a | Same reason in result rows, early-leave rows, path-end report, preview | P10 path/leave, P13: same `reason_key` and `lost_quantity`; `preview` == payout | HOLDS |
| 2b | `preview` equals the payout for the new order | P10, P13 true; test bites on M8 | HOLDS |
| 3 | D-42: only `inventory.move.apply` moves between pack and Sanctum | Cross-container removal only in `_move_entry` (`InventoryService.gd:664`, `:677-679`); `remove_at` at `:623` is discard; `remove_held` only removes; no other core file writes `inventory` arrays (`SaveService.gd:389` creates an empty block) | HOLDS |
| 3a | D-43 draw key unchanged | Diff hunks are at lines 11, 152, 269, 286, 469; `held_pieces` / `draw_id` (`:120-150`) untouched | HOLDS |
| 7 | Determinism | Probe P1-P9 run twice: outputs byte-equal (`cmp`); intake uses no RNG, time or OS call | HOLDS |
| 7a | No `ui/` change | `git diff --stat -- ui/` empty | HOLDS |
| 7b | Dispatch action guard 82 | `flow_transaction/dispatch_action_count_is_82` passes | HOLDS |
| 7c | Both snapshot fingerprints | `snapshot_fingerprint — 2 passed` | HOLDS |
| 7d | Compile check | `--check-only --quit`: 0 `SCRIPT ERROR` | HOLDS |
| 7e | Shard map | `SHARD MAP CHECK: OK (144 registered suites, each in exactly one of 13 shards or the merge step).` | HOLDS |

## Test integrity (versus HEAD `cae2ff4`)

Test functions and registered names: identical in all four files (13, 18, 22, 30 `_t_` functions, same at HEAD).
No test is added, removed or renamed.

| Test | Change | Judgement |
|---|---|---|
| `inventory_paths/a_new_stack_find_is_kept_in_the_pack_when_the_sanctum_is_full` | "two pack stacks" replaced by "one pack stack of quantity 3" | Correct re-pin for F2-02. Stronger (it now checks the quantity). M1 fails it. |
| `inventory_service/stack_merge_and_limit` | `partial/stack_limit` re-pinned to `stored/ok` with split counts; `at_limit` 2 -> 4 | Correct for F2-01. Still checks quantities and counts. The limit-0 case is kept. M2, M5 fail it. |
| `inventory_service/fixed_calls_give_the_pinned_save` | `_PINNED_RESULTS` and `_PINNED_SAVE` re-pinned | One named cause (D-45). Traced: call 4 (consumable 4) now spills 1 into the pack, so the pack fills earlier and calls 6-9 are `lost/overflow`. Coverage drift at call 11, see F3-04. Not a change made only to pass. |
| `inventory_service/cfg_of_the_wrong_type_does_not_crash` | two expectations `partial/stack_limit` -> `stored/ok` | Purpose (no crash, default fallback) kept: it still checks `stacks[0]` quantity 5. M5 fails it. |
| `inventory_service/stack_above_a_lowered_limit` | lost -> new stack of 2 | Correct for D-45. It still checks that the old stack keeps 5 (no shrink). |
| `item_packs/partial_stack_keeps_the_stored_quantity` | ctx (8,4) -> (1,1) with one weapon; asserts the pack stack | Needed: with a large Sanctum D-45 keeps all 8. The case (3 kept, 5 lost) is kept. M5, M6, M7 fail it. |
| `item_packs/path_end_preview_equals_the_payout_report` | consumable find 3 -> 12 | Needed to keep a `lost_quantity` row. M6, M7, M8 fail it. Docstring stale (F3-03). |
| `inventory_moves/intake_takes_the_lowest_free_slot` | last case re-pinned; pack merge, partial/overflow and both-full added | Stronger. M1, M5 fail it. |
| `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` | rewritten (8 cases) | Stronger than HEAD. Removed: unique "piece, both full" (still covered at `InventoryServiceTests.gd:246`, `:768`) and a weak `validate` check (replaced by a strict one on case b). Gap: no case for a gathered find that needs more than one pack slot while other rows reserve slots (F3-01; M9 passes). |
| `inventory_moves/held_stacks_are_settled_like_held_pieces` | extended (F2-04) | Added assertions only. |
| `inventory_moves/_t_resize` | comment only | Fine. |

No test was changed only to pass. Every re-pin follows D-45 and still bites (see mutations).

## Stale text grep

Patterns: "surplus is lost", "surplus above", "ASSUMED shrink", "no size ever shrinks", "size cut",
"never takes a pack slot", "never starts a second stack", "lost while", "stack goes to its Sanctum stack".
Searched `core/`, `ui/`, `tests/`, `data/`, `AGENTS.md`, `docs/` (story history excluded except the builder report).

| Hit | Status |
|---|---|
| `data/balance.json:3743` "Surplus above the limit is lost." | STALE, F3-03 |
| `tests/ItemPacksTests.gd:660-661` docstring | STALE, F3-03 |
| `step7-backend-moves-slots.md:36`, `:134-135` | History, F3-05 |
| `core/` comments (`InventoryService.gd:14`, `:155`, `:272-280`, `:295`; `InventoryController.gd:21`) | Fixed in this round, correct |
| `tests/InventoryMoveTests.gd:227` | Fixed, correct |

## Probes tried (raw results; scripts in the verifier scratchpad, outside the tree)

Fixture: `ph_consumable_a` limit 3. `cfg(cap, pack)` = `InventoryServiceTests._cfg`. "Cons" = conservation check:
quantity added to stacks = result `quantity`, and `quantity` + `lost_quantity` = find quantity.

| Id | Input | Result | Cons | Verdict |
|---|---|---|---|---|
| P1 | cfg(4,4), Sanctum cons 3/3, gathered find 2 (round-2 example) | `stored/ok` q2, new Sanctum stack slot 1, pack empty | OK | Pass |
| P2 | cfg(4,4) empty, find 10 | `stored/ok`, Sanctum 3,3,3,1 | OK | Pass |
| P2b/c | cfg(2,2) empty, find 20, direct and gathered | `partial/stack_limit` q12 lost 8, Sanctum 3,3, pack 3,3 | OK | Pass (reason per builder ASSUMED 1) |
| P3 | cfg(2,2), Sanctum cons 2, gathered find 9 | `packed/to_pack` q9: merge 1, Sanctum 3, pack 3,2 | OK | Pass |
| P3b | same, find 12 | `partial/stack_limit` q10 lost 2 | OK | Pass |
| P4 | cfg(2,4), Sanctum cons [2@1,1@0], pack [1@2,2@0], find 5 | Sanctum 3,3 (array order), pack 3,2 | OK | Pass |
| P4b/c | then find 2, then find 4 | merge pack first, then new pack stacks 1@1, 2@3 | OK | Pass |
| P5 | cfg(1,1) both full, direct find 2 | `lost/overflow`, save unchanged | OK | Pass |
| P5b | both full, direct find 8 | `lost/stack_limit` q0 lost 8 | OK | See F3-02 |
| P5c/d | both full, gathered find 2 / 8 | one stack at slot 1 (above size 1), `validate` reports it | OK | As designed (F2-06) |
| P6 | cfg(1,3), Sanctum full, direct, reserved 2, find 8 | `partial/stack_limit` q3 lost 5, one pack stack | OK | Pass (respects reserved) |
| P6b | same, gathered, reserved 3, find 8 | `packed/to_pack` q8, THREE pack stacks (slots 0,1,2) | OK | See F3-01 |
| P7 | cfg(2,2), find 3 three times | 3@S0, 3@S1, then 3@P0; `at_limit` true | OK | Pass |
| P8 | quantity 0, -1, 2.5, "3", null, 1e20 | `rejected/bad_entry` each, save unchanged | n/a | Pass |
| P8b | quantity 3.0 (whole float) | `stored/ok` q3 | n/a | Pass (tolerant read, same as before) |
| P9 | unknown type (kind consumable) / disabled kind | `rejected/unknown_type` / `rejected/kind_disabled` | n/a | Pass |
| P9c | stack limit 0 (cfg default 0) | `lost/stack_limit` q0 lost 2 | OK | Pass |
| P10 | Play: Sanctum 1 (full), pack 3, rows cons 8, relic, armor; path end AND leave (all) | pack holds 3 stacks + relic@3 + armor@4: 5 entries, size 3; `validate` = 3 errors | OK | FAIL, F3-01 |
| P11 | Same through the real seam `ActiveStageService.record_found_items` (all 3 finds taken) then path end | same as P10 | OK | FAIL, F3-01 |
| P13 | Sanctum 2 with cons 2, pack 2, rows cons 13 + relic; preview vs payout | preview == payout true; relic@2 above size 2 | OK | FAIL, F3-01 |
| P10/P13 | `preview` equals payout | true in both | - | Pass |

## Mutation checks

Each mutation: copy to `/tmp/claude-0/qa3-backup`, one edit, one short run of
`=inventory_paths,inventory_moves,inventory_actions,inventory_service,inventory_save,item_packs,item_packs_char`
(baseline `Tests: 134 total, 134 passed, 0 failed`), restore by `cp` in a `trap`, `cmp` equal, diff hash re-checked
after each (`1e804a31…c73b` every time).

| Id | Mutation | File:line | Result (raw) | Failing tests | Restored, cmp |
|---|---|---|---|---|---|
| M1 | Skip step 3 (pack merge): `take = 0` | `core/inventory/InventoryService.gd:496` | `134 total, 131 passed, 3 failed` | `inventory_moves/intake_takes_the_lowest_free_slot`, `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full`, `inventory_paths/a_new_stack_find_is_kept_in_the_pack_when_the_sanctum_is_full` | Yes, equal |
| M2 | Skip step 2 (new Sanctum stack): `while false` | `:486` | `134 total, 102 passed, 32 failed` | `inventory_service/stack_merge_and_limit`, `fixed_calls_give_the_pinned_save`, `item_packs/path_end_banks_item_rows_once` and 29 more | Yes, equal |
| M3 | Step 2 block moved after step 4 (pack before Sanctum) | `:485-494` | `134 total, 102 passed, 32 failed` | same set as M2 | Yes, equal |
| M4 | Direct step 4 ignores `reserved`: `pack_free(save, cfg, 0)` | `:502` | `134 total, 133 passed, 1 failed` | `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` | Yes, equal |
| M4g | "Gathered ignores reserved in step 4" | `:502` | Not applied: the code ALREADY ignores `reserved` for every gathered chunk. This is F3-01. | - | - |
| M5 | Swap `stack_limit` and `overflow` | `:519` | `134 total, 129 passed, 5 failed` | `inventory_service/stack_merge_and_limit`, `inventory_service/cfg_of_the_wrong_type_does_not_crash`, `item_packs/partial_stack_keeps_the_stored_quantity`, `inventory_moves/intake_takes_the_lowest_free_slot`, `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` | Yes, equal |
| M6 | Drop the remainder (`lost_quantity` 0) | `:520` | `134 total, 131 passed, 3 failed` | `item_packs/partial_stack_keeps_the_stored_quantity`, `item_packs/path_end_preview_equals_the_payout_report`, `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` | Yes, equal |
| M7 | Gathered always goes above the pack size (`if not gathered:`) | `:506` | `134 total, 131 passed, 3 failed` | `item_packs/partial_stack_keeps_the_stored_quantity`, `item_packs/path_end_preview_equals_the_payout_report`, `inventory_moves/a_new_stack_takes_a_pack_slot_when_the_sanctum_is_full` | Yes, equal |
| M8 | Preview banks the rows in reverse order | `core/economy/StageSettlementService.gd:223` | `134 total, 133 passed, 1 failed` | `item_packs/path_end_preview_equals_the_payout_report` | Yes, equal |
| M9 | Candidate fix for F3-01: a gathered find takes extra pack slots only while `pack_free(reserved) > 0` | `core/inventory/InventoryService.gd:502` | `134 total, 134 passed, 0 failed` | NONE (no test pins the multi-slot gathered case; the fix breaks nothing) | Yes, equal |

Note on the preview test: an order mutation inside `_intake_stack` (M1 to M3) changes the preview and the payout in the
same way, because both run `_bank_rows`. The preview test cannot see an order change in the service by design.
It bites on a preview-only change (M8). The order itself is pinned by the `inventory_moves` and `inventory_service` tests.


## Evidence

| Item | Raw line |
|---|---|
| Diff hash, start | `1e804a317b0d0effa8418c3f61e96406cc26adc522d72596f32ba014a061c73b  -` |
| Diff hash, after each mutation, after restart, at end | `1e804a317b0d0effa8418c3f61e96406cc26adc522d72596f32ba014a061c73b  -` |
| Baseline 7 inventory suites | `Tests: 134 total, 134 passed, 0 failed` |
| Contract suites `=flow_transaction,snapshot_fingerprint,snapshot_purity,snapshot_contract` | `Tests: 31 total, 31 passed, 0 failed` (flow_transaction 9, snapshot_fingerprint 2, snapshot_purity 12, snapshot_contract 8) |
| Compile check | 0 `SCRIPT ERROR` lines |
| Shard map | `SHARD MAP CHECK: OK (144 registered suites, each in exactly one of 13 shards or the merge step).` |
| Full sharded suite (main chat, same tree) | `COMBINED: 2680 total, 2680 passed, 0 failed` |
| M9 play probe (candidate fix applied, then restored, `cmp` equal) | P10/P11: pack stacks 3@0, relic@1, armor@2, `validate=[]`; consumable `q3 stack_limit lq5` |

## OPEN — questions and assumptions

- BLOCKED: None.
- ASSUMED: F3-01 is in scope for this round. A stack find above one stack is rare with `stack_limit_default` 20, but no rule caps a find's quantity. Jeff decides: fix now, or record a follow-up.
- ASSUMED: The intended rule for F3-01 is "each open row owns exactly one pack slot; extra chunks of a stack find use only unreserved free slots". D-45 does not say this. If Jeff wants a find to use reserved slots, the item-row reservation (`record_found_items`) must count slots per stack quantity instead.
- QUESTION for Jeff (F3-02): which reason does a lost stack remainder report when no slot is left, `overflow` always, or `stack_limit` when the find is larger than one stack (builder ASSUMED 1)?
- ASSUMED: the round-2 check "dispatch guard 82" means `flow_transaction/dispatch_action_count_is_82`.
- ASSUMED: probes run by `--script` from the scratchpad are equal to tests in effect; they changed no tree file (hash unchanged).
