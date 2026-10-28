# V2-ITEM-001a consolidated design (sr-game-designer, v2, corrected for D-17 to D-21)

Written in STE. Design only. D-01 to D-21 bind this design. Every player line is a PROPOSAL; Jeff owns copy. Word rules of ANSWERS #86 hold: Sanctum, path, lost.
**[CORRECTED D-18]** This file scopes V2-ITEM-001a: containers, intake, item rows, per-item leave draws, Sanctum discard, Sanctum inventory view, pack row before departure. The Echo choice, left list, keeper swap and path packs view sit in section 11 (001b, parked).

## 0. Reuse and checked facts

| Fact (checked in code, not comments) | Source |
|---|---|
| `add_row` rejects a row with no Ase and no Ekwan. An item-only row cannot be written. | `EarningsService.gd:49` |
| `items: []` is reserved on every row. | `EarningsService.gd:23` |
| `nothing_new` looks at Ase and Ekwan only. An item-only pack draws no leave roll. | `StageSettlementService.gd:295`, `:344` |
| The outcome roll is one draw on `stage.settle.<stage_id>.<run_count>.<settle_count>`. `settle_count` is read before it increments. | `StageSettlementService.gd:361-364`, `:384` |
| `mark_settled` gives every listed row the same share (0, 50 or 100). Item rows need their own mark. | `EarningsService.gd:111-117` |
| Defeat: `mark_lost` marks losable rows. `packs_lost` carries only Ase and Ekwan. A pack in the `inventory` block is not touched. | `ActiveStageService.gd:469-487` |
| "Some" share is `data.rewards.carry_shares.some` = 0.5. The Scout `retention_mul` changes the outcome weights, not the share. | `data/balance.json:1605-1609`, `StageSettlementService.gd:303-324` |

## 1. The item journey [CORRECTED D-19 D-20]

