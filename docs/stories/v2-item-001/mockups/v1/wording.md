# Wording for the v1 mockups (ITEM-001)

> AGENT-WRITTEN PLACEHOLDER wording. Jeff edits it after the play test. It replaces the `[Jeff's wording]` marks and grey `name-bar` slots so the screens can be read and clicked. Word rules: ANSWERS #86 (no "home", no "stage"; Sanctum, path, lost). No "banked", "settled" or "roll". No odds.

## Table 1: game text

| Slot id | Appears on | PLACEHOLDER text | Explains (key or state) | Note |
|---|---|---|---|---|
| rail-inventory | BottomRail (S1, all rail screens) | Pack | Sixth rail button | Short label for a 6-button rail |
| inv-title | Inventory (S1) | What we keep | Screen title | |
| inv-cap-gauge | Inventory | Pieces: %d of %d | Cap gauge, `unique_cap` | |
| inv-cap-full | Inventory | The Sanctum is full. | Cap gauge at full | From design section 8 (shortened) |
| inv-row-carried | Inventory | Carried from before | Carried row | |
| inv-grid-pieces | Inventory | In the Sanctum | Piece grid label | |
| inv-row-stacks | Inventory | Stacks | Stack row label | |
| inv-stack-limit | Inventory (stack tile) | At the limit | Stack at limit mark | |
| inv-empty | Inventory | Nothing is stored yet. | Empty state | PROPOSAL from game-feel design |
| inv-all-equipped | Inventory | Everything here is in use. | All pieces equipped (ITEM-003) | PROPOSAL from game-feel design |
| detail-sanctum | Inventory detail strip | Kept in the Sanctum. | Selected piece in the Sanctum | |
| detail-carried | Inventory detail strip | It may be lost on a path. | Selected carried piece | PROPOSAL from game-feel design |
| btn-let-go | Inventory, modal | Let it go | Discard button | PROPOSAL from both designs |
| btn-keep | Discard modal | Keep it | Safe button in modal | |
| modal-title | Discard modal | Let this go? | Modal title | |
| modal-risk-line | Discard modal | It cannot be brought back. | Modal body (sentence with title) | PROPOSAL from both designs, split in two |
| modal-risk-carried | Discard modal (carried piece) | It is carried. A path may take it. | Carried piece in modal | |
| reason-path-open | Inventory (blocked discard) | A path is still open. | `path_open` | Shown as text, not a grey button |
| chip-pack-neutral | Party prep (PackRow chip) | They may lose what they carry. | Chip, quiet, pack not low | PROPOSAL from game-feel design |
| chip-pack-warn | Party prep (chip, gold) | They have less room to carry this time. | Chip at `warn_pack_free_at` | PROPOSAL from game-feel design |
| pack-row-label | Party prep (PackRow) | Their packs | Pack row label | |
| pack-mark-risk | Party prep (held piece tooltip) | May be lost | "May be lost" mark | |
| leave-risk-line | Leave confirm (S5) | They may lose %d pieces. | Count of at-risk pieces | Adapted from game-feel proposal |
| leave-risk-carried | Leave confirm | %d was carried from before. | Shown only if a carried piece exists | Adapted from game-feel proposal |
| leave-early-rule | Leave confirm | Leaving early may lose some of what they carry. | Early-leave rule, in words | No odds |
| leave-stay | Leave confirm | Stay | Stay button | JEFF'S (exists in sheet) |
| leave-go | Leave confirm | To the Sanctum | Leave button | JEFF'S (exists in sheet) |
| group-kept | Leave result, stage clear | Kept in the Sanctum | Kept group heading, reason `ok` | |
| group-carried | Leave result, stage clear | Goes to the pack | Carried group heading, `to_pack` | |
| group-lost | Leave result, stage clear | Lost | Lost group heading | Word per ANSWERS #86 |
| result-kept | Leave result (tile tooltip) | It is safe in the Sanctum. | Kept, `ok` | |
| result-carried | Leave result (tile tooltip) | It stays in their packs. | Carried, `to_pack` | |
| result-lost-some | Leave result (tile tooltip) | Lost. They left too soon. | `leave_some` | PROPOSAL from design round 1 |
| result-lost-none | Leave result (tile tooltip) | Lost. They did not get it out. | `leave_none` | PROPOSAL from round 2 |
| result-overflow | Leave result, stage clear | Lost. There was no room. | `overflow` | PROPOSAL from all designs |
| result-stack-surplus | Leave result (stack tile) | The rest was lost. The limit is full. | `stack_limit` surplus | |
| result-settle-line | Leave result card line | Some of it got out | Existing settle line | JEFF'S (existing card line) |
| result-note | Leave result note line | What is in the Sanctum is safe. | Calming line | PROPOSAL from round 2 |
| defeat-line | Defeat (S7) | The party fell, and the packs were lost. | Defeat | JEFF'S (phase7 copy) |
| defeat-tile-tip | Defeat (lost tile tooltip) | Lost. The party fell. | Lost by defeat | PROPOSAL from design v2 |
| stageclear-preview | Stage clear (S8) | What they carry | Item preview heading | Same groups as above below it |
| nobody-no-room | Encounter, parked | Lost. There was no room. | Once-per-path no-room line (ITEM-002) | Parked; shown once per path |
| btn-continue | Result, defeat, stage clear | Continue | Continue button | JEFF'S (existing in `ui/`) |
| btn-cancel | Keeper swap strip | Cancel | Cancel button | JEFF'S (existing in `ui/`) |

## Table 2: item names (grey `name-bar` slots)

| Slot id | Placeholder |
|---|---|
| item-gear | Test piece A (gear) |
| item-charm | Test piece B (charm) |
| item-armor | Test piece C (armor) |
| item-relic | Test piece D (relic) |
| item-consumable | Test stack E (consumable) |
| item-material | Test stack F (material) |

## Table 3: prototype chrome (not game text)

| Slot | Text |
|---|---|
| scenario-roomy | Scenario 1: roomy pack |
| scenario-low | Scenario 2: pack nearly full |
| scenario-path-open | Scenario 3: discard blocked |
| scenario-leave-early | Scenario 4: leave early |
| scenario-clear | Scenario 5: path cleared |
| scenario-defeat | Scenario 6: party defeated |
| scenario-reset | Reset prototype |
| prototype-banner | Prototype. Not the game. |

Rule: every line here is AGENT-WRITTEN PLACEHOLDER; Jeff edits it after the play test.

## Table 4: singular and plural forms (added after the prototype build)

The prototype writes these forms in code. Use the singular form when the count is 1.

| Slot id | Singular (count 1) | Plural |
|---|---|---|
| inv-cap-gauge | Piece: 1 of %d | Pieces: %d of %d |
| leave-risk-line | They may lose 1 piece. | They may lose %d pieces. |
| leave-risk-carried | 1 was carried from before. | %d were carried from before. |

AGENT-WRITTEN PLACEHOLDER. Jeff edits it after the play test.
