# V2-ITEM-001 decisions

Written in STE. Source for every line: Jeff's answers in the story chat (2026-10-27) and the live Notion rows.
Project-wide answers go to `ANSWERS.md` only when Jeff says so.

## D-01 — Mixed item model (Jeff, 2026-10-27)
Gear and relics: one record per piece, each with a unique id. Gear 1.1 differs from gear 1.2; one may be equipped and the other not.
Consumables and materials: stacks (item type id + quantity).

## D-02 — Free hold, free move, recycle hook only (Jeff, 2026-10-27)
No fee to hold or to move an item. No sell action. This story reserves a recycle-yield key per grade (Ekwan only). Values are left for ECONOMY-004 Part B.

## D-03 — Early-leave roll and items (Jeff, 2026-10-27)
Outcome "nothing": items are lost. Outcome "everything": items go to intake. Outcome "some": each item draws on its own at the "some" share (50%).
The draws use a new seed path. The existing currency roll stream does not change.

## D-04 — Cap full: the item is lost (Jeff, 2026-10-27)
When intake finds the cap full, the item is lost with the reason `overflow`. The player must see cap pressure before a path ends.
Consequence: the path view needs a cap warning (see D-08).

## D-05 — One total cap (Jeff, 2026-10-27)
One total count caps unique gear and relics together. Stacks have a per-stack limit in config. Numbers live in `data/balance.json` (ANSWERS #83). Jeff has not set the numbers.

## D-06 — Item kinds and materials (Jeff, 2026-10-27)
Intake accepts gear, relics, consumables and materials. Materials stack like consumables.
Guardrail: materials are crafting inputs only. They are never a price, never sold, never shown as a balance. Recycling returns Ekwan only.

## D-07 — Crafting follow-up story (Jeff, 2026-10-27)
A later ITEM-area story expands crafting from Ase + Ekwan + item to include materials. A Notion row for it needs Jeff's yes. Not written yet.

## D-08 — Scope (Jeff, 2026-10-27)
Build: intake, packs rules for item rows, a test-only producer, placeholder items to prove the chain, a Sanctum inventory view (read-only), and a packs view on the path.
Do not build work that belongs to other stories (real drops: ITEM-002; equipping: ITEM-003; recycling: ITEM-004).
Not selected: Resolve-card reason lines; inventory actions (recycle, drop).

## D-09 — held_by field (Jeff, 2026-10-27)
Each gear record carries `held_by: ""`. It is reserved and unused here. ITEM-003 and INFRA-005 use it.

## D-10 — Comparison research before the design round (Jeff, 2026-10-27)
Before the design round, research how Gears Tactics, XCOM, Tomodachi Life and similar games handle shared inventory, loot, loss and cap pressure. Output: `research-comparison.md`.

## D-11 — Cap relief: one "free a slot" action (Jeff, 2026-10-27)
Finding (design round 1): D-04 plus D-08 left the player no way to free a slot. Junk could fill the cap for good.
Jeff chose option D: one pre-departure action in the Sanctum inventory view that discards one unique piece.
This amends D-08: that one discard action is in scope. Equip, recycle and sell stay out of scope.
Consequences to design: the save write for the discard, the action path through the single choke point, a confirmation, and the exact rule (unique pieces only? stacks?). Round 2 and the build plan settle these.
Source: `design-round1-sr-game-designer.md` section 7 and the options table.

## OPEN
- No Notion row owns the item catalogue (names, categories, grades, art, descriptions). Proposal: a separate catalogue story before ITEM-002 builds real drops. Needs Jeff's decision.
- Notion duplicates: ITEM-005 (Order 249.2 and 259), ECONOMY-002 (Order 242 and 360). Which row is open?
- Notion has no row for ECONOMY-004 Part B.