Two locations exist. **Gathered** items sit in item rows of `stage.earnings` (ANSWERS #87). **Held** pieces sit in `inventory.pack`. A held piece is a piece carried from an earlier path because the Sanctum was full.

| Step | Who decides | What can be lost | Reason key | Saved |
|---|---|---|---|---|
| Found (won encounter) | The producer (test) now; ITEM-002 later | Nothing yet | none | `inventory.next_seq` (id per unique find) |
| Fill the pack (section 3) | `take_in_order` | A find beyond free room is not gathered. It is not saved. | `no_room` (returned, not saved) | One item row per taken find; pick stamp |
| Gathered, held | Nobody | Early leave, defeat | see below | Item rows; `inventory.pack` |
| Early leave | The outcome draw, then one draw per piece (gathered AND held) | "Nothing": all. "Some": each piece at 50%. "Everything": none. | `leave_none`, `leave_some` | Row `settled` plus entry `fate`; `stage.held_fates` |
| Defeat | The code | All gathered items AND all held pieces | `defeat` | Rows `lost`; `stage.held_fates`; pack emptied |
| Path end (cleared) | The code, no draw | Nothing | none | Row `settled`; entry `fate` |
| Sanctum intake | The code, by order | Stack surplus; a direct arrival with no room | `stack_limit`, `overflow` | `inventory.items`, `inventory.stacks` |
| Stay in the pack | The code, when the Sanctum unique cap is full | Nothing | `to_pack` (a result, not a loss) | `inventory.pack` |

**Bug check, confirmed.** Fix: `add_row` accepts a row whose `items` array is not empty. `nothing_new` also requires "no unsettled item row and no held piece". Item-free packs with an empty pack behave as before; a characterization test proves it first.
**New effect of D-19.** A held piece is at stake on a leave. So a leave with held pieces and no new gathered item still draws the outcome roll. The roll moves `settle_count` only for packs that hold items.

## 2. The two containers [CORRECTED D-19 D-20]

**Intake order.** One function, one pass. At a path end or after a leave, the order is: (1) held pieces, oldest first, then (2) gathered item rows, in row order. For each piece:
1. A stack goes to its Sanctum stack. Surplus above `stack_limit` is lost (`stack_limit`). Stacks never enter the pack and have no total cap (D-05).
2. A unique piece goes to the Sanctum if `items.size() < unique_cap`.
3. Else it stays in, or moves to, `inventory.pack` (result `packed`, key `to_pack`). It already owns a pack slot, so this always fits.
4. Else it is lost (`overflow`). Only a piece that never owned a pack slot reaches this step (section 2, "When overflow occurs").

**Where the pack lives.** Root save block `inventory.pack` (array of unique records). It survives reload and path change. Additive only.
**Free pack room** = `pack_capacity` minus `inventory.pack.size()` minus the unsettled, unlost item rows of the live stage.

**How the pack empties: automatic.** A function moves held pieces into the Sanctum, oldest first, while room exists. It runs at four points: path end, leave survivors (intake), after a Sanctum intake, and after a Sanctum-piece discard. No keeper button exists. Defeat empties the pack by loss (D-20).
**Invariant.** After every mutation, `inventory.pack` is non-empty only while the Sanctum unique count equals `unique_cap`. The Sanctum gains no piece during a path, so the invariant also holds on a path. A test asserts it after every mutation.

**Early leave and held pieces (D-19).** Each held piece draws alone, as each gathered piece does (section 4). A piece that survives goes to intake. A piece that cannot fit stays in the pack and is held again.
**New path with items in the pack.** The pack goes with the party. Held pieces fill slots, so free room is smaller. This stays the disadvantage of D-16.

**When `overflow` loss can occur in 001a [CORRECTED D-17].** Overflow needs a piece that arrives with no pack slot: a "direct arrival". In 001a that arrival is only the `direct` mode of the intake API, used by tests and the debug producer. The gathered route cannot overflow: `take_in_order` takes a find only if a slot is free, and the piece keeps that slot until it reaches the Sanctum. So the D-17 statement holds in 001a: through the pack route, a full cap loses nothing. Other cap-related loss in 001a: stack surplus (`stack_limit`) only. Finds beyond free room are not lost by a cap. They stay on the path and vanish when the path ends (no left list until 001b).

**Exploit re-check [CORRECTED D-19].**
- Parking pieces in the pack dodges no roll. A held piece draws on every early leave and is lost on defeat. Only the Sanctum is safe.
- A gathered piece becomes held without risk only at a cleared path end, where no piece draws. Banking works the same today.
- One leave cannot be drawn twice (section 4). Burning `settle_count` to move the outcome roll is possible today with a small currency row. No new class of exploit.
- Filling the Sanctum with junk gives no benefit.

## 3. Pack filling in 001a: `take_in_order` [CORRECTED D-18]

**Call site.** After a won fight, beside `record_fight_earnings` (`FlowEncounterState.gd:222`). A defeat gathers nothing.
**One pure function, replaceable by 001b. No RNG. No save call.**

| Part | Content |
|---|---|
| Input `finds` | `[{ find_id, type_id, kind, grade, quantity }]` in find order. The caller assigns `find_id`. |
| Input `free_slots` | int, 0 or more |
| Input `chooser` | `{ echo_id, name, standing }` or `{}`. Not used in 001a. |
| Input `party` | ordered ids. Not used in 001a. |
| Input `rng_path`, `config` | String and Dictionary. Not used in 001a. |
| Output | `{ model: "find_order", chooser_id: "", taken: [find_id], left: [find_id], draws: 0 }` |

**Rule.** `taken` = the first `free_slots` finds. `left` = the rest, in order. `draws` = 0.
**The writer** applies the output: one item row per taken find (id `item:<situation_id>:<n>`, exactly-once stamp as the fight row) and one pick stamp `{ situation_id, model, chooser_id }` in `stage.pick_stamps`. 001a does not save `left`.
**Why 001b needs no change to a saved field.** 001b replaces the function with `standing_v1`. It writes the same output and the same stamp. 001b adds two stage fields with safe defaults, `left_items` and `swap_used`. No 001a field changes shape.

## 4. Leave and defeat draws for items [CORRECTED D-19 D-20]

**When.** After the outcome roll, only when the outcome is "some". Outcome "nothing" loses every piece with no draw. Outcome "everything" keeps every piece with no draw.
**One draw per piece.** `rng.randi_range(0, 99) < roundi(share * 100)`, where `share` is the `picked["share"]` of the outcome (equals `carry_shares.some`). A stack draws once as a whole (A5).
**Seed path and index.** New root:
`inventory.leave.<stage_id>.<run_count>.<settle_count>.<kind>.<id>`

| Part | Value |
|---|---|
| `settle_count` | The value read before the increment, same as the outcome roll |
| `kind` | `row` (gathered; `id` = item row id) or `held` (`id` = piece id `it.<seq>`) |
| Index | The `id`, never a list position. The draw is the first and only draw of the path. |

The `id` is stable under reload, discard, pack reorder and a move to the Sanctum. The path is not `stage.settle`. The outcome stream and the EchoFactory draw order do not change. A test proves item-free packs draw the same values as before. Mechanics-developer confirms that `CampaignSeed.get_rng_from` accepts a row id with colons.

**Where the fate is saved, so reload and retry never redraw.**
- **Gathered row:** `settled` and `settled_share` (100 kept, 0 lost, written by the item path, not by the shared `mark_settled`), plus entry `fate` and `reason_key`.
- **Held piece:** one record in `stage.held_fates`: `{ id, type_id, kind, grade, token, fate, reason_key }`. `token` = `<run_count>.<settle_count>`. A lost piece leaves `inventory.pack` in the same mutation. A kept piece goes to intake. The draw skips a piece that has a record with the same token.
- **One mutation, one save request.** The caller requests the save after the escape succeeds (existing rule, `StageSettlementService.gd:332-334`). A crash before the save repeats the same pure draws and gives the same result.
- **Defeat** (`lose_unsettled_packs`, `ActiveStageService.gd:469`): item rows go `lost` through `mark_lost` (item rows carry `keep_on_defeat: false`). The same call empties `inventory.pack` through the inventory service and writes `held_fates` with `defeat`. The defeat report adds item counts beside `packs_lost`. A repeat finds nothing to lose.

## 5. The Sanctum discard (D-11, D-21) [CORRECTED D-21]

- Only in the Sanctum, before departure. A request on a live path is refused (`not_in_sanctum`).
- Targets: unique pieces in `inventory.items` AND carried pieces in `inventory.pack`. Stacks are refused (`not_unique`). A piece with a non-empty `held_by` is refused (`equipped`; unreachable until ITEM-003).
- Many uses, one piece per use. A `ModalHost` confirmation each time says the piece cannot be brought back.
- No recycle in 001a (D-02); ITEM-004 adds it. No path discard: the path discard is the 001b swap drop (D-21).

**Write.** Action `inventory.discard.apply`, payload `{ item_id }`, through `FlowRuntime.dispatch` and a controller. One mutation: remove the piece, run the auto-move, request one save.
**Effect.** A discarded Sanctum piece frees Sanctum room, so one held piece moves in and one pack slot frees. A discarded carried piece frees one pack slot and no Sanctum room. The player chooses by value and risk.
**Nothing to discard.** Cap 0, or every piece equipped (flag to ITEM-003). The button does not show.

## 6. Record shapes

**Unique piece** (`inventory.items[]`, `inventory.pack[]`): `id` (`it.<seq>` from `inventory.next_seq`, no RNG), `type_id`, `kind` (`gear`|`relic`), `grade`, `held_by: ""` (D-09).
**Stack** (`inventory.stacks[]`): `type_id`, `kind` (`consumable`|`material`), `quantity`. No id, no grade.
**Item row** (`stage.earnings`, source `item`): `ase: 0`, `ekwan: 0`, `scaled: false`, `keep_on_defeat: false`, `id: "item:<situation_id>:<n>"`, `items: [entry]`. One entry per row. The entry adds `fate` (`gathered`, `carried`, `lost`) and `reason_key`.
**Intake result:** `{ result, reason_key, item_id, quantity }` plus `lost_quantity`. `result`: `stored`, `packed`, `partial`, `lost`, `rejected`.
**Reason keys:** `ok`, `to_pack`, `overflow`, `stack_limit`, `unknown_kind`, `unknown_type`, `kind_disabled`, `duplicate`, `no_room`, `leave_none`, `leave_some`, `defeat`, `not_in_sanctum`, `not_unique`, `not_found`, `equipped`.

**Cost shape** `cost: { ekwan, ase }` lives only in config definitions. No value is set here (ECONOMY-004 Part B). Not saved.
**Saved:** the `inventory` block, item rows, `stage.pick_stamps`, `stage.held_fates`. **From config definitions:** display name, `cost`, stack limit overrides, recycle-yield key.
**Block** `data.inventory`, numbers unset: `unique_cap`, `pack_capacity`, `stack_limit_default`, `kinds_enabled`, `recycle_yield_ekwan` (keys per grade, empty), `warn_room_at`, `warn_pack_free_at`, `definitions` (empty in shipping). The leave share is read from `data.rewards.carry_shares.some`. A static getter `ConfigService.get_inventory_cfg` reads the block. Save name: `inventory.items`, never `relics`.

## 7. Placeholder set and the catalogue

Set: `ph_weapon_a`, `ph_charm_a`, `ph_relic_a`, `ph_consumable_a`, `ph_material_a`, `ph_armor_a`. No real weapon names (bible 3.6, 4.1). Fixture and producer sit under `tests/`, because everything under `res://` ships. Jeff's play test uses `debug.inventory.produce` (DebugController, layer 128), with a `direct` mode. Guard tests: no `ph_` id in `data/balance.json` or a new save; no non-debug code calls the producer.
**Catalogue owner.** No Notion row owns names, categories, grades, art or descriptions. FLAG: Jeff decides on a catalogue story before ITEM-002.

## 8. View requirements [CORRECTED D-18 D-19 D-21]

- **Sanctum inventory:** count against `unique_cap` and a full state; pieces by kind, icon, grade mark; stacks as tiles with a quantity badge and an at-limit mark; a separate "carried" row; the discard button on a selected Sanctum or carried piece. Keep out: Ase and Ekwan balances, ids, `held_by`, cost, yield, recycle, equip, sell.
- **Pack before departure:** pack sockets, filled by held pieces or free; a "may be lost" mark on held pieces; the departure chip, quiet by default and gold at `warn_pack_free_at`. Keep out: a material as a number, odds.
- **Leave confirmation (existing panel):** one added count line of gathered and held pieces that may be lost (A8). Tiles and per-item marks are 001b.

Items use tiles in their own region. The line `In their packs: <Ase> Ase and <Ekwan> Ekwan.` stays a number line.
PROPOSAL lines: `The Sanctum is full. These stay in their packs.` / `They have less room to carry this time.` / `They may lose what they carry.` / `Lost. There was no room.` / `Lost. The party fell.` / `Let this go? It cannot be brought back.`

## 9. The pressure of a full pack [CORRECTED D-19 D-20]

**Fair?** Yes, with a warning. The cost is now room AND risk.
**Spiral?** No lock, but a trap of zero gain. Trace: the Sanctum is full, path ends fill the pack, free room is 0, the party gathers nothing, and held pieces can only be lost. The trap shrinks by itself: a lost held piece frees a slot. Three exits exist: a Sanctum discard (always available, many-use), clearing the path (no piece draws), and the loss itself.
**Leave loop.** Each early leave draws the held pieces again. A player who leaves and returns repeatedly wears them down. See A9.

**Guard rails still needed:**
1. Discard works on carried pieces, many-use (D-21). It is the main exit. Without it the trap is a lock.
2. Auto-move of held pieces into the Sanctum when room exists.
3. Only unique pieces overflow. Stack surplus is lost, not parked.
4. Carried load visible at party prep, with a "may be lost" mark; chip gold at `warn_pack_free_at`.
5. A count line on the leave confirmation (D-04).

**Removed:** "held pieces safe" (D-19). **Not needed:** the floor `pack_min_free`. It loses a piece the player cannot avoid, and the discard already gives an exit. It is parked in section 11.

## 10. Scope and risks [CORRECTED D-18]

**In 001a:** the containers, auto-move, the discard action, the item rows and per-item draws, `take_in_order`, the Sanctum view, the pack row. **Not in 001a:** section 11, real drops (ITEM-002), equip (ITEM-003), recycle (ITEM-004), the grade ladder (ITEM-005), crafting with materials (D-07), pack debuffs (another story). The carried load stays readable data for that story (D-17).

**Risks:**
- Dead end: Sanctum full plus an all-equipped Sanctum (ITEM-003). Flag to ITEM-003: equipped pieces must not block relief.
- Harsh loss (D-19, D-20): mitigated by the chip, the count line and the discard. Jeff plays and judges.
- Exploits: section 2. Replay farming of items is ITEM-002's rule to own.
- Determinism, save: new root `inventory.leave.*`; the outcome draw is unchanged for packs with no items; item-bearing packs now draw it even with no new Ase (section 1); ids from a counter; additive `inventory` block with a repair pass. Opus reviews the save change and the draw order.
- Defeat report: `packs_lost` carries no items. Add item counts, or the player sees no loss.
- Name clash: `economy.relics` (number), Resolve `relics` (array) and relic items stay apart.
- GDD (list only): 19.3 slot 4 shares "relic or consumable", while D-05 caps relics only. 19.10 and 21.1 list the cap structure as open; D-05, D-13, D-16 now set it.

## 11. 001b (parked, kept for later) [CORRECTED D-18]

001b needs a Notion row with Jeff's yes. 001a is played first. Changes needed before 001b builds: D-19 puts held pieces in the roll, so the path view must mark them at risk.

**Echo choice `standing_v1`.** The chooser is the party member with the highest Standing among members not knocked out at the fight end; ties go to party order (A3). Roster field: `standing`, fallback `rank`. The rule uses the same seam as section 3.
- `worth = grade_index * 100 + kind_weight`; ties go to find order.
- Per free slot, two draws: `a = randi_range(0,99)`, `b = randi()`. If `a < wise_pct` (from Standing), take the highest `worth`; else take the find at index `b mod remaining`.
- Seed: `inventory.pick.<stage_id>.<run_count>.<situation_id>`, never `stage.settle`. The pick stamp makes it exactly-once.
- Output: the section 3 shape with `model: "standing_v1"`. Free slots already exclude held pieces. Reserved chooser inputs: `calling`, `vector_scores`, `dominant_vector`, `morale`, `fear`, `fear_base`.

**Left list and keeper swap (D-14).** `stage.left_items` holds finds the Echoes left; `stage.swap_used` is the one-per-path flag. Action `inventory.swap.apply`, payload `{ take_id, drop_row_id }`; one mutation, one save request. After a leave draw the rows are settled, so a swap fails (`not_gathered`). The swap drop is the only path discard (D-21). Refusal keys: `swap_used`, `not_left`, `not_gathered`, `path_not_live`. A7: held pieces cannot be dropped. D-19 puts them at risk, so Jeff may reconsider.

**Packs view on the path.** Gathered tiles with the chooser portrait, free-room count, left row, swap action, leave confirmation with per-item marks, and path-end marks.
**Parked questions.** `manner` as a core output; the floor `pack_min_free`; an optional defeat line; discard of left items; fixture grades `ph_g1` to `ph_g3`; config `pick.*`, `grades`, `pick_kind_weight`.

## OPEN — questions and assumptions

- ASSUMED: A1 [CORRECTED D-17]. In 001a, `overflow` occurs only for a direct arrival (no pack slot). The find-order route cannot overflow. Finds beyond free room are not gathered and are not lost by a cap. Jeff confirms that is intended.
- ASSUMED: A2 REVERSED by D-19. Held pieces are rolled again on an early leave and lost on defeat (D-20). They are safe only in the Sanctum.
- ASSUMED: A3. (001b) "Not knocked out" is readable at the fight end.
- A4: closed by D-21. The discard has no count limit in the Sanctum.
- ASSUMED: A5. One item row holds one entry. A stack draws once as a whole.
- ASSUMED: A6. Stack surplus above the limit is lost and never enters the pack.
- ASSUMED: A7. (001b) The keeper swap drops only gathered pieces, not held ones.
- ASSUMED: A8. The existing leave panel gets one count line in 001a. Without it the player cannot see the new risk. Tiles on the path are 001b.
- ASSUMED: A9. Every early leave draws held pieces again, including a repeat leave on the same stage. The alternative is that a piece that survived one draw is exempt for the rest of that stage. Jeff decides.
- ASSUMED: A10. A held piece that survives a leave and finds the Sanctum full stays in the pack (held again).
- BLOCKED: Numbers for `unique_cap`, `pack_capacity`, `stack_limit_default`, `warn_room_at`, `warn_pack_free_at` (Jeff, D-05, D-13). The 001b numbers `pick.*` wait for 001b.
- BLOCKED: Is the Notion row for 001b, and for the full Echo model, approved? Jeff's yes is needed.
- BLOCKED: Which story owns the item catalogue? No Notion row exists.
- BLOCKED: Notion duplicates (ITEM-005, ECONOMY-002) and the missing ECONOMY-004 Part B row (`decisions.md` OPEN).
