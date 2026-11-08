# V2-ITEM-001 decisions (in force)

Written in STE. This is the short list of decisions that hold today. When two decisions conflicted, the later one won and the earlier one was removed. IDs in brackets point to the original entries, which are in git history at commit `11d566f` (`git show 11d566f:docs/stories/v2-item-001/decisions.md`). Project-wide answers: `ANSWERS.md` (#83, #86, #87, #88, #89).

## 1. Items, containers, numbers
- Gear and relics are unique pieces (own id, `held_by: ""` reserved). Consumables and materials are stacks (type id and quantity). (D-01, D-09)
- Every piece and every stack fills ONE slot and keeps a saved slot position. A new entry takes the first free slot. (D-33, D-37, D-40)
- Two containers: the Sanctum inventory (Storehouse) and the party pack (Travel pack). Shipping sizes: Sanctum 20 slots, pack 4 slots. Both are config values in `data.inventory`, provisional, may grow, tuned after play. The Sanctum never shrinks. (D-05, D-13, D-34, D-40)
- The stack limit is a config value (default 20). Cap warnings use config thresholds. (D-05, D-25)
- Materials are crafting inputs only: never a price, never sold, never shown as a balance. (D-06)
- Holding and moving are free. No selling. A recycle-yield key per grade is reserved and empty (Ekwan only). Recycling waits for ITEM-004. (D-02)
- No repairs or bridges for old saves until Jeff says a 1.0 version is live. (D-38, ANSWERS #88)

## 2. Moving and arranging
- Moves between containers and reorders: drag and drop, or select then a Move button. Allowed on the Sanctum and party-prep screens, also while a saved path is live. Refused on the path view. (D-33, D-40)
- Reorder only into an EMPTY slot. No swap onto an occupied slot. A stack dropped on a same-type stack merges, up to the limit. A moved stack moves whole. (D-34, D-40)
- Nothing moves between pack and Sanctum by itself: not at path end, not after a leave, not in intake. The player moves things. (D-42)
- Inventory is panels over the Sanctum, not screens. A Storehouse panel opens from a rail button. The pack opens from party details, to the right of it. Each panel opens alone. Open state is UI-local, with no flow state. (D-33, D-34, D-35)

## 3. Destroy (discard)
- In the Sanctum and party prep: unlimited, any entry in either container, a confirmation each time, a count picker for a stack. (D-33, D-34, D-40)
- On the path view: ONE per path, on a pack entry only. The used mark is saved and cleared at leave, defeat and path end. (D-33, D-34)
- Confirmation: `Keep` has focus. Esc, Back, B and an outside tap mean Keep. 0.25 s open window. 0.6 s lock after confirm. No hold, swipe or drag to confirm. (D-32)

## 4. Finds, leaves, defeat
- A find is an item row in the packs (`source: item`, zero currency). It owns one reserved pack slot. Open rows of other Realms count. (D-17, D-47)
- Early leave: nothing = items lost, everything = kept, some = one seeded draw per item AND per carried piece at the "some" share (50%). Every early leave draws again. New draw roots. The `stage.settle` stream is unchanged. A carried stack's draw key uses its type and its order among same-type stacks, not its slot. (D-03, D-19, D-22, D-43)
- Defeat: all finds and all carried pieces are lost. (D-20)
- A find that survives a path (clear or early leave) lands in the PACK and stays there. The Sanctum is never touched. A kept find is a carried piece, so carried means at risk. (D-49, D-53)
- A find is lost (`overflow`) only when no pack slot can hold it. A lost remainder always reports `overflow`. The pack never holds more entries than its size. A find bigger than one stack can lose units; accepted for now. (D-16, D-46, D-47, D-50)
- The debug producer `direct` mode places Sanctum first, then pack. The old `gathered` mode was deleted. (D-45, D-50)

## 5. What the player sees
- Result cards (leave, defeat, stage-clear) show ONE row of tiles: survivors in the kept state, lost pieces as ghosts. No place words, no lane titles, no preview mark. The stage-clear card shows the row before the payout from the same code on a copy of the save, and keeps it through a reload. The leave confirmation shows the at-risk tiles with the leaf mark. (D-23, D-30, D-42, D-51)
- First tap finishes the animation. Continue ignores taps for 0.25 s. Sequence cap 2.4 s. Reduced motion: 0.15 s fade. Loss tone: calm, a small lift, no red, no shake, no sound. (D-32)
- The pack panel shows no counts and no bead gauge. The count is on the party pack button only. Three panel tones (plain `#7A5B3E`, near full `#4F3B28`, full `#120E0C`), no decoration. (D-39, D-49, D-51)
- A full pack has NO mechanical penalty. The risk shows through the leaf mark, the departure line and the tone. (D-17, D-36)
- Tile rules: kind shapes, at most 3 marks, grade pips 1 to 3 with no rarity colour, six twin-notch shapes, two leaf glyphs, lost tile at 35% fill and 60% marks. (D-32)
- Item `name` comes from the item definition on inventory, at-risk and result rows. No definition means the kind word. (D-48)
- A refused move or destroy sets a one-shot `data.inventory.refused` in the next snapshot, never saved. A refused button shows only its refusal line. (D-48, D-51)
- Snapshot keys: party prep and the path view always carry `data.inventory`. Other item keys appear only when non-empty. (D-28, D-29, D-43)
- The approved UI contract is the interactive prototype `docs/visual-plans/inventory-ui-mockup-v2.html`. (D-44)

## 6. Text
- Jeff approves every player-facing line. Approved lines carry `# APPROVED (Jeff <date>)` in `ItemUiText.gd`, a fixture holds them and a test guards them. The source of the wording is `copy-approval-jeff.md`. (D-51, ANSWERS #89)

## 7. Technical rules
- The Sanctum fingerprint test erases `data.inventory` before it hashes. The recorded hash is unchanged. (D-27)
- Move and destroy rules read the saved path state, so they work after a quit and Continue. `stage.return_home` is refused unless the party is on a path. (D-28, D-29)
- The debug producer `inventory produce [direct|gather]` works in debug builds only. It reads `tests/fixtures/inventory_placeholders.json`. (D-27, D-28)
- `data.inventory.mark_count` (default 6) and `data.inventory.grades` (ordered, empty in shipping) are config keys. (D-26, D-28)

## 8. Not built in 001a (later work)
- **001b:** the Echoes choose what they take (`standing_v1`: Standing sets how well the party picks; Calling, vectors and emotion are reserved inputs), the left list, one keeper swap per path (take one left item, drop one taken), the pack view on the path. `stage.pick_stamps` belongs to 001b. It needs a Notion row with Jeff's yes. (D-12, D-14, D-15, D-18, D-26)
- **Pack shrink rule:** the pieces in closing slots move to the Sanctum. If the Sanctum is full, the surplus is lost and the player chooses at party prep. It needs a saved pending state and a party-prep step. Never on a live path. Built in the story that shrinks packs. (D-41)
- **Pack size** by Sanctum progression (note on V2-CONTINUITY-002) and per Echo (note on V2-ITEM-003). (D-34)
- **Finds** drawn in the pack while a path is live, and finds with no room (the encounter-card tile row and mini pack row, parked): the finds story (ITEM-002). (D-32, D-48)
- **Other stories:** real drops ITEM-002, equipping ITEM-003, recycling ITEM-004, crafting with materials (note on ECONOMY-003, D-07), the item catalogue (note on ITEM-002), ECONOMY-004 Part B (inputs in `handoff.md`).
- **UX redesign (Jeff):** panel placement and hierarchy, pack discoverability, text size, two refusal lines on a path, the weak full-tone edge on the dark path. (D-49, D-52)
- **Pack debuff:** closed. Revisit only if play shows nobody feels the pack. (D-36)

## 9. Removed because a later decision replaced them
| Removed | Replaced by |
|---|---|
| D-04 (cap full: item lost) | D-16, D-46, D-49 |
| D-08 (scope list), D-11 (one free-a-slot action), D-21 (discard rules) | D-33, D-34, D-40 (Destroy) |
| D-31 (inventory as a rail destination with its own flow state) | D-33, D-35 (panels) |
| D-24 (a survivor moves to the Sanctum when room exists), the move part of D-20 | D-42 |
| D-25 (provisional numbers 8 and 4) | D-34 (20 and 4) |
| D-36 strap line and consequence word, D-39 strap line | D-49, D-51 |
| D-34 and D-32 three result lanes and the preview mark | D-42, D-51 |
| D-40 and D-45 Sanctum-first intake for finds, D-45 `stack_limit` loss reason | D-49, D-46 |
| D-10 (research), D-44 (prototype approved), D-47 to D-53 findings lists | Done. Their results are in sections 1 to 8. |

## Open
- Which Notion rows are open for ITEM-005 (Order 249.2 and 259) and ECONOMY-002 (Order 242 and 360)? Not needed for this story.
