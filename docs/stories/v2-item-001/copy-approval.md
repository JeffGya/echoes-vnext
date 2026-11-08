# V2-ITEM-001a copy for approval (for Jeff)

Every player-facing line added in this story. Source: `ui/components/ItemUiText.gd`. All lines are PLACEHOLDER until you approve them. The suggestions are proposals. You write the final text. Word rules (ANSWERS #86): never "home", never "stage" (say "path"), an unclaimed reward is "lost".

New words in the suggestions that you must approve as game vocabulary: **Storehouse** (the Sanctum's storage), **Travel pack**, **Release / let go**, **Sort**, **Amount**, **Supply**, **bundle** (a stack).

Not in this list: the F1 debug console lines (dev only), the symbols `×` `−` `+` `<` `>` and `x1`, and the test item names (`Placeholder weapon A`). They never reach a player.


## Rail and panel titles

| Approve | Id | Where it shows | Current (placeholder) | Suggestion |
|---|---|---|---|---|
| [ ] | `RAIL_LABEL` | New rail button | Stores | Storehouse |
| [ ] | `SANCT_TITLE` | Title of the Sanctum panel | Sanctum storage | The Storehouse |
| [ ] | `SANCT_SUB` | Line under the Sanctum title | House storage. Always safe. | What the Sanctum keeps. |
| [ ] | `PACK_TITLE` | Title of the pack panel | Party pack | The Travel Pack |
| [ ] | `PACK_SUB` | Line under the pack title | Goes with the party. | Carried out with the party. |
| [ ] | `SHOW_PACK` | Button in the Sanctum panel | Show pack | Open the pack |
| [ ] | `HIDE_PACK` | Same button, pack open | Hide pack | Put the pack away |
| [ ] | `CLOSE_SANCT` | Spoken label of the Sanctum close button | Close Sanctum storage | Close the Storehouse |
| [ ] | `CLOSE_PACK` | Spoken label of the pack close button | Close party pack | Close the pack |
| [ ] | `PARTY_PACK_BUTTON` | Button in party details and on the path HUD | Party pack | Travel pack |
| [ ] | `FULL_WORD` | Word for a full container | Full | Full |

## Pack risk words

| Approve | Id | Where it shows | Current (placeholder) | Suggestion |
|---|---|---|---|---|
| [ ] | `PACK_NEAR` | Pack panel, one slot free | Nearly full. | Almost full. |
| [ ] | `PACK_HEAVY` | Pack panel, full, in party details | Heavy. They may lose what they carry. | Heavy with all they carry. Some of it may not come back. |
| [ ] | `PACK_FULL_PATH` | Pack panel, full, on a path | Full. Nothing more fits. | Nothing more will fit. |
| [ ] | `DEPART_LINE` | Above the pack button when the pack holds something | Carried pieces can be lost on a defeat or an early leave. | What the party carries can be lost if it falls or turns back. |
| [ ] | `AT_STAKE` | Detail line of a carried piece | At stake: it can be lost. | It may be lost on the road. |
| [ ] | `AT_STAKE_LABEL` | Spoken label of the leaf mark | At stake | At risk |

## Details area

| Approve | Id | Where it shows | Current (placeholder) | Suggestion |
|---|---|---|---|---|
| [ ] | `DETAILS_TITLE` | Title of the details area | Details | This piece |
| [ ] | `DETAILS_EMPTY` | Details area, nothing selected | Select a piece to see its details. | Choose a piece to learn more. |
| [ ] | `DETAILS_HINT` | Details area, nothing selected | Drag a piece to the other panel, or select it and press a Move button. | Drag it across, or choose it and use a button below. |
| [ ] | `WHERE_SANCT` | Where a selected piece is | In the Sanctum | Rests in the Storehouse |
| [ ] | `WHERE_PACK` | Where a selected piece is | In the pack | Travels with the party |
| [ ] | `KIND_LABEL` | Label before the kind | Kind | Sort |
| [ ] | `GRADE_LABEL` | Label before the grade | Grade | Grade |
| [ ] | `COUNT_LABEL` | Label before the amount | Count | Amount |
| [ ] | `ONE_PIECE` | Amount of a single piece | 1 piece | One |
| [ ] | `AT_LIMIT` | A stack at its limit | At the limit | As full as it gets |
| [ ] | `BTN_MOVE_PACK` | Button | Move to pack | Put in the pack |
| [ ] | `BTN_MOVE_SANCT` | Button | Move to Sanctum | Send to the Storehouse |
| [ ] | `BTN_LET_GO` | Button (also the first word of its reason line) | Let it go | Release it |
| [ ] | `BTN_KEEP` | Button in the confirmation | Keep it | Hold on to it |

## Path view

| Approve | Id | Where it shows | Current (placeholder) | Suggestion |
|---|---|---|---|---|
| [ ] | `PATH_READONLY` | Lock line in the pack on a path | On a path: read-only | On the path, the pack stays as it is. |
| [ ] | `PATH_LEFT` | Token on a path, one release left | Let it go: 1 left this path | One release left on this path. |
| [ ] | `PATH_USED` | Token on a path, release used | Let it go: used | No release left on this path. |
| [ ] | `PATH_HINT` | Empty details area on a path | On a path, pieces cannot be moved. | On the path, nothing is moved. |
| [ ] | `PATH_RULE` | Rule line on a path | Only one piece may be let go on a path. | Only one piece may be released on a path. |
| [ ] | `PATH_PREVIEW` | Mark on the path-clear card | Preview. Read-only. | A glimpse of what the path would give. |
| [ ] | `CARD_PREVIEW` | Same mark, second constant | Preview. Read-only. | A glimpse of what the path would give. |

## Kind names

| Approve | Id | Where it shows | Current (placeholder) | Suggestion |
|---|---|---|---|---|
| [ ] | `KIND gear` | Tile and details | Gear | Gear |
| [ ] | `KIND relic` | Tile and details | Relic | Relic |
| [ ] | `KIND consumable` | Tile and details | Consumable | Supply |
| [ ] | `KIND material` | Tile and details | Material | Material |

## Refusal lines

| Approve | Id | Where it shows | Current (placeholder) | Suggestion |
|---|---|---|---|---|
| [ ] | `R_PATH` | A move refused on a path | Moves are closed on a path. | On the path, nothing can be moved. |
| [ ] | `R_PACK_FULL` | A move to a full pack | The pack is full. Free a socket first. | The pack is full. Make room first. |
| [ ] | `R_SANCT_FULL` | A move to a full Sanctum | The Sanctum is full. Free a slot first. | The Storehouse is full. Make room first. |
| [ ] | `R_DISCARD_USED` | Second release on a path | The one discard of this path is used. | You have already let one go on this path. |
| [ ] | `R_NOT_IN_PACK` | Release of a Sanctum piece on a path | On a path only a piece in the pack can be let go. | On the path, only what the party carries can be let go. |
| [ ] | `R_OCCUPIED` | Drop on a taken slot | That slot is taken. Drop on an empty slot. | Something rests there. Choose an empty place. |
| [ ] | `R_TYPE` | Merge of two different kinds | Only the same kind of stack can merge. | Only the same kind can be joined. |
| [ ] | `R_STACK_LIMIT` | Merge into a full stack | That stack is at its limit. | That bundle is as full as it gets. |
| [ ] | `R_EQUIPPED` | Piece in use (future equipping) | It is in use. | Someone is using it. |
| [ ] | `R_SANCTUM_ONLY` | Action outside the Sanctum | This can only be done in the Sanctum. | This can only be done in the Sanctum. |
| [ ] | `R_NO_CHANGE` | A move that changes nothing | Nothing changed. | Nothing changed. |
| [ ] | `R_GONE` | Piece no longer there | That piece is not there any more. | It is no longer there. |
| [ ] | `R_BAD_SLOT` | Slot that does not exist | That slot is not available. | There is no place there. |
| [ ] | `R_COUNT` | Bad count in the release | That count is not possible. | That amount is not possible. |
| [ ] | `R_UNKNOWN` | Any other refusal | That did not work. Nothing changed. | That did not work. Nothing was changed. |

## Drop hints

| Approve | Id | Where it shows | Current (placeholder) | Suggestion |
|---|---|---|---|---|
| [ ] | `DROP_REORDER` | While dragging over an empty slot | Drop to place it in this slot | Set it down here |
| [ ] | `DROP_MERGE` | While dragging over a same-kind stack | Drop to merge the stacks | Join the bundles |
| [ ] | `DROP_PACK` | While dragging over the pack | Drop to put it in the pack | Put it in the pack |
| [ ] | `DROP_SANCT` | While dragging over the Sanctum | Drop to put it in the Sanctum | Send it to the Storehouse |

## Discard confirmation

| Approve | Id | Where it shows | Current (placeholder) | Suggestion |
|---|---|---|---|---|
| [ ] | `MODAL_TITLE` | Title | Let this go? | Let this go? |
| [ ] | `MODAL_LINE` | Line | It cannot be brought back. | It will not come back. |
| [ ] | `MODAL_PATH_LINE` | Line on a path | This is the one discard of this path. | This is the one release of this path. |
| [ ] | `MODAL_PACK_LINE` | Line for a pack piece | It is in the pack. | It travels with the party. |
| [ ] | `MODAL_SANCT_LINE` | Line for a Sanctum piece | It is in the Sanctum. | It rests in the Storehouse. |
| [ ] | `MODAL_COUNT_LABEL` | Label of the count picker | How many? | How many? |
| [ ] | `COUNT_FEWER` | Spoken label of the minus button | Fewer | One less |
| [ ] | `COUNT_MORE` | Spoken label of the plus button | More | One more |

## Leave and result cards

| Approve | Id | Where it shows | Current (placeholder) | Suggestion |
|---|---|---|---|---|
| [ ] | `LEAVE_RISK_LABEL` | Spoken label of the at-risk row | At stake | At risk |
| [ ] | `CARD_SURVIVED` | Tile line on a result card | Survived | Made it through |
| [ ] | `CARD_LOST` | Tile line on a result card | Lost | Lost |
| [ ] | `ITEMS_GROUP_LABEL` | Spoken label of the tile row | Pieces | What was carried |

## Lines built from numbers

| Approve | Id | Where it shows | Current (placeholder) | Suggestion |
|---|---|---|---|---|
| [ ] | `slots_word` | Sanctum gauge (used, total) | 3 / 20 slots | 3 of 20 places filled |
| [ ] | `sockets_word` | Pack button (used, total) | 2 / 4 sockets | 2 of 4 carried |
| [ ] | `pack_button` | Spoken label of the pack button | Party pack 2/4 | Travel pack 2/4 |
| [ ] | `stack_count` | Count of a stack in the details | x3 of 20 | x3 of 20 |
| [ ] | `leave_risk (many)` | Leave confirmation | They may lose 3 pieces. | 3 may be lost. |
| [ ] | `leave_risk (one)` | Leave confirmation | They may lose 1 piece. | One may be lost. |
| [ ] | `moved_toast (pack)` | Spoken line after a move | It is now in the pack. | Put in the pack. |
| [ ] | `moved_toast (Sanctum)` | Spoken line after a move | It is now in the Sanctum. | Sent to the Storehouse. |
| [ ] | `Detail line patterns` | Details area | Kind: Gear / Grade: 3 / Count: 1 piece | Sort: Gear / Grade: 3 / Amount: One |
| [ ] | `Refusal line pattern` | A refused button | Move to pack: The pack is full. Free a socket first. | Put in the pack: The pack is full. Make room first. |

Total: 83 lines.
