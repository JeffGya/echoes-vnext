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

## D-12 — Echoes choose what to take at pickup (Jeff, 2026-10-27) — DESIGN DIRECTION, details open
After each encounter, the Echoes decide which finds go into the packs and which stay on the path. A higher Standing or a "smarter" Calling chooses better. Jeff also sees a link to Storyweight, Standing, vectors and emotion.
The keeper's one intervention is the swap (see D-11; the exact form is still being clarified).
This design round 1 and round 2 were written BEFORE D-12. Both need a pass 3 that adds the Echo choice. D-03 (per-item draw on an early leave) and D-04 stay until Jeff says otherwise.
Scope risk: an Echo decision model touches Echo behavior, vectors and Calling data. One story, one subject: Jeff decides whether the full model is this story or a follow-up. This story would build the selection seam.

## D-13 — The packs have their own small capacity (Jeff, 2026-10-27)
The party carries a limited number of item slots on the path (a config number, not set yet). Echoes choose which finds fill them. The Sanctum cap (D-05) still applies when items arrive.

## D-14 — Choice moment and the keeper's swap (Jeff, 2026-10-27)
The Echoes choose at pickup, after each encounter (D-12).
The keeper has one swap per path: take one item the Echoes left, and drop one they took. The Sanctum discard (D-11) stays as the way to free house room.
ASSUMED (not yet confirmed): the packs still go through the early-leave roll (D-03) and the path-end bank, as ANSWERS #87 says. The Echo choice happens before the roll.

## D-15 — Scope of the Echo choice (Jeff, 2026-10-27)
This story builds: the packs capacity (D-13), the pickup decision point (a selection seam), the one keeper swap, and a simple seeded rule in which Standing sets how well the party picks.
Calling, vectors and emotion are reserved inputs. They are not used yet.
A follow-up story builds the full Echo decision model. It needs a new Notion row (Jeff's yes first).

## D-16 — The party pack is separate from the Sanctum inventory (Jeff, 2026-10-27)
The party pack and the Sanctum inventory are two containers. The pack can be filled while the party is in the Sanctum. It works as overflow: when the Sanctum inventory is full, an arriving item stays in the pack and is not lost.
A filled pack goes on the next path. The party starts with less free pack room. This is a deliberate disadvantage.
If the Sanctum inventory AND the pack are both full, the next arriving item is lost (reason `overflow`). D-04 survives for this one case.
This amends D-04, D-13 and the packs rules. Open for the design rounds: how the pack empties (keeper action? automatically when room appears?), how the pack interacts with the early-leave roll (D-03) when it already holds old items, whether items in the pack from an earlier path are rolled again on a new early leave, and where the player sees the carried-over load.

## D-17 — The pack makes loss at a full cap rare (Jeff, 2026-10-27)
Confirmed: through the Echo choice, nothing is lost to a full cap, because every gathered item already owns a pack slot. The "Sanctum and pack both full, item lost" rule (D-16) stays as a safety net for arrivals that skip the Echo choice.
The real pressure is lost room: a full pack limits the Echoes' choices on the next path.
Jeff: a full pack should also be detrimental to the Echoes' state and cause debuffs. That is for ANOTHER story. This story builds no debuff. It must leave the hook visible (the carried load is readable data), so the later story can read it.
Source: `design-sr-game-designer-v2.md` section 2 and A1.

## D-18 — Story split into V2-ITEM-001a and V2-ITEM-001b (Jeff, 2026-10-28)
001a: containers (Sanctum inventory and party pack), intake, item rows in the packs, per-item early-leave draws, the Sanctum discard, and the Sanctum inventory view. In 001a the pack fills in find order through a default seam function.
001b: the Echo choice (`standing_v1`), the left list, the keeper swap, and the packs view on the path.
001a is played and verified before 001b starts. A Notion row for 001b needs Jeff's yes.
Source: `design-sr-game-designer-v2.md` section 10.

## D-19 — Held pieces are rolled again on an early leave (Jeff, 2026-10-28)
Held pieces are items carried in the pack from an earlier path because the Sanctum was full. Jeff chose: they ARE rolled again on an early leave (each draws alone, as D-03).
This reverses the designer's recommendation (A2: held pieces safe). A full pack now risks lost pieces, not only lost room.
Open: defeat and path end for held pieces; the designer's invariant and the feel design (lit "safe" tiles, no lift on carried pieces) must be redone.

## D-20 — Defeat takes held pieces too (Jeff, 2026-10-28)
Follows D-19. A defeat empties the pack: gathered items and held pieces are both lost (reason `defeat`). Finishing a path moves held pieces into the Sanctum when room exists.

## D-21 — Discard rules (Jeff, 2026-10-28)
- In the Sanctum: the player may discard as many times as wanted, with a confirmation each time. It works on Sanctum pieces and on carried (pack) pieces. Only while in the Sanctum.
- On the path: one discard per path. It is the keeper swap's drop (D-14). There is no separate path discard.
- Recycling: not built in 001a. D-02 stands (recycle hook only). Jeff's wish "discard or recycle as many times as wanted in the Sanctum" is built when ITEM-004 lands.
- Unique pieces only (the designer's rule, unchanged). Stacks are not discarded.

## D-22 — Held pieces are drawn at every early leave (Jeff, 2026-10-28)
A9 answered: every early leave draws the held pieces again, including repeat leaves on the same path. No exemption for a survivor. Rule: carried means at risk.

## D-23 — A tile row shows what is at risk (Jeff, 2026-10-28)
A8 / C-9 answered: the leave confirmation and the leave and defeat result screens get a small row of item tiles (at risk before, kept or lost after). It is not a count line only. 001b's path view can reuse the row.

## D-24 — A survivor with a full Sanctum stays held (Jeff, 2026-10-28)
A10 answered: a held piece that survives an early-leave draw while the Sanctum is full stays in the pack as a held piece. It can be drawn again (D-22) and lost on defeat (D-20).

## D-25 — Provisional starting numbers (Jeff, 2026-10-28)
Jeff chose provisional small values to tune after his play test. They are marked PROVISIONAL in `data/balance.json`: `unique_cap` 8, `pack_capacity` 4, `stack_limit_default` 20, `warn_room_at` 2, `warn_pack_free_at` 1. Tests use their own test config and never depend on these values.

## OPEN
- No Notion row owns the item catalogue (names, categories, grades, art, descriptions). Proposal: a separate catalogue story before ITEM-002 builds real drops. Needs Jeff's decision.
- Notion duplicates: ITEM-005 (Order 249.2 and 259), ECONOMY-002 (Order 242 and 360). Which row is open?
- Notion has no row for ECONOMY-004 Part B.
