# V2-ITEM-001: basis for 001b and for later work

One file that keeps the design and research material still useful after V2-ITEM-001a. It was ten files. Each section below is one of them, unchanged except for the heading level and a STATUS line that says what later decisions override. The decisions in `decisions.md` always win over this file.

Removed files and where to read them: see section 6 of `handoff.md` (git history).

## Contents

1. Game designer design, round 2 (the 001b basis) (was `design-sr-game-designer-v2.md`)
2. Game feel design, round 2 (the 001b basis) (was `design-feel-game-feel-developer-v2.md`)
3. Research: how comparable games handle carry limits and inventory (was `research-comparison.md`)
4. Research: UI best practices for inventory, loss and confirmation (was `research-ui-best-practices.md`)
5. Pack shrink options, designer view (was `pack-shrink-options-designer.md`)
6. Pack shrink options, game feel view (was `pack-shrink-options-feel.md`)
7. Pack debuff options, designer view (was `pack-debuff-options-designer.md`)
8. Pack debuff options, game feel view (was `pack-debuff-options-feel.md`)
9. Artist proposal: tile marks, colour rules and measured contrast (was `mockup-proposal-2-artist.md`)
10. Merged mockup proposal and the decisions it asked for (was `mockup-proposal-merged.md`)


---

## 1. Game designer design, round 2 (the 001b basis)

Source file: `design-sr-game-designer-v2.md` (removed in the cleanup of this folder).

**STATUS: the 001a parts were overridden by D-19 to D-21 and then by D-33 to D-53 (see `decisions.md`). The 001b parts are still the basis for 001b and are NOT built: the Echo choice `standing_v1`, the left list, the keeper swap and the pack view on the path (D-12 to D-15, D-18).**

### V2-ITEM-001a consolidated design (sr-game-designer, v2, corrected for D-17 to D-21)

Written in STE. Design only. D-01 to D-21 bind this design. Every player line is a PROPOSAL; Jeff owns copy. Word rules of ANSWERS #86 hold: Sanctum, path, lost.
**[CORRECTED D-18]** This file scopes V2-ITEM-001a: containers, intake, item rows, per-item leave draws, Sanctum discard, Sanctum inventory view, pack row before departure. The Echo choice, left list, keeper swap and path packs view sit in section 11 (001b, parked).

#### 0. Reuse and checked facts

| Fact (checked in code, not comments) | Source |
|---|---|
| Before step 4, `add_row` rejected a row with no Ase and no Ekwan. Step 4 fixed it: `add_row` accepts a row with a non-empty `items` array. | `EarningsService.gd` (`add_row`) |
| `items: []` is reserved on every row. | `EarningsService.gd:23` |
| Before step 4, `nothing_new` looked at Ase and Ekwan only. Step 4 fixed it: `nothing_new` is false when an open item row or a held piece exists, so such a pack draws the leave roll. | `StageSettlementService.gd` (`settle_plan`) |
| The outcome roll is one draw on `stage.settle.<stage_id>.<run_count>.<settle_count>`. `settle_count` is read before it increments. | `StageSettlementService.gd:361-364`, `:384` |
| `mark_settled` gives every listed row the same share (0, 50 or 100). Item rows need their own mark. | `EarningsService.gd:111-117` |
| Defeat: `mark_lost` marks losable rows. `packs_lost` carries only Ase and Ekwan. A pack in the `inventory` block is not touched. | `ActiveStageService.gd:551-600` (`lose_unsettled_packs`) |
| "Some" share is `data.rewards.carry_shares.some` = 0.5. The Scout `retention_mul` changes the outcome weights, not the share. | `data/balance.json:1605-1609`, `StageSettlementService.gd:303-324` |

#### 1. The item journey [CORRECTED D-19 D-20]

Two locations exist. **Gathered** items sit in item rows of `stage.earnings` (ANSWERS #87). **Held** pieces sit in `inventory.pack`. A held piece is a piece carried from an earlier path because the Sanctum was full.

| Step | Who decides | What can be lost | Reason key | Saved |
|---|---|---|---|---|
| Found (won encounter) | The producer (test) now; ITEM-002 later | Nothing yet | none | Nothing. A gathered piece has no instance id yet. `intake` mints the id (`inventory.next_seq`). |
| Fill the pack (section 3) | `take_in_order` | A find beyond free room is not gathered. It is not saved. | No reason key: `left` is returned, not saved | One item row per taken find; pick stamp |
| Gathered, held | Nobody | Early leave, defeat | see below | Item rows; `inventory.pack` |
| Early leave | The outcome draw, then one draw per piece (gathered AND held) | "Nothing": all. "Some": each piece at 50%. "Everything": none. | `leave_none`, `leave_some` | Row `settled` plus entry `fate`; `stage.held_fates` |
| Defeat | The code | All gathered items AND all held pieces | `defeat` | Rows `lost`; `stage.held_fates`; pack emptied |
| Path end (cleared) | The code, no draw | Nothing | none | Row `settled`; entry `fate` |
| Sanctum intake | The code, by order | Stack surplus; a direct arrival with no room | `stack_limit`, `overflow` | `inventory.items`, `inventory.stacks` |
| Stay in the pack | The code, when the Sanctum unique cap is full | Nothing | `to_pack` (a result, not a loss) | `inventory.pack` |

**Bug check, confirmed.** Fix: `add_row` accepts a row whose `items` array is not empty. `nothing_new` also requires "no unsettled item row and no held piece". Item-free packs with an empty pack behave as before; a characterization test proves it first.
**New effect of D-19.** A held piece is at stake on a leave. So a leave with held pieces and no new gathered item still draws the outcome roll. The roll moves `settle_count` only for packs that hold items.

#### 2. The two containers [CORRECTED D-19 D-20]

**Ids.** `intake` mints the piece id `it.<n>` from `inventory.next_seq`. A caller may pass a `piece_id`. A gathered piece has no id before intake.

**Intake order.** One function, one pass. At a path end or after a leave, the order is: (1) held pieces, oldest first, then (2) gathered item rows, in row order. For each piece:
1. A stack goes to its Sanctum stack. Surplus above `stack_limit` is lost (`stack_limit`). Stacks never enter the pack and have no total cap (D-05).
2. A unique piece goes to the Sanctum if `items.size() < unique_cap`.
3. Else it stays in, or moves to, `inventory.pack` (result `packed`, key `to_pack`). It already owns a pack slot, so this always fits.
4. Else it is lost (`overflow`). Only a piece that never owned a pack slot reaches this step (section 2, "When overflow occurs").

**Where the pack lives.** Root save block `inventory.pack` (array of unique records). It survives reload and path change. Additive only.
**Free pack room** = `pack_capacity` minus `inventory.pack.size()` minus the unsettled, unlost item rows of the live stage.

**How the pack empties: automatic.** A function moves held pieces into the Sanctum, oldest first, while room exists. It runs at four points: path end, leave survivors (intake), after a Sanctum intake, and after a Sanctum-piece discard. No keeper button exists. Defeat empties the pack by loss (D-20).
**Invariant.** `intake` never puts a piece in `inventory.items` above `unique_cap`, and never puts a piece in `inventory.pack` while the Sanctum has room. `intake` of a unique piece, `discard` and the move function first move held pieces into the Sanctum. After them, `inventory.pack` is empty or the Sanctum has no room. A raised cap can leave a held piece with room until the next of these calls. A lowered cap can leave more pieces than the cap; no call drops a piece. A `gathered` piece can take the pack above `pack_capacity`; `validate` reports it. A test asserts these after every mutation.

**Early leave and held pieces (D-19).** Each held piece draws alone, as each gathered piece does (section 4). A piece that survives goes to intake. A piece that cannot fit stays in the pack and is held again.
**New path with items in the pack.** The pack goes with the party. Held pieces fill slots, so free room is smaller. This stays the disadvantage of D-16.

**When `overflow` loss can occur in 001a [CORRECTED D-17].** Overflow needs a piece that arrives with no pack slot: a "direct arrival". In 001a that arrival is only the `direct` mode of the intake API, used by tests and the debug producer. The gathered route cannot overflow: `take_in_order` takes a find only if a slot is free, and the piece keeps that slot until it reaches the Sanctum. So the D-17 statement holds in 001a: through the pack route, a full cap loses nothing. Other cap-related loss in 001a: stack surplus (`stack_limit`) only. Finds beyond free room are not lost by a cap. They stay on the path and vanish when the path ends (no left list until 001b).

**Exploit re-check [CORRECTED D-19].**
- Parking pieces in the pack dodges no roll. A held piece draws on every early leave and is lost on defeat. Only the Sanctum is safe.
- A gathered piece becomes held without risk only at a cleared path end, where no piece draws. Banking works the same today.
- One leave cannot be drawn twice (section 4). Burning `settle_count` to move the outcome roll is possible today with a small currency row. No new class of exploit.
- Filling the Sanctum with junk gives no benefit.

#### 3. Pack filling in 001a: `take_in_order` [CORRECTED D-18]

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
**The writer** applies the output: one item row per taken find (id `item:<situation_id>:<find_id>`, exactly-once stamp as the fight row). 001a does not save `left` or a pick stamp (D-26: `stage.pick_stamps` belongs to 001b).
**Why 001b needs no change to a saved field.** 001b replaces the function with `standing_v1`. It writes the same output and adds its own pick stamp (001b field). 001b adds two stage fields with safe defaults, `left_items` and `swap_used`. No 001a field changes shape.

#### 4. Leave and defeat draws for items [CORRECTED D-19 D-20]

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
- **Defeat** (`lose_unsettled_packs`, `ActiveStageService.gd:551`): item rows go `lost` through `mark_lost` (item rows carry `keep_on_defeat: false`). The same call empties `inventory.pack` through the inventory service and writes `held_fates` with `defeat`. The defeat card data is `packs_lost.items`: one report row for each lost item row and held piece (no id; item rows first, then held pieces). The log `economy.earnings.lost` carries the item counts. A repeat finds nothing to lose.

#### 5. The Sanctum discard (D-11, D-21) [CORRECTED D-21]

- Only in the Sanctum, before departure. A request on a live path is refused (`not_in_sanctum`).
- Targets: unique pieces in `inventory.items` AND carried pieces in `inventory.pack`. Stacks are refused (`not_unique`). A piece with a non-empty `held_by` is refused (`equipped`; unreachable until ITEM-003).
- Many uses, one piece per use. A `ModalHost` confirmation each time says the piece cannot be brought back.
- No recycle in 001a (D-02); ITEM-004 adds it. No path discard: the path discard is the 001b swap drop (D-21).

**Write.** Action `inventory.discard.apply`, payload `{ item_id }`, through `FlowRuntime.dispatch` and a controller. One mutation: remove the piece, run the auto-move, request one save.
**Effect.** A discarded Sanctum piece frees Sanctum room, so one held piece moves in and one pack slot frees. A discarded carried piece frees one pack slot and no Sanctum room. The player chooses by value and risk.
**Nothing to discard.** Cap 0, or every piece equipped (flag to ITEM-003). The button does not show.

#### 6. Record shapes

**Unique piece** (`inventory.items[]`, `inventory.pack[]`): `id` (`it.<seq>` from `inventory.next_seq`, no RNG), `type_id`, `kind` (`gear`|`relic`), `grade`, `held_by: ""` (D-09).
**Stack** (`inventory.stacks[]`): `type_id`, `kind` (`consumable`|`material`), `quantity`. No id, no grade.
**Item row** (`stage.earnings`, source `item`): `ase: 0`, `ekwan: 0`, `scaled: false`, `keep_on_defeat: false`, `id: "item:<situation_id>:<find_id>"`, `items: [entry]`. One entry per row. The entry adds `fate` (`gathered`, `carried`, `lost`) and `reason_key`.
**Intake result:** `{ result, reason_key, item_id, quantity }` plus `lost_quantity`. `result`: `stored`, `packed`, `partial`, `lost`, `rejected`.
**Reason keys:** `ok`, `to_pack`, `overflow`, `stack_limit`, `unknown_kind`, `unknown_type`, `kind_disabled`, `duplicate`, `duplicate_find`, `bad_entry`, `leave_none`, `leave_some`, `defeat`, `not_in_sanctum`, `not_unique`, `not_found`, `equipped`.

**Cost shape** `cost: { ekwan, ase }` lives only in config definitions. No value is set here (ECONOMY-004 Part B). Not saved.
**Saved:** the `inventory` block, item rows, `stage.held_fates`. **From config definitions:** display name, `cost`, stack limit overrides, recycle-yield key.
**Block** `data.inventory`, numbers unset: `unique_cap`, `pack_capacity`, `stack_limit_default`, `kinds_enabled`, `recycle_yield_ekwan` (keys per grade, empty), `warn_room_at`, `warn_pack_free_at`, `definitions` (empty in shipping). The leave share is read from `data.rewards.carry_shares.some`. A static getter `ConfigService.get_inventory_cfg` reads the block. Save name: `inventory.items`, never `relics`.

#### 7. Placeholder set and the catalogue

Set: `ph_weapon_a`, `ph_charm_a`, `ph_relic_a`, `ph_consumable_a`, `ph_material_a`, `ph_armor_a`. No real weapon names (bible 3.6, 4.1). Fixture and producer sit under `tests/`, because everything under `res://` ships. Jeff's play test uses `debug.inventory.produce` (DebugController, layer 128), with a `direct` mode. Guard tests: no `ph_` id in `data/balance.json` or a new save; no non-debug code calls the producer.
**Catalogue owner.** No Notion row owns names, categories, grades, art or descriptions. FLAG: Jeff decides on a catalogue story before ITEM-002.

#### 8. View requirements [CORRECTED D-18 D-19 D-21]

- **Sanctum inventory:** count against `unique_cap` and a full state; pieces by kind, icon, grade mark; stacks as tiles with a quantity badge and an at-limit mark; a separate "carried" row; the discard button on a selected Sanctum or carried piece. Keep out: Ase and Ekwan balances, ids, `held_by`, cost, yield, recycle, equip, sell.
- **Pack before departure:** pack sockets, filled by held pieces or free; a "may be lost" mark on held pieces; the departure chip, quiet by default and gold at `warn_pack_free_at`. Keep out: a material as a number, odds.
- **Leave confirmation (existing panel):** one added count line of gathered and held pieces that may be lost (A8). The item tile row (at risk before, kept or lost after) is built in 001a (D-23); 001b's path view reuses it.

Items use tiles in their own region. The line `In their packs: <Ase> Ase and <Ekwan> Ekwan.` stays a number line.
PROPOSAL lines: `The Sanctum is full. These stay in their packs.` / `They have less room to carry this time.` / `They may lose what they carry.` / `Lost. There was no room.` / `Lost. The party fell.` / `Let this go? It cannot be brought back.`

#### 9. The pressure of a full pack [CORRECTED D-19 D-20]

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

#### 10. Scope and risks [CORRECTED D-18]

**In 001a:** the containers, auto-move, the discard action, the item rows and per-item draws, `take_in_order`, the Sanctum view, the pack row. **Not in 001a:** section 11, real drops (ITEM-002), equip (ITEM-003), recycle (ITEM-004), the grade ladder (ITEM-005), crafting with materials (D-07), pack debuffs (another story). The carried load stays readable data for that story (D-17).

**Risks:**
- Dead end: Sanctum full plus an all-equipped Sanctum (ITEM-003). Flag to ITEM-003: equipped pieces must not block relief.
- Harsh loss (D-19, D-20): mitigated by the chip, the count line and the discard. Jeff plays and judges.
- Exploits: section 2. Replay farming of items is ITEM-002's rule to own.
- Determinism, save: new root `inventory.leave.*`; the outcome draw is unchanged for packs with no items; item-bearing packs now draw it even with no new Ase (section 1); ids from a counter; additive `inventory` block with a repair pass. Opus reviews the save change and the draw order.
- Defeat report: `packs_lost` carries no items. Add item counts, or the player sees no loss.
- Name clash: `economy.relics` (number), Resolve `relics` (array) and relic items stay apart.
- GDD (list only): 19.3 slot 4 shares "relic or consumable", while D-05 caps relics only. 19.10 and 21.1 list the cap structure as open; D-05, D-13, D-16 now set it.

#### 11. 001b (parked, kept for later) [CORRECTED D-18]

001b needs a Notion row with Jeff's yes. 001a is played first. Changes needed before 001b builds: D-19 puts held pieces in the roll, so the path view must mark them at risk.

**Echo choice `standing_v1`.** The chooser is the party member with the highest Standing among members not knocked out at the fight end; ties go to party order (A3). Roster field: `standing`, fallback `rank`. The rule uses the same seam as section 3.
- `worth = grade_index * 100 + kind_weight`; ties go to find order.
- Per free slot, two draws: `a = randi_range(0,99)`, `b = randi()`. If `a < wise_pct` (from Standing), take the highest `worth`; else take the find at index `b mod remaining`.
- Seed: `inventory.pick.<stage_id>.<run_count>.<situation_id>`, never `stage.settle`. The pick stamp makes it exactly-once.
- Output: the section 3 shape with `model: "standing_v1"`. Free slots already exclude held pieces. Reserved chooser inputs: `calling`, `vector_scores`, `dominant_vector`, `morale`, `fear`, `fear_base`.

**Left list and keeper swap (D-14).** `stage.left_items` holds finds the Echoes left; `stage.swap_used` is the one-per-path flag. Action `inventory.swap.apply`, payload `{ take_id, drop_row_id }`; one mutation, one save request. After a leave draw the rows are settled, so a swap fails (`not_gathered`). The swap drop is the only path discard (D-21). Refusal keys: `swap_used`, `not_left`, `not_gathered`, `path_not_live`. A7: held pieces cannot be dropped. D-19 puts them at risk, so Jeff may reconsider.

**Packs view on the path.** Gathered tiles with the chooser portrait, free-room count, left row, swap action, the leave confirmation and result tile rows are built in 001a (D-23) and reused here.
**Parked questions.** `manner` as a core output; the floor `pack_min_free`; an optional defeat line; discard of left items; fixture grades `ph_g1` to `ph_g3`; config `pick.*`, `grades`, `pick_kind_weight`.

#### OPEN — questions and assumptions

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


---

## 2. Game feel design, round 2 (the 001b basis)

Source file: `design-feel-game-feel-developer-v2.md` (removed in the cleanup of this folder).

**STATUS: the 001a feel parts were overridden by D-19, D-20, D-33 to D-53. The 001b feel parts (the left list, the swap beat, the path pack view) are NOT built and remain the basis for 001b. The loss tone still holds: a leaf let go, fade to 0.35, lift 8 units, 0.5 s, no red, no shake, no sound on defeat.**

### V2-ITEM-001a feel design (game-feel-developer, v2, corrected for D-17 to D-21)

Written in STE. Design only. I ran no code and no Godot. D-01 to D-21 bind this design.
Tags: READ = from a file I opened. ASSUMED = not verified. Research is hypothesis only (`research-comparison.md`, evidence LOW).
All player text is PROPOSAL. Jeff owns copy. Word rules (ANSWERS #86): say Sanctum, path, lost. No "banked", "settled" or "roll" in text.
**[CORRECTED D-18]** Sections 1 to 8 scope 001a. Section 9 holds the 001b parts (parked, ideas unchanged).

#### 0. Findings first

1. READ: a reduced-motion switch exists (`ui/components/StopMarkMotion.gd:24`). Every motion needs a 0.15 s fade path.
2. READ: no audio player exists in `ui/` or `core/`. Sound items are hints only.
3. READ: `docs/Living_Grove_Design_System.md:35-52`. Info blue `#7AB5C8` is also the Fearful colour. Marks use shape and neutral ink. Gold means actionable or full.
4. **[CORRECTED D-19 D-20]** Carried pieces are at risk. A carried tile is never "safe" or "lit". The lock glyph and the "carried tiles stay lit" idea are removed. Only the Sanctum is safe.
5. **[CORRECTED D-18]** 001a has no path packs view. The leave and defeat beats need one surface. I propose a result row on the existing outcome screen (section 3.1). Question for Jeff.


#### 1. Plain find-order arrival (001a) [CORRECTED D-18]

The pack fills in find order (`take_in_order`). No Echo chooses. No portrait walks. No manner, ground line or left list.
The beat plays on the encounter result card (ASSUMED; `ui-ux-designer` confirms).

| Case | What the player sees | Time |
|---|---|---|
| No finds | Nothing | 0 |
| Finds fit | Tiles appear and drop together into free sockets, left to right. | 0.5 s |
| Finds exceed free room | Tiles appear in a row (0.2 s). The first tiles drop into the free sockets (0.3 s). The other tiles fade to 35 percent and leave the row (0.5 s, `EASE_OUT`, no lift). | 0.8 s |
| Free room 0 | Tiles appear (0.2 s) and fade out (0.5 s). No drop. | 0.7 s |

A tap finishes the beat. The result is already saved.

**How the extra finds read.** A tile appears and fades where no socket waits. This is the "lost" gesture without the lift. The lift means "it was in the pack". An extra find never was, so it only fades. The filled sockets show the cause.
PROPOSAL line, once per path, at the first find with no room: `Lost. There was no room.` After that, only the fade plays. This avoids a repeated alarm.
An extra find is not saved and cannot return. Risk: a first-time player may think it waits. Mitigation: the fade and the once-only line.

#### 2. The carried pack before departure (D-16, D-17, D-19)

##### 2.1 Sockets

At party prep a socket row shows the pack. Carried pieces fill from the left. A carried socket looks heavy: darker bed, 2 units lower. **[CORRECTED D-19]** Each carried tile has a small "loose leaf" glyph (a leaf with a gap) in its top-left corner. It means "may be lost". It uses shape only. It disappears when the piece enters the Sanctum (section 5.2). Free sockets look light.

##### 2.2 The departure chip [CORRECTED D-19]

The chip once warned about lost room. Now it must also warn about lost pieces.

| Condition | Chip |
|---|---|
| No carried piece | Hidden. |
| One or more carried pieces | Shown in neutral ink: the carried count and the loose-leaf glyph. |
| Free room at or below `warn_pack_free_at` | Thin gold outline added, no fill. Depart keeps the only gold fill. |

A tap opens the Sanctum inventory view, where the discard is (section 5). The chip leads to the cure.
PROPOSAL tooltip: `They may lose what they carry.` Second line when room is low: `They have less room to carry this time.`
No modal at departure. Sockets and chip share the screen with Depart.

##### 2.3 Leave-panel count line [CORRECTED D-19]

The existing leave confirmation gets one line. It counts gathered pieces plus carried pieces that may be lost. A stack counts as one piece.
PROPOSAL: `They may lose 3 pieces. 1 was carried from before.` The second sentence shows only when a carried piece exists. The line hides at 0.
It is a number line, with no tiles and no odds. Tiles with per-item marks on the path are 001b.

#### 3. Loss beats (001a) [CORRECTED D-19 D-20]

##### 3.1 One shared motion and the surface

Lost means: fade to 35 percent over 0.5 s, `EASE_OUT`. One parameter: lift 8 units if the tile was in the pack. Gathered and carried pieces were both in the pack, so both use the lift. No red, shake or strike-through. Tone: a leaf let go.
**Surface (question for Jeff).** The beats need tiles. 001a has no path packs view. I propose a result row on the existing leave and defeat outcome screens. It shows only pieces at stake, carried first, then gathered. It is a result, not a path view. Fallback if Jeff refuses: the outcome line plus a count (`Lost 2 of 3 pieces.`), and the Sanctum view shows what survived.

##### 3.2 The beats

| Beat | Motion | Time | Sound hint | PROPOSAL line |
|---|---|---|---|---|
| Early leave, some | The existing outcome line first. Tiles resolve in pack order. Each holds 0.3 s, then slides toward the Sanctum glyph (kept) or uses the lost motion with lift. Stagger 0.25 s. | Cap 1.8 s; over seven tiles, stagger 0.1 s | One soft falling tone per lost tile, at most three | `Lost. They did not get it out.` |
| Early leave, nothing | All tiles, carried and gathered, use the lost motion with lift together. | 0.6 s | One tone | Outcome line only |
| Early leave, everything | All tiles slide to the Sanctum glyph together, then intake. | 0.5 s | One soft rising tone | Outcome line only |
| Survivor, Sanctum full | A kept carried tile does not slide. It settles in its socket and keeps its loose-leaf glyph. | 0.2 s | None | `The Sanctum is full. This stays in their packs.` |
| Defeat | All pack tiles, gathered and carried, use the lost motion with lift together. | 0.8 s | None. Never a sting. | Existing `The party fell, and the packs were lost.` |
| Stack surplus | The badge ticks to the limit and becomes the at-limit capsule. A ghost chip of the surplus lifts off and fades. The tile stays. | 0.6 s | One small tone | `Lost. The stack was full.` |

A slide toward the Sanctum glyph promises safety, so the survivor settles in place.
Order at a path end: outcome line, leave beats, intake (kept tiles settle 0.25 s each), surplus ghosts. Cap 3.0 s. A tap finishes all motion.

##### 3.3 Repeat-leave wear-down (A9) — question for Jeff

Each early leave draws every carried piece again. In the "some" outcome a piece survives n leaves with chance 0.5 to the power n. After two leaves, 75 percent are lost on average.

| Test | Result |
|---|---|
| Readable | Yes. Each tile shows its fate each time. The glyph stays until the piece reaches the Sanctum. |
| Fair | Mostly. The player can discard, or finish a path (no draw). The risk is a choice. |
| Warm | Weak point. A survivor feels earned, and a second draw can feel like a trick. |

Recommendation: keep A9. One rule, "carried means at risk", is easier to read than a hidden exemption. Warmth comes from the survivor beat, which promises no safety, and from the persistent glyph.
Alternative: a survivor is exempt for the rest of that stage. It is kinder, but it needs a visible mark and an exploit check. Not recommended. Jeff decides. Checklist 7 tests it.

##### 3.4 Spiral risk [CORRECTED D-17 D-19]

Trace: Sanctum full, pack fills, free room 0, nothing gathered, carried pieces can only be lost. Nothing locks: a lost carried piece frees a slot. Mitigations, all visual: sockets and chip at party prep; the quiet room-0 beat; one discard visibly frees one pack socket (5.2); the chip tap leads to the Sanctum view.

##### 3.5 Hook for the later debuff story [CORRECTED D-17]

D-17 puts debuffs in another story. 001a designs no debuff, no Echo state change and no rule that reads the load. These are data and visual hooks only.

| Hook | Content |
|---|---|
| Snapshot `pack_load` | `{ carried, capacity, free, level }`. `carried` counts held pieces. `level` 0 to 3 (none, light, heavy, full). Thresholds: `warn_pack_free_at` plus one config key. Core derives it each snapshot. |
| Visual slot `LoadMark` | A satchel glyph at the head of the socket row, four states. Static in 001a. |
| Socket posture | Carried sockets are lower and darker. A higher `level` adds one tone step. |

Only `LoadMark` and the socket tone read `level` in 001a. Numbers are unset (Jeff).

#### 4. Reading at a glance

| View | A glance must answer | Elements in rank order |
|---|---|---|
| Sanctum inventory | Full? What is carried? Anything at limit? | Cap gauge `n / cap`, shape change at full. Carried row under it, with glyphs. Tile grid by kind. Stack badges. |
| Pack before departure | How heavy? What may be lost? | Socket row with `LoadMark`. The chip. |
| Leave panel | How many pieces are at stake? | The count line. |

Tiles: 72 units at 1920x1080, 64 at 1280x720; gap 8 or more; targets 48 or more. Ase and Ekwan stay a plain text line. Stack badge `x7` bottom right; at the limit a solid capsule with an underline. Material quantity is a tile badge only (D-06). Twins: a corner notch from `mark_index`, kept across pack and Sanctum.

#### 5. The Sanctum discard (D-11, D-21) [CORRECTED D-21]

##### 5.1 Picking a piece and the confirmation

The discard works only in the Sanctum, on Sanctum pieces and carried pieces. It has many uses. Each use needs a confirmation.
1. The player taps a unique tile in the grid or in the carried row. A selection outline shows. Both use the same outline.
2. A detail strip shows name, grade pips and `Let it go` (quiet, thin border, 48 or more, never gold fill; thin gold outline at full cap). For a carried piece it adds PROPOSAL `It may be lost on a path.`
3. The button shows even with room left, so the rule is visible. Stacks show no button.
4. `Let it go` opens ModalHost (layer 40), which restores focus.

| Part | Spec |
|---|---|
| Content | Tile at large size (with the glyph if carried), name, grade pips |
| PROPOSAL line | `Let this go? It cannot be brought back.` |
| Buttons | `Keep it` (primary look, 56, default focus). `Let it go` (secondary, 48). 24 units apart or more. |
| After confirm | The button ignores input for 0.6 s. |

**Guards.** No swipe, long press, drag or button on the tile. No hold-to-confirm. Default focus is `Keep it`.
**[CORRECTED D-21]** New guard: after a discard the selection clears and the strip hides. The discard is many-use and tiles shift. A double tap must not reach a new `Let it go`.

##### 5.2 What the tiles do

| Discarded piece | Motion |
|---|---|
| Carried | The modal closes (0.15 s). The tile uses the lost motion with lift. The socket closes and neighbours shift (0.25 s). The gauge does not change. |
| Sanctum | The modal closes (0.15 s). The tile uses the lost motion with lift. If the pack holds a piece, the oldest carried piece glides from its socket into the freed grid place (0.4 s). Its glyph fades on landing (0.2 s). The gauge eases (0.3 s). |

The glide shows one discard free one pack socket. Without it the socket would vanish with no cause. The glyph fade is the only "safe" signal, and it sits in the Sanctum.
No coin sound, no yield text (D-02). No recycle in 001a.

##### 5.3 Nothing to discard

Empty: PROPOSAL `Nothing is stored yet.` and no button. Only stacks: no button, never a grey disabled one. All equipped (ITEM-003): PROPOSAL `Everything here is in use.`

#### 6. Placeholder look

Hatched grey-cream tiles, dashed outline, one plain shape per kind, no gold or Adinkra (READ: `docs/art-direction.md`). Twin notch, pips and glyph show real data.

#### 7. Play test checklist for Jeff (001a)

1. Finds fit: does the 0.5 s drop feel like nothing?
2. Finds exceed room: do fading tiles read as "no room"? Does a tile look like it will return?
3. Free room 0: is the quiet fade enough?
4. Party prep with carried pieces: do you see weight and risk before Depart? Does the chip help?
5. A path with a full pack: stall, punishment or reminder?
6. Leave early with five pieces, some carried: is each tile its own chance? Is "lost" warm?
7. Leave early twice with the same carried piece: fair, warm, readable? (A9)
8. A survivor with a full Sanctum: does the settle read as "kept, still carried"?
9. Lose a fight with carried pieces: do all tiles read as lost with no extra line?
10. Overflow a stack: does the ghost chip read as "the stack was full"?
11. Discard a Sanctum piece with a full pack: do you see the carried piece glide in?
12. Discard a carried piece: is the difference clear?
13. Tap `Let it go` twice fast: does anything discard by accident?
14. Is the leave-panel count line enough?
15. At 1280x720: tell twins apart.

#### 8. Conflicts and dependencies

| # | Designer v2 | My position | Status |
|---|---|---|---|
| C-1 | No pack discard | Allow discard on a carried piece | **ACCEPTED by Jeff, D-21.** Closed. |
| C-6 | Chip gold at `warn_pack_free_at` | Thin gold outline, not fill | Open for the designer |
| C-7 | Material number out of the path view | Tile badge everywhere; never a header | Designer confirms (D-06) |
| C-8 | Auto-move of held pieces | Make the move a visible glide | Still applies |
| C-9 (new) | Leave panel: one count line (A8) | Add a result row of tiles on leave and defeat screens | Question for Jeff (3.1) |
| C-10 (new) | Chip gold at low room only | Chip also shows whenever a carried piece exists | Risk exists at any room level |

Dropped (need an Echo choice, now in section 9): C-2 left tiles, C-3 portrait, C-4 `manner`, C-5 full stack rank.

Dependencies: (1) per find: `taken` or `no_room`, kind, pips, `mark_index`; (2) per piece at a leave or defeat: `fate`, `reason_key`, `carried`, `stack_at_limit`; (3) `pack_load` and the at-risk count each snapshot; (4) `can_discard` per tile, covering carried pieces and ITEM-003 `held_by`; (5) party prep state survives a trip to the inventory view (ASSUMED).

Rules that feel bad where numbers cannot help: (1) discard is the only relief and it destroys; ITEM-004 fixes it; (2) cause (full Sanctum at departure) and symptom (nothing gathered) sit minutes apart; (3) a held piece costs room and risk, so `pack_capacity` is the lever. Watch it in the first play test.

#### 9. 001b (parked) [CORRECTED D-18]

Not built in 001a. Needs a Notion row with Jeff's yes. Ideas are unchanged except the D-19 note.

**Echo choice beat.** Finds fit: tiles drop together with a portrait badge on each (0.5 s). A real choice: the chooser portrait slides in (0.25 s); per pick it leans and the tile rises into a socket (0.3 s); left tiles sink to the ground line (0.3 s). Cap 2.0 s.
**Ground line.** Left tiles rest on a thin line below the pack row, at full outline and 65 percent fill. PROPOSAL tooltips: `%s took this.` / `%s left this.`
**Manner.** A sure pick pauses 0.2 s; a hasty pick leans at once (0.15 s). Core outputs `manner` per pick; the rule already draws `a < wise_pct`. No fake hesitation. A Standing glyph by the chooser name covers the hasty high-Standing case.
**Bug-like pick.** Pass `sanctum_stack_full` to the seam; rank that find lowest.
**Keeper swap.** One pip at the head of the pack row. Tap a left tile (take), tap a pack tile (drop); either order. An inline strip shows both tiles. `Swap` (primary, 56) and `Cancel` (secondary, 48), 24 units apart; default focus `Cancel`. PROPOSAL: `You can do this once on this path. It cannot be undone.` No ModalHost. Tiles cross in 0.45 s; a keeper hand glyph replaces the portrait badge; the pip empties (0.3 s).
**[D-19 note]** The old design showed carried pieces with a lock glyph, as "safe". D-19 removes that meaning. If 001b refuses a swap on carried pieces (designer A7), it needs a different "cannot swap" mark, and the lock must not mean "safe". The 001b path view must mark carried pieces at risk with the loose-leaf glyph. The swap drop is the only path discard (D-21).
001b dependencies: `manner`, chooser data, `swap: { available, spent }`, left items in the snapshot.

#### OPEN — questions and assumptions

- ASSUMED: The encounter result card hosts the arrival beat. | WRONG IF: it must sit on the path view.
- ASSUMED: `StopMarkMotion.reduced` can drive the new motions.
- ASSUMED: No audio layer exists. Sound items are hints only.
- ASSUMED: Party prep state survives a trip to the inventory view.
- ASSUMED: The line `Lost. There was no room.` shows once per path.
- BLOCKED: Jeff decides A9 (3.3): a draw at every early leave, or a survivor exempt for the stage. I recommend the draw at every leave.
- BLOCKED: Jeff decides C-9 (3.1): a result row of tiles on leave and defeat screens, or a count line only.
- BLOCKED: Jeff decides whether departure needs a modal when carried pieces exist. I recommend none.
- BLOCKED: Numbers for `pack_capacity`, `warn_pack_free_at` and the `level` thresholds (Jeff, D-13).
- BLOCKED: Jeff approves all PROPOSAL lines.


---

## 3. Research: how comparable games handle carry limits and inventory

Source file: `research-comparison.md` (removed in the cleanup of this folder).

**STATUS: evidence at community and wiki level (unverified claims are marked in the text). Still valid as input for 001b and for Jeff's UX redesign.**

### V2-ITEM-001 research: how other games handle shared inventory, loot, loss and cap pressure

Written in STE. Step 0a of the plan (decision D-10).

#### Evidence level: LOW

Two research agents used WebSearch only. WebFetch failed for every wiki and forum host (DNS block). No agent opened a full page.
Every claim comes from a search-result summary. Links are given as the agents reported them. I did not open them.
A claim without a link, or marked UNVERIFIED, is not evidence. Treat all lessons below as hypotheses for the design round.
One scraped page held an embedded instruction aimed at an AI agent. The agent ignored it and used none of that page.
To get verified research, the session network must allow these hosts: steamcommunity.com, fandom.com wikis, wiki.gg wikis, fireemblemwiki.org, stardewvalleywiki.com, support.2k.com.

#### Verification pass 2 (independent searches, same day)

WebFetch is blocked for every host tried, Wikipedia included. Only WebSearch works. I ran eight new searches, written differently from the first pass, and compared them with the first pass. Search-result summaries still, no page opened.

| Claim | Result | Notes |
|---|---|---|
| XCOM 2: loot left on the ground is lost on an evac mission; supply-raid evac gives nothing | CORROBORATED (community level) | Several Steam threads agree. The summary says the posts are from about 2015 to 2016 and may predate patches. No official source. The "2K support FAQ" line from pass 1 was not found again. |
| XCOM 2: on a non-evac mission the game collects loot if you finish before the timer ends | CORROBORATED (community level) | Same threads. A few unconfirmed reports of missing loot. |
| XCOM Enemy Unknown: soldiers outside the drop zone are flagged left behind, then MIA | CORROBORATED (modder notes) | Nexus developer notes plus a Nexus rescue thread. This is not official. Ground gear lost on abort is only "generally" supported. Ufopaedia's "abort = instant loss" is about the final two-part mission only. Do not cite it as a general rule. |
| Darkest Dungeon: a full inventory forces drop choices; leftover supplies are lost; treasure turns into gold on return; trinkets are kept | PARTLY CORROBORATED | Several Steam threads (community level). New detail: unused supplies refund only a small fraction. The 16-slot figure was NOT found again. The pass 1 claim "loot vanishes when the window closes" was NOT found again. |
| Darkest Dungeon 2: a full Stagecoach stops the expedition until the player discards; discarding gives a little Hope; no selling; Storage Trunk adds 3 slots, Spacious adds 6 | CORROBORATED | Wiki and guide results agree (wiki.gg, fandom, fextralife, a guide site). |
| Darkest Dungeon 2: quitting an expedition loses all items and trinkets | NOT RE-VERIFIED | The second search found nothing on abandoning. Still single source (gamepressure). |
| Stardew Valley: pack 12, then 24 for 2,000g, then 36 for 10,000g | CORROBORATED | Several results agree, including the game wiki and forum pages. The number 12 came from pass 1 only. |
| Fire Emblem Three Houses: convoy holds 400, bundles of 99 | NOT CORROBORATED | The search returned nothing on capacity. Treat as unverified. |
| Gears Tactics: no storage cap found; recruit-and-dismiss to move gear | WEAK | Two searches found no cap. The dismiss workaround rests on one Steam thread (same thread both times, so not independent). |
| Dragon Quest Builders 2: a full inventory blocks pickup, even a key item; the Bag unlocks at Furrowfield | PARTLY CORROBORATED | Two guides (GameSpew, Twinfinite), both several years old. No slot count found. |
| Tomodachi Life, Into the Breach details | NOT RE-CHECKED | Still pass 1 only. |

Net effect on the hypotheses below: numbers 3 (Stardew upgrade path), the Darkest Dungeon 2 stop-and-discard rule, and the XCOM 2 loot-loss rule are now supported by more than one source. All of it is still community level. No official source was reached.

#### Verification pass 3 (searches limited to official and game-wiki domains)

Method: WebSearch with `allowed_domains` set to official sites and the games' own wikis. Fetch is still blocked, so these are search summaries of official pages, not page reads. This pass corrects pass 2 where noted.

| Claim | Result | Source type |
|---|---|---|
| XCOM 2: calling extraction early gives up loot, experience and mission success parameters | CONFIRMED by an official source (first reported in pass 1, now found again) | 2K support FAQ, support.2k.com. The FAQ is about 10 years old and predates War of the Chosen. |
| XCOM 2: a fallen soldier's gear is lost if the body is not extracted | Community guidance only | Same search; not from the FAQ. |
| Darkest Dungeon: the mission inventory has 16 slots and holds supplies and collected loot; the trinket stash has 999 slots; each hero has 2 trinket slots | CONFIRMED on the Darkest Dungeon wiki.gg ("Official Darkest Dungeon Wiki") | Corrects pass 2, which could not find the 16. |
| Darkest Dungeon: survivors may claim a dead hero's trinkets "if there is room" | NEW, from the wiki | Relevant to us: a full stash can block a recovery. |
| Darkest Dungeon: on retreat, a random party member dies; the wiki advises unequipping trinkets before abandoning a quest | Reported by the wiki location page; unusual, treat with care | Not matched by any other source. |
| Stardew Valley: pack 12, then 24 (2,000g), then 36 (10,000g) | CONFIRMED on the Stardew Valley Wiki | Players say 36 feels tight since version 1.6. |
| Fire Emblem Three Houses: convoy 400 items; identical items bundle to 99; each unit carries 6 items; convoy access is tied to Byleth | CONFIRMED on fireemblemwiki.org, plus a Serenes Forest forum thread | Corrects pass 2 ("not corroborated"). A forum anecdote says the game may prompt a discard even when the convoy has space (not official). |
| Dragon Quest Builders 2: the bag has a fixed capacity that a patch raised | CONFIRMED that a capacity increase happened (Square Enix official update notes); slot count NOT found | Per-island placement caps for storage furniture (32 for general storage) are on the Dragon Quest Wiki. |
| Gears Tactics: the convoy is the mobile base where equipment cases from the battlefield are opened; gear is outfitted between missions | CONFIRMED in official Xbox and Gears pages; no stash cap found in any official page | Our earlier "no cap found" stands. |

Still without an official source: Darkest Dungeon 2 quit-loses-items rule, Tomodachi Life, Into the Breach, XCOM Enemy Unknown abort rules, and every complaint claim (complaints are community opinion by nature).

What changed for the design round:
- The Fire Emblem convoy gives a second real number set: a large shared pool (400), bundles of 99 for identical items, a small personal carry (6). It fits our mix of unique gear and stacks.
- The Darkest Dungeon "claim a trinket if there is room" rule is a precedent for a full inventory blocking a recovery.
- The XCOM 2 early-extraction rule is now an official precedent for the loss on an early leave.

#### Findings by game

| Game | Cap and storage | Loot to base | Failed or early end | Complaints | Source level |
|---|---|---|---|---|---|
| Gears Tactics | No gear cap found (UNVERIFIED). Roster cap only. | Map cases picked up by a unit; prize claimed at mission end. | UNVERIFIED | Players recruit soldiers to strip gear, then dismiss them. | steamcommunity threads (snippets) |
| XCOM: Enemy Unknown | UNVERIFIED for 2012. Original UFO games: storage "effectively unlimited"; over capacity blocks buying and transfers. | UNVERIFIED | Players say an abort counts as a failed mission. A modder reads the code as: gear of soldiers left behind is destroyed (modder reading, not official). | One bug thread about gear loss on failure. | ufopaedia, steam, nexusmods (snippets) |
| XCOM 2 | No cap found (UNVERIFIED). | A unit picks up loot and must evacuate with it. Loot left on the map is auto-recovered on mission completion. If the carrier dies, the loot drops. | Early extraction forfeits loot, XP and mission parameters (2K support FAQ). | Players ask for mods that retrieve all loot on evac. | xcom.fandom, support.2k.com, steam (snippets) |
| Into the Breach | No shared inventory found (UNVERIFIED). | Time pods are recovered if they survive to mission end. They are destroyed by Vek or damage. Pod risk is visible on the map. | Cores and items are lost on a timeline reset. | UNVERIFIED | intothebreach.fandom, steam (snippets) |
| Darkest Dungeon | In-run loot inventory 16 slots; trinket stash 999; 2 trinkets per hero. | Loot sells for gold on return; trinkets go to the stash. | A dead hero's trinkets are recoverable only after a won battle. Loot rule on retreat: UNVERIFIED. | Players hit the cap mid-dungeon and cannot take gold or gems. Loot left behind vanishes. Some defenders like the risk-versus-reward choice. | darkestdungeon.wiki.gg, steam (snippets) |
| Darkest Dungeon 2 | Stagecoach has limited slots; base upgrades raise them. | Items ride in the Stagecoach; return details UNVERIFIED. | Quitting an expedition loses all items and trinkets from that run. A full Stagecoach stops the expedition until the player discards. | No sell, so players discard spare trinkets freely; some miss the first game's selling. | wiki.gg, fextralife, gamepressure, steam (snippets) |
| Tomodachi Life | No general item cap found (UNVERIFIED). 70 Miis (100 in the original). Delete one Mii to add one. | No expedition loop found. | Not applicable | Gifts for levelling run out quickly (one review). | nerdschalk, games.gg, crystal-dreams (snippets) |
| Fire Emblem (Three Houses) | Convoy 400 items; identical items bundle to 99. | In most games a full unit sends new items to the convoy (not confirmed for Three Houses). | Not applicable | None found. | fireemblemwiki.org (snippets) |
| Stardew Valley | Pack 12, 24 (2,000g), 36 (10,000g). Chests are shared storage. | The player carries items home by hand. | A mine treasure chest gives a swap screen. One forum report says cancelling drops and duplicates the loot (single report). | Pack too small for late areas. Depositing into chests is tedious (a mod exists for it). | stardewvalleywiki, forums, nme (snippets) |
| Dragon Quest Builders 2 | Main inventory plus a Bag; community chest; storage furniture has limits. | The player carries items home by hand. | Not applicable | Early-game carry limit blocks pickups. | twinfinite, gamespew, nintendo (snippets) |

#### What the evidence suggests (hypotheses)

1. **Games that show the loss rule before the player commits get less complaint.** XCOM 2 and Darkest Dungeon 2 state what a quit costs. (Weak: no direct complaint data.)
2. **The closest precedents handle a full cap by blocking or asking, not by silent loss.** Dragon Quest Builders 2 blocks the pickup. Darkest Dungeon 2 stops the expedition until the player discards. Stardew Valley gives a swap screen. Darkest Dungeon (original) loses loot when the window closes, and players complain about it.
   - This is an open tension with D-04 ("item is lost when the cap is full"). D-04 stands. The design round must decide how the loss is warned about and shown.
3. **A hard cap is accepted when the player chooses what to drop and can raise the cap.** Stardew Valley has bought pack upgrades. Darkest Dungeon defenders like the choice. The pain is tedious sorting, not the cap itself.
4. **With no sell, players discard spare gear freely** (Darkest Dungeon 2). D-02 (no sell) therefore makes attachment and the recycle hook the only value for spare gear.
5. **Loot tied to one carrier is fragile** (XCOM 2). Our packs belong to the party, not to one Echo. Keep it so.
6. **Total forfeit on early leave drives players to mods** (XCOM 2). Our roll (nothing, some, everything) is softer. Whether the odds are shown to the player is a design question.
7. **Per-character carry limits make players juggle** (Fire Emblem lesson, from the agent, not from a complaint source). D-02 already gives free transfer.
8. **Exploit risk:** Gears Tactics players strip gear and dismiss units. Free transfer removes the reason. Stardew Valley has one unconfirmed duplication report on a cancelled prompt. Our intake must resolve once, with one deterministic record, and ignore a cancelled prompt.

#### Pitfalls table

| Pitfall | Game | How our design could avoid it | Evidence |
|---|---|---|---|
| Silent loss at a full cap | Darkest Dungeon | A cap meter on the path view and the Sanctum screen; a warning before the path ends; a "will be lost" tag on the incoming item; the loss shown as an explicit event | Medium |
| Player cannot see counts while looting | Darkest Dungeon | Show gear count against the cap in every packs and arrival view | Low |
| Loss rule unclear until after the loss | XCOM abort | State the early-leave rule on the leave confirmation | Low |
| Total forfeit on early leave | XCOM 2 | Keep the roll; decide whether to show the odds | Medium |
| Loot tied to one carrier who can die | XCOM 2 | Packs belong to the party | Medium |
| Gear moved by exploit | Gears Tactics | Free transfer; no per-unit slot ownership | Medium |
| Tedious depositing and sorting | Stardew Valley | One bank step at the path end; free transfer; no per-character limits | Medium |
| Cap too small with no way to raise it | Stardew Valley | A config hook for a cap increase (the Sanctum growth link is not in this story) | Medium |
| Duplication on a cancelled prompt | Stardew Valley (single report) | One idempotency key per intake; ignore a cancelled prompt | Low |
| Spare items worthless when there is no sell | Darkest Dungeon 2 | Recycle hook (Ekwan only); attachment (ITEM-003 and later) | Low |
| Key items blocked by a full cap | Dragon Quest Builders 2 | Keep Threads, entitlements and key items outside the cap (already required) | Low |

#### Not verified

Gears Tactics cap, mission-fail loot and UI. XCOM 2012 loot flow and UI. Into the Breach cap and complaints. Darkest Dungeon retreat loot rule. Darkest Dungeon 2 slot counts and UI. Tomodachi Life item cap, attachment rules and any cap display. Fire Emblem Engage capacity and attachment. Stardew Valley cap warning. Dragon Quest Builders 2 slot counts and UI. Early-leave roll fairness as a pitfall in any game.

#### Gaps for the design round

- No source describes a roll-based settlement of away loot. Our packs rule has no verified precedent.
- No verified source shows how any game displays cap pressure before a loss. The design round must invent and test this.


---

## 4. Research: UI best practices for inventory, loss and confirmation

Source file: `research-ui-best-practices.md` (removed in the cleanup of this folder).

**STATUS: evidence at community and article level. Treat each use as a hypothesis to test in play. Still valid for the UX redesign and 001b.**

### Research: UI best practices for V2-ITEM-001a

Date: 2026-11-01. Method: WebSearch summaries only. WebFetch was blocked. I did not read any page in full.

Evidence labels: OFFICIAL (publisher or platform owner), DEVELOPER (developer talk or post), ARTICLE (third-party analysis), COMMUNITY (forum, wiki, player report), UNVERIFIED (no source found).

Main limit: I found no developer-written source on the XCOM, Gears Tactics, Wartales, Battle Brothers, Fire Emblem or Mutant Year Zero inventory screens. Most evidence is COMMUNITY.

#### 1. Armory and inventory layout

| Finding | Evidence | Source |
|---|---|---|
| A grid shows more items on one screen than a list. A list sorts better. | COMMUNITY | https://forum.chaosforge.org/index.php/topic,6927.55/wap2.html ; https://www.strayspark.studio/blog/inventory-crafting-system-players-enjoy |
| Baldur's Gate 3 uses a grid for equipment slots and a list for general inventory (hybrid). | ARTICLE | https://www.strayspark.studio/blog/inventory-crafting-system-players-enjoy |
| Grid works when item management is part of the play. List works when inventory is a means to an end. | ARTICLE | https://www.strayspark.studio/blog/inventory-crafting-system-players-enjoy |
| Grid cursor navigation is harder on a gamepad than with a mouse. Design for both from the start. | ARTICLE | https://www.strayspark.studio/blog/inventory-crafting-system-players-enjoy |
| Original X-COM forced five screens for one squad decision. The author asks for quick links between related screens. | ARTICLE | https://www.gamedeveloper.com/design/the-ui-missteps-behind-one-of-the-best-games-of-all-time- |
| XCOM 2 modders ask for a link from squad select to soldier loadout, and for armory to show squad membership. Jumping between screens is "cumbersome". | COMMUNITY | https://steamcommunity.com/app/268500/discussions/0/154644705025464376 (via search summary; exact thread not confirmed) |
| Gears Tactics: one review names the between-mission loadout UI as its main criticism. Detail not found. | ARTICLE (mirror site, original not confirmed) | https://wwwrockpapershotgos.pages.dev/posts/gears-tactics-review |
| Darkest Dungeon: unequipped trinkets are one stack per slot. Unique trinkets allow one copy only. | COMMUNITY (official-named wiki, old pages) | https://darkestdungeon.wiki.gg/wiki/Inventory ; https://darkestdungeon.wiki.gg/wiki/Trinkets_(Darkest_Dungeon) |
| Fire Emblem Three Houses: identical items with the same durability bundle into one stack, max 99. Convoy sort uses durability first, then type. | COMMUNITY | https://fireemblemwiki.org/wiki/Supply_convoy ; https://gamefaqs.gamespot.com/boards/204445-fire-emblem-three-houses/77909964 |
| Stardew Valley: inventory rows of 12. An auto-sort button orders by game order and quality. | OFFICIAL-WIKI (fan wiki) so COMMUNITY | https://stardewvalleywiki.com/Inventory |

How identical items are told apart: none of the sources I found shows an explicit "equipped vs spare" mark for twin items. Fire Emblem separates identical items by durability value. This is a gap. See section "Could not verify".

#### 2. Capacity display and warnings

| Finding | Evidence | Source |
|---|---|---|
| Darkest Dungeon provisions: 16 slots. Stack sizes differ (torch 8, food 12). | COMMUNITY | https://darkestdungeon.wiki.gg/wiki/Provisions |
| Darkest Dungeon II: the stagecoach has limited slots. A storage trunk adds four. Players discard to make room. | COMMUNITY | https://darkestdungeon.wiki.gg/wiki/Stagecoach_Items ; https://darkestdungeon2.wiki.fextralife.com/Storage+Trunk |
| Battle Brothers: if loot is not clicked on the post-battle screen, it is discarded. One player lost items to a full stash after closing the window early. | COMMUNITY | https://steamcommunity.com/app/365360/discussions/1/1733216261946060355 |
| Battle Brothers mods add loot sort by value on the loot screen. Players wanted it. | COMMUNITY | https://www.nexusmods.com/battlebrothers/mods/960 |
| Stardew Valley: with a full backpack, a fish caught with treasure moves into the chest menu. Closing it early forfeits the rest. | COMMUNITY | https://stardewvalleywiki.com/Fishing |
| Wartales: weight limit per companion. Camp chests still count toward weight. Players find this confusing. | COMMUNITY | https://steamcommunity.com/app/1527950/discussions/0/575994948960165203 (via search summary) |
| A design note suggests sending overflow loot to a "lost items" box, so the player does not manage inventory right after a peak moment. | ARTICLE (weak, vendor-style page) | https://www.agensi.io/skills/game-design-peak-end-audit |

Pattern: players are hurt when loss happens silently at a moment of rush (closing a window, pressing B). The fix in these reports is a visible count before the loss and a safe place for overflow.

#### 3. Loadout prep and departure

| Finding | Evidence | Source |
|---|---|---|
| Darkest Dungeon: the wiki advises players to unequip trinkets before fleeing, so they are not lost. This is a player burden, not a game warning. | COMMUNITY | https://darkestdungeon.wiki.gg/wiki/Darkest_Dungeon_(location) |
| Darkest Dungeon: unequipped trinkets in the inventory are lost forever on a party wipe, per the Shrieker page. | COMMUNITY | https://darkestdungeon.wiki.gg/wiki/The_Shrieker |
| XCOM Enemy Unknown: some items are not all available before missions. A 2016 thread calls base menus "unintuitive". | COMMUNITY | https://steamcommunity.com/app/268500/discussions/0/412446292777172546 (via search summary) |
| Stardew Valley: fishing treasure and mine loss rules are explained on the wiki, not in the game at the moment of risk. | COMMUNITY | https://stardewvalleywiki.com/The_Mines |

I found no source about a "warning chip" on a prep screen in any listed game. UNVERIFIED for all games. Our chip is new design work.

#### 4. After-action reports

| Finding | Evidence | Source |
|---|---|---|
| Darkest Dungeon: after any exit, a debriefing screen shows. Rewards are greyed out after an unsuccessful run. Unused provisions turn into small gold. | COMMUNITY | https://darkestdungeon.wiki.gg/wiki/Expeditions |
| XCOM 2: gear of dead soldiers is lost on an evac unless a soldier carries the body out. Players learn this from forums. | COMMUNITY | https://steamcommunity.com/app/268500/discussions/0/2789318172117541544 (via search summary) |
| XCOM 2: left-behind soldiers may be recovered on a later rescue mission, with gear. Details conflict between posts. | COMMUNITY | https://cyberpost.co/can-you-recover-captured-soldiers-xcom-2/ |
| A studio moved extra values from a combat report into a detail view opened on tap. | DEVELOPER (small studio blog) | https://millionlords.com/?p=1111 |
| Warframe players: a results screen that fills half the display hides useful information. | COMMUNITY | https://forums.warframe.com/topic/1213187-the-new-mission-endscreen-is-confusing-and-wasting-space/ |
| Short summary first, detail on request, a short delay before the popup. | ARTICLE (weak) | https://www.agensi.io/skills/game-design-peak-end-audit |
| Slay the Spire 2: Mega Crit disabled chest skipping in multiplayer after players confused skip with Proceed. | ARTICLE | https://www.pcgamer.com/games/card-games/slay-the-spire-2-adds-end-of-run-badges-to-let-you-know-what-was-unique-about-each-adventure-in-latest-beta-patch |

Not found: any source on "loot you did not get" display, other than the Darkest Dungeon greyed-out rewards and the XCOM forum explanations. The greyed-out reward is the only visible pattern. It shows what was missed without a text lecture.

#### 5. Loss, retreat and failure tone

| Finding | Evidence | Source |
|---|---|---|
| Roguelike failure reads as investment when each run banks something (currency, unlocks, knowledge). Show progress on the failure screen. | ARTICLE | https://bugnet.io/blog/designing-failure-how-to-make-losing-fun |
| A game over screen breaks flow. It is a metagame element. | ARTICLE | https://www.gamedeveloper.com/design/alternatives-to-the-game-over-screen |
| Fold failure into the fiction instead of ignoring it. | ARTICLE | https://gamespace.com/all-articles/news/game-over-is-not-the-end-how-games-turn-failure-into-part-of-the-story/ |
| Counterpoint: a reviewer disliked a game that coddled the player and avoided stating that failure happened. | ARTICLE | https://popmatters.com/post/font-can-be-insulting |
| Stardew Valley: after passing out in the mines, lost items can be recovered from Marlon at the Adventurer's Guild. This is a recovery path for loss. | COMMUNITY (wiki) | https://stardewvalleywiki.com/The_Mines |
| Darkest Dungeon II: discarding an item gives a small amount of Hope. Loss is turned into a small gain. | COMMUNITY | https://elevation.propertystream.co/darkest-dungeon-ii-discard-guide.html (low-quality site; treat as weak) |
| Stardew Valley: an upgraded trash can returns 15% to 60% of an item's gold value. | COMMUNITY (wiki) | https://stardewvalleywiki.com/Trash_Cans |

Patterns for "warm loss": a recovery path (Stardew Marlon), a small return for a sacrifice (DD2 Hope, Stardew trash can), a greyed-out view of the reward (DD). State the fact plainly (PopMatters counterpoint).

#### 6. Destructive action confirmation

| Finding | Evidence | Source |
|---|---|---|
| Destructive actions need either a confirmation or an undo. Users click through confirmations by habit, so undo is often better. | ARTICLE (GNOME HIG, design system) | https://developer.gnome.org/hig/patterns/feedback/dialogs.html |
| For dangerous actions, put initial focus on Cancel. Escape and outside click must cancel. Return focus to the opener. | ARTICLE (Primer design system) | https://primer.style/product/components/confirmation-dialog/accessibility |
| For irreversible actions, add friction (type-to-confirm). Too heavy for a one-piece discard. | ARTICLE | https://vercel.com/geist/destructive-action-modal |
| Fire Emblem Three Houses: pressing B on the "send to convoy?" prompt turns it into a discard prompt. A later "are you sure" exists (user report). Players lose items by habit. | COMMUNITY | https://gamefaqs.gamespot.com/boards/204445-fire-emblem-three-houses/77904204 |
| Stardew Valley: no confirmation found on the trash can. On Switch, a small stick move toward the trash icon discarded valuable items. | COMMUNITY | https://forums.stardewvalley.net/threads/option-to-remove-auto-sort-button-in-inventory.33757/ ; https://stardewvalleywiki.com/Trash_Cans |
| Stardew Valley: the auto-sort button sits close to the close button. Players press it by accident. | COMMUNITY | https://forums.stardewvalley.net/threads/option-to-remove-auto-sort-button-in-inventory.33757/ |

Lesson: the back or cancel input must never lead toward a more destructive prompt. Keep the discard control away from sort and close.

#### 7. Item tile visual language

| Finding | Evidence | Source |
|---|---|---|
| Do not carry information by colour alone. Add shape, pattern or text. | ARTICLE (vendor page citing Xbox guidance; Xbox claim not checked) | https://color-archive.vercel.app/guides/gaming-accessible-color-scheme/ |
| Colour-blind people tell shapes apart more easily than colours. | ARTICLE | https://cacm.acm.org/opinion/color-blind-accessibility-manifesto |
| A rarity gem icon with distinct shapes was praised by players of a card game. | COMMUNITY | https://pol1.lr.ggtyler.dev/r/ColorBlind/comments/1ht4b1c/how_do_these_look |
| Many tiers with one shape each get cluttered (Phasmophobia developer). | DEVELOPER (forum post) | https://lr.eu.psf.lt/r/PhasmophobiaGame/comments/16ccfvp/shop_v31_feedback_time_again/jzj94vy/?context=3 |
| Factorio players complain about items that differ only by colour. | COMMUNITY | https://forums.factorio.com/viewtopic.php?p=591160 |
| Into the Breach: the developers "sacrifice cool ideas for the sake of clarity every time". They limited how many status effects one action can apply. | DEVELOPER | https://gamedeveloper.com/design/-i-into-the-breach-i-dev-on-ui-design-sacrifice-cool-ideas-for-the-sake-of-clarity-every-time- |
| Stardew Valley: right-click takes one from a stack. Shift plus right-click takes half. | COMMUNITY (wiki) | https://stardewvalleywiki.com/Controls |
| Fire Emblem Three Houses: stack cap 99 per bundle. | COMMUNITY | https://fireemblemwiki.org/wiki/Supply_convoy |

#### 8. Controller, touch and resolution

| Finding | Evidence | Source |
|---|---|---|
| Valve: minimum glyph height 9 px at 1280x800. Valve recommends 12 px. Valve recommends user-adjustable text size. | OFFICIAL | https://partner.steamgames.com/doc/steamdeck/compat |
| Material Design: 48 x 48 dp touch target. Apple: 44 x 44 pt. WCAG 2.2: 24 px minimum, 44 px enhanced. | ARTICLE (secondary summaries; not checked against the primary documents) | https://adrianroselli.com/2019/06/target-size-and-2-5-5.html |
| Grid navigation with a gamepad is harder than with a mouse. | ARTICLE | https://www.strayspark.studio/blog/inventory-crafting-system-players-enjoy |
| Test UI at arm's length on a 1280x800 reference. | ARTICLE (tutorial) | https://bugnet.io/blog/how-to-fix-steam-deck-ui-too-small-to-read |

Note: our minimum is 1280x720, not 1280x800. The Valve numbers are a guide, not a rule for us.

#### 9. Pitfalls players report

| Pitfall | Game | Source |
|---|---|---|
| Silent loss when a window closes with full storage | Battle Brothers, Stardew Valley | see sections 2 |
| Hidden rule: gear lost unless bodies are carried out | XCOM 2 | see section 4 |
| Hidden rule: unequip trinkets before fleeing | Darkest Dungeon | see section 3 |
| Cancel input leads to discard | Fire Emblem Three Houses | see section 6 |
| Accidental discard by stick drift | Stardew Valley (Switch) | see section 6 |
| Inventory chores: scrap and gear pile up unused | Mutant Year Zero (one review) | https://game-wisdom.com/analysis/mutant-year-zero |
| Unclear weight rule (chest still carried) | Wartales | see section 2 |
| Too many screens per decision | X-COM, XCOM 2 | see section 1 |
| Results screen too large, key facts hard to find | Warframe | see section 4 |

---

#### (a) Practices

| Practice | Source games | Evidence | How it applies to our screens |
|---|---|---|---|
| Hybrid layout: grid for unique gear and relics, stacked tiles for consumables, one sort button | BG3 (hybrid), Fire Emblem, Stardew | ARTICLE, COMMUNITY | Sanctum view: one grid, two tile types. Add a sort control away from close and discard. |
| Cap gauge shown always, with count and a state change before full | Darkest Dungeon, Battle Brothers (lack of it caused loss) | COMMUNITY | Gauge in the Sanctum header and in party prep. Change mark and motion at near-full. No colour-only state. |
| Overflow goes to a safe place, not to silent loss | Stardew (chest menu), agensi note | COMMUNITY, ARTICLE | "Party pack" overflow row. Say where each overflow item goes. |
| Shape-coded marks plus text in the detail view | Card games, Phasmophobia, ACM | ARTICLE, DEVELOPER | Equipped, spare, at risk: one shape each, plus a short label in the tooltip. |
| Show durability or a stack badge to separate identical items | Fire Emblem | COMMUNITY | Twin gear: add an "equipped on [portrait]" mark on one tile. Spare tile has a different frame. Needs our own test. |
| Back and cancel must never lead to destruction | Fire Emblem Three Houses | COMMUNITY | Discard needs select, then a separate confirm. Cancel is default focus. |
| Undo or recovery when possible, confirm when not | GNOME HIG, Stardew Marlon | ARTICLE, COMMUNITY | Discard is permanent by rule, so confirm with focus on Cancel. State the permanence in the dialog. |
| Summary first, detail on demand | Million Lords, Warframe complaint | DEVELOPER, COMMUNITY | Result card: three groups (kept, stayed in pack, lost) as icon rows. Names appear on focus or tap. |
| Greyed-out view of rewards not earned | Darkest Dungeon | COMMUNITY | Defeat card shows lost items as faded tiles with a soft mark, not red. |
| Small return for sacrifice | DD2 Hope, Stardew trash can | COMMUNITY | Option for design owner: discard gives a small Sanctum benefit. UNVERIFIED as a fit. Jeff decides. |
| Clarity over cleverness | Into the Breach | DEVELOPER | Limit marks per tile to 2 or 3. |
| Text floor and touch floor | Valve, Material | OFFICIAL, ARTICLE | Test 1280x720 at arm's length. Touch targets 48 units. Text at least 12 px, as Valve recommends. |

#### (b) Pitfalls

| Pitfall | Where seen | How to avoid it for ours |
|---|---|---|
| Item lost with no warning at the moment of risk | Battle Brothers, XCOM 2, Darkest Dungeon | Leave confirmation lists items at risk before the leave. Prep screen shows a chip with the count. |
| Rule known only from a wiki | XCOM 2 gear rule, DD trinket rule | Put the rule in the screen as an icon and one short line. Show it at the point of choice. |
| Back button leads to discard | Fire Emblem Three Houses | Cancel and Back always close. Never map them to discard. |
| Accidental discard by touch or drift | Stardew Valley Switch | Select first, confirm second. Place discard away from sort. Target 48 units or larger. |
| Sort or close pressed by mistake | Stardew Valley | Separate controls by clear space. |
| Result screen too large or too cold | Warframe | Three icon rows. Short warm line. Detail on focus. Allow skip of motion. |
| Two identical items look the same | Not directly seen (gap) | Equipped mark and portrait chip on one tile. Test in grayscale. |
| Colour-only state | ESO, Factorio | Shape plus text for every state. |
| Too many screens per decision | X-COM, XCOM 2 | Link from party prep to the Sanctum view and back. Keep the pack row in prep. |
| Overflow chores | Mutant Year Zero | Stack consumables and materials. Offer sort. Keep cap small but clear. |

#### (c) Could not verify

1. Any developer talk or post about inventory, armory or after-action UI for XCOM, XCOM 2, Gears Tactics, Wartales, Battle Brothers, Mutant Year Zero or Fire Emblem. None found.
2. Gears Tactics armory layout detail. Only one mirrored review line found.
3. XCOM debrief and memorial screen order, pacing and animation. Search returned only mission loot pages.
4. Slay the Spire relic and reward screen design rationale. No developer source found. Only the PC Gamer skip-button note.
5. Into the Breach inventory or reward UI. Only general clarity quotes found. GDC Vault talk is members-only and unread.
6. Mutant Year Zero stash limits. No source found.
7. Wartales and Battle Brothers exact capacity numbers and any warning wording.
8. Darkest Dungeon II end-of-run item rules. Search result was cut off.
9. Any warning chip on a party-prep screen in any listed game.
10. How any listed game marks two identical items as equipped vs spare.
11. Primary Apple, Google and W3C documents for touch target sizes. Only secondary summaries read.
12. Xbox Accessibility Guidelines claim on colour. Only a vendor page repeats it.
13. Tone and wording research for loss messages. Only general articles found. No wording standard exists in these sources.
14. Controller-specific lessons for XCOM, Gears Tactics or Fire Emblem armory screens.
15. Grid versus list preference data from controlled studies. Only opinion articles found. The "Tim Cain" grid page could not be attributed.
16. Several cited pages are mirrors or low-quality sites (pages.dev mirror, agensi.io, propertystream.co). Treat them as weak.


---

## 5. Pack shrink options, designer view

Source file: `pack-shrink-options-designer.md` (removed in the cleanup of this folder).

**STATUS: input for the story that contains shrinking packs. D-41: the rule is deferred. Jeff chose automatic move to the Sanctum with a player choice when the Sanctum is full (feel option B with player choice).**

### Pack shrink with a full Sanctum (designer view)

Written in STE. Everything here is a PROPOSAL except the cited facts. Jeff decides.

#### Facts that bound the question

| Fact | Source |
|---|---|
| The Sanctum never shrinks. Only the pack can shrink. | `decisions.md` D-40 |
| Sanctum has 20 slots, pack has 4 slots. Both sizes are config and can grow. | D-34 |
| Pieces move both ways between pack and Sanctum, anywhere in the Sanctum or party prep. | D-33 |
| Discard in the Sanctum is unlimited, with a confirmation. | D-21, D-33 |
| A pack piece has a saved slot index. A shrink must leave a valid place. | D-37 |
| Stacks fill one slot. | D-40 |
| No mechanical pack penalty exists. | D-36 |
| Loss is a rare, visible event (reasons `overflow`, `defeat`, early leave). | D-16, D-19, D-20 |
| Old saves need no repair. Jeff makes a new save. | D-38 |
| `canon-index.md` has no entry for party size or party composition. | grep, 0 hits |

#### 1. When can the pack shrink, and how likely is a full Sanctum?

| Trigger | Who starts it | Can the game warn first? |
|---|---|---|
| T1. A config or balance cut | Developer | Yes. No player is in the flow. |
| T2. An Echo leaves the party (later story: pack size per Echo, D-34) | Player, at party prep | Yes. Party prep is a stop point. |
| T3. A debuff that cuts the pack | Nobody. D-36 closes this. | Not applicable |
| T4. Mid path | Nobody. The party cannot change on a path (D-34, D-40). | Not applicable |

Result: every real shrink happens at a stop point. The player can see it coming.

How likely is a full Sanctum at that moment? Three reasons, in order:
1. The Sanctum has 20 slots (D-34). The player can discard without limit in the Sanctum (D-21). A full Sanctum is a state the player can fix in seconds.
2. Pieces enter the pack by the Echo choice (D-17) or stay as held pieces (D-16). Held pieces exist BECAUSE the Sanctum was full on an earlier path (D-24).
3. So the two states are linked. A full Sanctum and a pack with pieces occur together more often than chance.

My estimate (unmeasured): rare overall, but not independent. It concentrates on players who hoard and carry. Nobody has data on it. A play test is the only proof.

The overflow size is small. A cut from 4 slots to 3 moves at most 1 piece. A cut to 2 moves at most 2 pieces.

#### 2. Options (fewest new systems first)

##### Option A: move to the Sanctum; if full, the shrink waits (core rule)

- Rule: a shrink applies only when the Sanctum has room for every overflow piece; otherwise the shrink is refused and names the missing room.
- Reuses: the D-33 move action, the D-21 discard, the D-40 `slot_taken` style refusal.
- New state: none. One refusal reason (for example `sanctum_full`).
- Player learns it: the refusal states "Free 1 Sanctum slot to continue." The player uses the normal move or discard.
- Failure mode: it cannot block T1 (a config cut with no player). A saved game may hold a pack over the new size. Needs a rule for that load case (see Option B as the fallback).
- Build cost: small. One check, one reason, one test.

##### Option D: party prep forces the player to empty the doomed slots first (UI flow on top of A)

- Rule: party prep marks the slots that will vanish, and the confirm button stays off until those slots are empty.
- Reuses: the party-prep screen, D-33 moves, D-37 slot positions (the highest indices vanish first).
- New state: none. One preview of the future size.
- Player learns it: the doomed slots show a clear mark before the change. The player sees which pieces are at stake.
- Failure mode: the player feels forced to discard at a bad time. Also T1 still has no player to ask.
- Build cost: small to medium. UI work only. It needs A underneath, so D is an add-on, not a rival.

##### Option B: move to the Sanctum; if full, the extra pieces are lost with a report

- Rule: overflow pieces go to the Sanctum; pieces with no room are lost, and a report lists each lost piece.
- Reuses: loss reason list (add `shrink`), the result-card lanes (D-34), the D-23 tile row.
- New state: one loss reason, one report entry type.
- Player learns it: a loss report after the change. Better: a preview before it.
- Failure mode: the loss is a punishment for something the player may not control (T1, T2). It breaks the rule that loss is rare and caused by the player's own risk (D-19, D-20). The first loss will feel like a bug.
- Build cost: small to medium. Copy, report, tests. Prefer a preview, which then makes B equal to A.

##### Option C: overflow pieces wait in a temporary overflow slot

- Rule: pieces beyond the new size sit in an overflow slot until the player resolves them.
- Reuses: the pack panel, the held-piece draw rules (D-19, D-22).
- New state: a saved overflow list, plus rules for it.
- Player learns it: a new slot type on the pack panel.
- Failure mode: it is a hidden pack size. It does not shrink the pack. Open questions follow: does it roll on an early leave? Is it lost on a defeat? Does it count in the Sanctum cap? Each answer adds a rule.
- Build cost: highest. New save field, new UI, new roll rules, new tests.

#### Comparison

| Option | New systems | New saved state | Silent loss | Handles T1 |
|---|---|---|---|---|
| A | 0 | 0 | No | No |
| D | 0 (UI only) | 0 | No | No |
| B | 0 | 0 | No, if preview exists | Yes |
| C | 1 | 1 | No | Yes |

#### 3. Recommendation (proposal)

Build Option A as the core rule. Add Option D as the UI in the party prep step.

Reason: A uses only the move, discard and refusal rules that D-33 and D-40 already set, adds no saved state, and loses nothing, so it keeps loss rare and visible (D-19, D-20).

For T1, avoid the case instead of handling it:
1. Treat a config cut as a developer act. D-38 means a new save absorbs it.
2. Apply a size change only at party prep, never on a path.
3. Show the new size and the doomed slots before the player confirms.
4. Cut the pack in small steps (one slot at a time) so the overflow is at most 1 piece.
5. The Sanctum only grows, so room exists more often over time.

If a later story needs a shrink with no player stop point (an unblockable shrink), decide Option B for that story. Add the preview first, so the loss is never a surprise.

#### OPEN — questions and assumptions

- ASSUMED: Slots vanish from the highest index down. Pieces in those slots are the ones that must move (D-37).
- ASSUMED: A shrink never happens on a live path. A live path with the party in the Sanctum counts as the Sanctum (D-40), so moves are allowed there.
- ASSUMED: A pack piece moved to the Sanctum takes the first free Sanctum slot (D-34).
- ASSUMED: A stack counts as one piece and moves whole (D-40).
- ASSUMED: The "pack size depends on the Echoes in the party" story lets the player change the party only at party prep.
- ASSUMED: My likelihood reasoning (rare, but linked to held pieces) is an estimate with no data.
- BLOCKED: `canon-index.md` returned no party composition rules. I could not check whether a party can lose an Echo outside party prep (for example in a defeat or an early leave).
- BLOCKED: No data on how often a player holds a full Sanctum while carrying pack pieces. Only a play test answers this.
- BLOCKED: Jeff decides whether the Echo-leaves case (T2) may ever force a shrink with no player action. If yes, A alone is not enough and B is needed as a fallback.
- BLOCKED: Player-facing copy for the refusal message and the loss report is Jeff's. None is final here.


---

## 6. Pack shrink options, game feel view

Source file: `pack-shrink-options-feel.md` (removed in the cleanup of this folder).

**STATUS: input for the story that contains shrinking packs (D-41, deferred).**

### Pack shrink: feel options (game-feel-developer, PROPOSAL)

Everything below is a proposal. Jeff decides. Sound and haptic items are hints only: the project has no audio layer.
Sources: D-16, D-17, D-19, D-20, D-33, D-36, D-37, D-39, D-40; `design-feel-game-feel-developer-v2.md` section 3.3 (lost motion); `pack-debuff-options-feel.md`; `research-ui-best-practices.md` sections 2 and 5.
Word rules (ANSWERS #86): say Sanctum, pack, lost. All player text here is a placeholder. Jeff writes final text.

#### 1. How the player experiences a shrink today, and what makes a loss fair

Nothing is built. D-40 says core builds no shrink rule yet. If a shrink happened in the prototype today:
- The pack panel would show fewer slots. Pieces in the removed slots would have no place (D-37 gap).
- The player would see no cause, no report and no choice. A piece would vanish or sit in a slot that does not exist.
- Because D-39 removed the pack counts, the party details pack button is the only fill signal. It would change number with no explanation.

A loss feels fair when all five hold:

| Test | Meaning |
|---|---|
| Foreseen | The player saw it coming before it happened. |
| Caused | The player chose the action that led to it (or can see the cause). |
| Told | A line names the piece and the reason. Never silent. |
| Located | The player knows where a kept piece went. |
| Avoidable | The player had a way to prevent it (free a Sanctum slot, drop a piece first). |

A loss feels unfair when it happens while the player is away, with no preview, to a piece the player did not choose. The research names silent loss as the top complaint (Battle Brothers, Stardew).
Key point: a move to the Sanctum is not a loss. Only the full-Sanctum case is a loss. The design should make that split clear: most shrinks cost nothing.

#### 2. Options, fewest new systems first

All three reuse the existing lost-tile motion (design v2 3.3): fade to 0.35 over 0.5 s, `EASE_OUT`, lift 8 units (the piece was in the pack), no red, no shake, no strike-through, no sound on defeat. Tone: a leaf let go.

##### Option A: The shrink waits for the player (guided step in party prep) - PROPOSAL

The pack keeps its old size until the surplus slots are empty. The cause is shown first. Applied when the player confirms.

- Sees: the pack panel marks the slots that will go (dashed edge, a small "closing" mark: shape, not colour). One line: `The pack will have 3 slots. Move 1 piece out.` The party details pack button shows the pending change.
- The player drags the piece to the Sanctum (D-33 move) or taps `Move to Sanctum`. When the last marked slot is empty, the slot closes: fade to 0.35 over 0.25 s, then the neighbours shift (0.25 s). Total 0.5 s.
- If the Sanctum is full, the line says so: `The Sanctum is full. Let go of a piece, or free room.` The player picks which piece to let go (existing `Let it go` action, existing lost motion, 0.5 s). The player chooses the loser. That is the fairest loss.
- Report: inline in the pack panel and the party details pack button. No toast, no result card. The guide is a state, not a message chain.
- Failure mode: nagging, and a stuck state. If the cause is not undoable (a house level), the player cannot depart until the step is done. Mitigation: a departure is blocked only for the surplus pieces; the line stays one sentence; no modal.
- Hole: the shrink must never happen while the player is away. If the size drops with no party-prep visit (for example a house level on a result screen), the step opens at the next party prep.
- Reduced motion: no fade or shift. The slot closes with a 0.15 s fade (`RM_FADE_MS`). The "closing" mark is shape and text, so it works without motion. Focus moves to the first marked piece; the line is a live region for screen readers; every move has a button path, not drag only.
- New systems: a "pending size" state saved in the snapshot, and the departure check. This is the most new state.

##### Option B: Automatic move, quiet report, loss report only when the Sanctum is full - PROPOSAL

The shrink applies at once. Surplus pieces go to the first free Sanctum slots (D-37 rule).

- Moved case (the common case). Sees: the marked pieces glide from the closing slots toward the Sanctum glyph (0.4 s, stagger 0.15 s, cap 1.0 s), then the slots close (0.25 s). One quiet line on the party details pack button and pack panel for the rest of the visit: `2 pieces moved to the Sanctum.` No toast. No sound.
- Lost case. Sees: the same glide, but a piece with no room uses the lost motion with lift (0.5 s) at its slot. A loss line replaces the quiet line: `The Sanctum was full. Lost: Moss Charm.` The line names every lost piece (cap 3 names, then a count). It stays until the player leaves the screen.
- Report place: the pack panel line plus a one-time row on the next result card or party-prep entry if the shrink happened away from the screen. A loss is never shown only on a toast: toasts vanish.
- Failure mode: surprise loss. The player never chose it. Worst case: the player opens the game and finds a piece gone. Mitigations: show a preview line before the size change when the cause is a player action (party change: `This party has 3 slots. 1 piece will move to the Sanctum, 1 will be lost.`); keep the loss line until dismissed; add a recovery lane as in the open question below.
- Reduced motion: no glide. Moved pieces fade out of the pack and into the Sanctum grid with a 0.15 s fade. Lost pieces fade 0.15 s, no lift. The line carries the meaning. Never use colour alone.
- New systems: none beyond D-40 and a report string. This is the fewest.

##### Option C: A temporary overflow slot - PROPOSAL

The surplus pieces stay in one extra "waiting" slot per lost slot until the player resolves them. The pack looks as small as the new size, with a tray beside it.

- Sees: a labelled tray (`Waiting`) next to the pack, showing the pieces with no place. The player moves them to the Sanctum or lets them go at any time. A tray piece is not in the pack for a path: it does not come on the path.
- Report: the tray is the report. A small mark on the party details pack button. No toast.
- Failure mode: unclear and heavy. The player must learn a third container. A tray that never empties becomes clutter. The question "does a tray piece count as carried and at stake (D-19, D-20)?" needs a rule. Peak-moment chores (research section 2) get worse.
- Timing: the tray appears with a 0.25 s fade. Removing a piece uses the existing move glide (0.4 s) or lost motion.
- Reduced motion: 0.15 s fades. Tray text and a count word carry the state.
- New systems: a third container, its save field, its size rule and its path rule. This is the most new systems and it adds a concept the player does not need.

#### 3. What to avoid

| Pattern | Why |
|---|---|
| Silent loss | The top complaint in the research. A loss always names the piece and the reason. |
| Loss while the player is away | The player cannot foresee or avoid it. Resolve a loss only on a screen the player is watching, or hold it until the player returns. |
| A modal chain (one dialog per piece) | Click-through by habit (GNOME HIG note). Use one inline line and one list. |
| Choosing the loser for the player with no preview | Unfair. If a loss is needed, preview it or let the player choose. |
| Red, shake, sting, strike-through | Breaks the loss tone (a leaf let go). |
| A toast as the only loss report | A toast vanishes before the player reads it. |
| Loss on a live path | The path view allows no moves (D-33). A shrink must not apply on the path view. |
| Repeating the line | Show it once per shrink. No loop, no nag. |

#### 4. Recommendation - PROPOSAL

Build option B, with one addition: a preview line before the shrink when a player action causes it, and a kept loss line when a piece is lost.

Reason: it is the fewest-systems option, and the move case (almost every shrink) costs the player nothing, so only the rare full-Sanctum case needs a loss moment.

If Jeff wants no surprise loss at all, option A is the safe alternative. It costs one saved "pending size" state. Do not build option C.

#### OPEN — questions and assumptions

- ASSUMED: the shrink has a visible cause (a party change or a house level) and happens on Sanctum or party-prep screens, never inside the path view.
- ASSUMED: Jeff's "lost or destroyed" means the same state as `lost` with a reason such as `shrink`. I use one word, lost, in all text (ANSWERS #86).
- ASSUMED: a shrink caused by a party change in prep can be undone by the player (put the Echo back). If true, a preview line is enough for option B.
- ASSUMED: carried pieces moved by a shrink lose their loose-leaf glyph on landing in the Sanctum (design v2 section 5.2).
- BLOCKED: who chooses which piece is lost when the Sanctum has less room than the surplus? Options: the player (option A), the highest slot index first (option B default), the lowest grade first. Jeff decides. This changes the failure mode.
- BLOCKED: does a shrink that happens away from the screen (house level on a result card) wait for the next party prep, or apply at once? Jeff and the designer decide.
- BLOCKED: should a lost piece stay recoverable for the rest of the visit (a one-tap undo on the loss line)? This is a recovery lane (research section 5, Stardew Marlon). It adds one small state and is my addition, not a request.


---

## 7. Pack debuff options, designer view

Source file: `pack-debuff-options-designer.md` (removed in the cleanup of this folder).

**STATUS: D-36 chose option A: no mechanical penalty. Options B to D stay unbuilt. Revisit only if play shows nobody feels the pack.**

### Pack debuff options (designer view)

Written in STE. Everything here is a PROPOSAL except the cited facts. Jeff decides.

#### Facts that bound the question

| Fact | Source |
|---|---|
| A full pack already limits Echo choices on the next path. "The real pressure is lost room." | `decisions.md` D-17 |
| A carried pack is "a deliberate disadvantage": fewer free slots. | `decisions.md` D-16 |
| Held pieces draw again on an early leave. A defeat empties the pack. | `decisions.md` D-19, D-20 |
| Pack size is 4 and is config. Warning levels exist: 0 none, 1 light, 2 heavy, 3 full. | `data/balance.json:3742`, `InventoryService.gd:59-72` |
| Pieces can move between pack and Sanctum anywhere in the Sanctum. One discard per path. | `decisions.md` D-33 |
| Research: DD2 stops the run on a full cart; XCOM 2 states the loss before the commit. No game found with a stat penalty for a full pack. Evidence level is LOW. | `research-comparison.md` pitfalls table |

Key insight: the player can empty the pack for free before a path (D-33 moves). So any penalty on a full pack is a penalty the player chose to keep. This makes a penalty less needed and easier to feel unfair.

#### Option A: no mechanical penalty (adds zero systems)

Rule: a full pack only costs what D-16, D-17, D-19 and D-20 already cost.

What carries the tension instead:
1. Lost room. With a full pack, a new find has no slot. The player must discard or skip.
2. Risk of loss. Held pieces roll again on an early leave and vanish on defeat. The Sanctum is the only safe place.
3. Pack size. 4 slots makes each slot a real choice.
4. Warning. The existing level 2 and level 3 states show the risk before departure.

Proposal to make it work with no new rule: on the party prep pack, show held pieces with an "at stake" mark. Show the line "These can be lost on a defeat or an early leave." once at departure.

What the player feels: "I am carrying something I could lose." This is a choice about greed, not a handicap. The player never feels the game punished a mistake. The cost is only felt if the player does not read the mark.

Failure mode: the player parks pieces in the pack and never feels a cost until a defeat. The loss then feels late. Fix is the mark and the line, not a rule.

Build cost: near zero. Copy and one mark. Already half built (`pack_load`).

#### Option B: morale nudge at path start (one new number)

Rule: when the party leaves with a pack at level 3 (full), each Echo starts the path with a small morale loss.

- Reuses: `EmotionService.apply_morale_delta` (`core/emotion/EmotionService.gd:244`), which is the only valid morale entry. The status tier is derived from morale, so no new display (`CONVENTIONS.md` 378-417 range).
- New state and numbers: one config value (`pack_full_morale_delta`, for example -5) and one cause string `pack_full`. No new save field if applied once at path start.
- Player learns it: the existing emotional status tier of each Echo drops, and the departure line says "A full pack weighs on the party."
- Failure mode: it duplicates the `burdened` tier name (fear 45 or more). The words will confuse players. It also hits all Echoes for one player choice, and a small morale change may flip a tier boundary that is not visible. A quiet exploit: move one piece out, leave at 3 of 4.
- Build cost: small. One call in the path-start flow, one config value, one cause string, tests for the draw order not changing (no RNG used). Needs a copy decision from Jeff.

#### Option C: carried pieces shift the leave roll (two new numbers)

Rule: each held piece from an earlier path lowers the weight of the "all" outcome on an early leave a little.

- Reuses: `data.rewards.carry_odds` weights and `carry_shares`, settled by `StageSettlementService.settle_leave` (`CONVENTIONS.md:925`). Scout already multiplies those weights and renormalises, so a modifier path exists.
- New numbers: a per-held-piece weight shift and a floor. Odds stay hidden from the player (existing rule, `CONVENTIONS.md:925`).
- Player learns it: only by feel. The leave screen would say "A heavy pack makes a clean exit harder." Hidden odds make this hard to read.
- Failure mode: worst of the three. It stacks a second penalty on D-19, which already rolls each held piece. The player is taxed twice for one choice. Hidden odds make it feel like bad luck, not a cost. It also changes the recorded roll weights, so fixtures re-record.
- Build cost: medium. Touches the settlement choke point and the golden fixtures. Needs opus-level attribution under the project rules.

#### Option D: step budget cost (not recommended)

Rule: a full pack lowers the directive `step_budget` by 1.

- Reuses: the directive `step_budget` (Scout Carefully 3, Seek Signs 6) in `core/movement/StagePartyMovementAdapter.gd` (`CONVENTIONS.md:840`).
- Failure mode: a budget below 2 gives an `authored_override` (same line). Scout Carefully at 3 would hit that edge at once. It also adds movement tuning to an inventory story.
- Build cost: medium to high. Listed for completeness only.

#### Ranking by new systems added

| Rank | Option | New systems | New numbers |
|---|---|---|---|
| 1 | A: none | 0 | 0 |
| 2 | B: morale nudge | 0 (reuses emotion) | 1 |
| 3 | C: roll shift | 0, but touches a choke point | 2 |
| 4 | D: step budget | 0, but touches movement | 1 |

#### Recommendation

Choose Option A. Reason: D-16 to D-20 already make a full pack cost room and risk, and D-33 lets the player empty the pack for free, so a stat penalty would punish a choice the player can undo at no cost. Option A adds the least to a systems-heavy game. If play shows nobody feels the pack, add Option B as the first step, because it reuses one existing service and one number.

#### Proposed test of Option A in play (no code)

1. Play three paths with a full pack at 4 slots.
2. Ask: did you ever leave a piece in the pack on purpose? Did a loss surprise you?
3. If most losses surprise the player, the fix is the "at stake" mark and the departure line. If the player ignores the pack, consider Option B.

#### OPEN — questions and assumptions

- ASSUMED: The Sanctum-to-pack move is free before a path (D-33), so a full pack is always a player choice.
- ASSUMED: The pack size of 4 and the warn levels stay as in `data/balance.json:3742-3747` for the play test.
- ASSUMED: Jeff wants no new player-facing copy decided here. All copy above is a proposal.
- BLOCKED: No data on how often a player carries a full pack into a path. Only a play test answers this.
- BLOCKED: Whether the "at stake" mark and the departure line already exist in the prototype v2 or v3. I did not read the mockups.
- BLOCKED: The research evidence is LOW level (search summaries only). No source shows a stat penalty for a full pack.


---

## 8. Pack debuff options, game feel view

Source file: `pack-debuff-options-feel.md` (removed in the cleanup of this folder).

**STATUS: D-36 chose option A (feedback only). The presentational option B stays unbuilt and is the next step if play shows the pack is not felt.**

### Pack debuff: feel options (game-feel-developer, PROPOSAL)

Everything below is a proposal. Jeff decides. Sound and haptic items are hints only: the project has no audio layer.
Sources: D-04, D-16, D-17, D-19, D-20, D-33, D-34; `design-feel-game-feel-developer-v2.md` sections 2.2, 3.3, 3.5; `research-ui-best-practices.md` sections 2, 3, 9; `inventory-ui-mockup-v2.html`.

#### 1. How the player learns about pack risk today

| Channel | What exists | Source |
|---|---|---|
| Pack gauge | Bead string, 4 beads. Text `Load n of 4`. At full: gold fill, ink keyline, word `Full`. Last bead pulses once (scale 1.15, 400 ms), once per session. | Prototype v2 `gaugePack`, `pulseIfFull` |
| Departure chip | Designed (neutral ink, count, loose-leaf glyph, gold outline when room is low). In prototype v2 it is only a CSS swatch. No live departure flow is shown. | Design v2 2.2; mockup line 1064 |
| Leave panel line | `They may lose 3 pieces. 1 was carried from before.` Designed, number only. | Design v2 2.3 |
| Refusal | `The pack is full. Free a socket first.` Shown only when the player tries a move. | Prototype `rPackFull` |

Honest assessment: it is a good notice, not yet a cost.
- The gauge says "full". It does not say "this has a price".
- The pulse fires once per session. After that, a full pack is silent.
- Loss risk (D-19, D-20) is told only at the leave panel. That is late, and the research shows players dislike late loss (section 2 and 9 of the research file).
- The real cost is already strong: carried pieces can vanish. But the player meets it only as an event, never as a state they carry.
- A full pack today feels like "no room", not "heavy". Nothing in the party looks changed by the load.

#### 2. Options, ranked by new systems (fewest first)

##### Option A: Feedback only (no new rule, no new state) - PROPOSAL

Make the existing risk visible as a state. Four small changes:

| Change | Detail |
|---|---|
| Heavy gauge | At full, beads sit 2 units lower and one tone darker (design v2 3.5 "socket posture"). Gold stays only for actionable things, so full uses a dark leather tone plus a thin strap line, not more gold. |
| Standing risk glyph | The loose-leaf glyph from design v2 2.1 stays on every carried tile, also on the path card. The pack always shows what is at risk. |
| Wording | Replace `Full` with a consequence word. Examples: `Full. Nothing more fits.` on a path, `Heavy. They may lose what they carry.` at prep. One sentence each. Jeff writes final text. |
| Gauge behaviour | The pulse runs at every transition into full, not once per session. One 400 ms pulse, then still. No loop. |

- Sees and feels: the pack looks loaded, like a satchel with a strap pulled tight. The cost is a look, not a number.
- Timing: pulse 0.4 s on the transition only. Tone change fades in 0.25 s.
- Hint only: one soft thud on the transition; one short vibration on a handheld.
- Failure mode: unclear. If the player never opens party prep, the state may go unseen. It cannot punish.
- Reduced motion: no pulse. Tone and glyph change by a 0.15 s fade (matches `RM_FADE_MS`). Meaning is carried by shape, wording and tone, never by motion or colour alone.

##### Option B: Presentational consequence (no number changes) - PROPOSAL

The party visibly carries the load. It changes how the party looks and moves, not how it fights.

| Level (existing `pack_load.level` hook, design v2 3.5) | What the player sees |
|---|---|
| 0 and 1 | Nothing. Normal walk. |
| 2 (heavy) | Party idle sits 2 px lower. Walk cycle is 8 percent slower in the Sanctum and on the path map only. Satchel glyph `LoadMark` shows a bulge. |
| 3 (full) | Same as 2, plus the satchel strap creaks once on entering the path (0.4 s) and a small `Heavy` tag sits on the party card. |

- Sees and feels: "we are loaded down". Dropping one piece lifts the party (a 0.3 s rise). That reward is the point: freeing a socket feels like relief.
- Rule: combat speed, animation timing and input never change. Only walk and idle in non-combat views. The slow walk must never lengthen a wait.
- Failure mode: annoying. A slow walk can read as lag or as a bug. It can also read as a hidden speed penalty. Mitigation: the `Heavy` tag explains it, and the effect is subtle and capped.
- Reduced motion: keep the 2 px posture and the tag. Remove the walk-speed change. The creak is replaced by a 0.15 s fade. Never rely on the slow walk to convey state.
- Cost: needs `level` in the snapshot (already proposed as a data hook) and one art state. No new rule.

##### Option C: Small mechanical hook on an existing system - PROPOSAL

Reuse the early-leave roll (D-03, D-19). Do not add a stat.

- Idea: the pack size sets how much the roll "weighs" in the player's view only, or, if Jeff accepts one rule: a full pack at departure gives the leave panel a stricter default label (`some` shown first). Mechanically nothing new is read, because the draw already exists.
- Lighter variant, one number: when the pack is full at path end, the first gathered item that has no socket goes to a "dropped on the road" card with a 1-tap swap against a held piece. This reuses the D-16 safety net (reason `overflow`) and the existing lanes. No debuff.
- Sees and feels: a full pack now creates a decision at a peak moment (keep the new piece or the old one). Research sections 2 and 9 warn that peak-moment inventory chores feel bad. This is the main risk.
- Timing: swap card uses the existing 0.25 s guard. No extra animation.
- Failure mode: punishing and nagging. It adds a prompt after a win. Keep it to one card, skippable, never repeated.
- Reduced motion: no new motion. Card fades 0.15 s.
- Cost: one swap action and one card. This is still a new rule, so it ranks last.

#### 3. What to avoid

| Pattern | Why |
|---|---|
| Repeating warnings (toast every time the pack is full) | Reads as nagging. One pulse per transition is the limit. |
| Red or flashing full state | Reads as an error and fails colour-blind players. Use shape, tone, wording. |
| Silent loss at a rush moment | The research names it as the top complaint (Battle Brothers, Stardew). |
| A modal at departure | D-17 design: no modal at departure. It blocks the main action. |
| A hidden speed or stat drop with no label | Reads as a bug (Wartales weight confusion, research section 2). |
| Slow input or slow combat from load | Changes pace the player did not choose. |
| Shaming wording (`You are overloaded`) | Punishes a choice the player made on purpose. |
| Stacking cost on cost | Loss risk (D-19) is already a heavy cost. Add feel, not a second penalty. |

#### 4. Recommendation

Do option A now. Add option B later only if play tests show the pack still feels free.

Reason: the real cost (D-19, D-20) already exists, and option A makes the player feel it before they depart, with no new system, rule or number.

Option A is also the least-systems choice. Option B reuses the `level` hook that design v2 3.5 already proposes. Option C adds a rule and a peak-moment prompt, so I do not recommend it.

Play test question for Jeff: after a full pack at prep, does the player say "I should drop something" without being told?

#### OPEN — questions and assumptions

- ASSUMED: "pack debuff" means any cost beyond the D-19/D-20 loss risk, in numbers or in play.
- ASSUMED: the departure chip will be built as designed in design v2 2.2. Prototype v2 shows only its style, not a live flow. I could not confirm chip behaviour by clicking.
- ASSUMED: gold stays reserved for actionable things. A heavy tone for "full" is my proposal.
- ASSUMED: art can supply one extra party idle state and a satchel bulge for option B. Not checked with the artist.
- BLOCKED: none. Final wording and any number are Jeff's.


---

## 9. Artist proposal: tile marks, colour rules and measured contrast

Source file: `mockup-proposal-2-artist.md` (removed in the cleanup of this folder).

**STATUS: the tile marks, states and colour rules are built (see `step8-ui-build.md`). The contrast finding is still OPEN: the design-system file states wrong numbers (gold on the warm panel is 1.72:1, warm tan is 3.66:1). Fix the design-system file after the story.**

### V2-ITEM-001a mockup proposal 2 of 3: artist (look, marks, colour, art scope)

Author: sr-game-artist. Written in STE. Proposal only; no mockup or code exists. Builds on proposal 1. Binding: D-01 to D-30. Motion belongs to the game-feel proposal. Player text is `[Jeff's wording]`.
Citations: `[R7 LABEL]` is `research-ui-best-practices.md` section 7 with its evidence label. Most evidence is weak, so each use is a hypothesis.
Contrast numbers are my own WCAG calculation, not copied from the design-system file.

#### 0. Findings first

| # | Finding | Effect |
|---|---|---|
| 1 | The design-system file states gold on a warm panel as 4.8:1. Measured: 1.72:1 on `#F5E6D3`, 1.45:1 on `#E0D5C3`. Gold on `#120E0C` is 9.13:1. | A gold outline alone is invisible on a light bed. Every gold mark gets an ink keyline. |
| 2 | The file states warm tan `#8B7355` on the panel as 5.2:1. Measured: 3.66:1. | `#8B7355` never carries item text. |
| 3 | Rarity `Rare` is `#7AB5C8` (`art-direction.md`), the same as Fearful and Info. `Uncommon` `#4CAF72` equals Success. | Grade never uses rarity colour (section 3). |
| 4 | `ThreadSlotItem` is a circle sigil disc. `RealmRecoveryCord` legend uses `●`, `≋`, `✕`. | Item marks use no circle disc, no `●`, no `✕`. |
| 5 | Game-feel section 6 wants a dashed placeholder outline. | Dashed is reserved for the lost state. The placeholder uses hatch. |

#### 1. The tile

**Construction (one `ItemTile`, all 8 surfaces).**

| Part | 1280x720 | 1920x1080 | Rule |
|---|---|---|---|
| Bed | 72 | 80 | Rounded square, radius 12. Fill `#DCCEB5`. 1 px inset edge `#785C2B` at 45%. |
| Plate | 64 | 72 | Radius 10, uniform. 2 px border `#785C2B`. Fill `#F5E6D3`. |
| Art slot | 40 | 45 | 62.5% of the plate, centred. Silhouette stays inside the slot with its four corner triangles (8 units) empty. |
| Mark ring | 10 | 11 | Free band around the art. Marks live here. |

The tile brings its own bed, so it reads the same on dark and cream surfaces. The plate edge (4.0:1 on bed), not the fill, carries the shape.

**Two-second read.** (1) Silhouette = kind. (2) Corner marks = which piece, its fate. (3) Bottom row = pips or count. Three marks at most [R7 DEVELOPER].

**Unique piece vs stack.**

| | Unique piece (gear, relic) | Stack (consumable, material) |
|---|---|---|
| Edge | One plate | Two plates: a second plate edge shows 4 units below and 4 right, behind the first |
| Bottom row | Grade pips, left | Count capsule `x7`, right |
| Corner | Twin notch | None |
| Grayscale | One edge, no capsule | Doubled edge, capsule |

**Five states (shape, weight, tone; no motion).**

| State | Shape | Weight | Tone |
|---|---|---|---|
| In the Sanctum | Plain tile, no extra mark | Bed `#DCCEB5` | Full |
| Carried in the pack | Open-leaf glyph, top-left | Bed `#D9C5A0` (darker), socket edge 2 units lower | Full |
| At risk (leave panel S5) | Four corner brackets, 3 units outside the plate, 2 px ink `#3D2817`. Leaf glyph stays. | Plate unchanged | Full |
| Kept (S6, S8) | Brackets and leaf removed. Border grows from 2 to 3 px. | Heavier | Full |
| Lost (S6, S7, S8) | Dashed 2 px outline stays as a ghost. Art and fill fade. | Lightest | Fill and art 35%, kind shape, pips and notch 60%, outline 80% (game-feel owns timing; this is the end state) |

Brackets are the only mark outside the plate. No notch shape is a bracket.

#### 2. Kind shapes and marks

**Placeholder shapes** (flat `#785C2B`, inside the art slot, plain, no detail):

| Kind | Shape | Why distinct in grayscale |
|---|---|---|
| gear | Portrait rounded rectangle, 40% wide | Straight sides |
| relic | Hexagon | Six facets |
| consumable | Triangle, base down | One apex |
| material | Two short parallel bars | Two parts |

No circle (finding 4) and no diamond (diamonds are pips).

**Final art direction by category** (bible 3.3, 3.4, 3.5, 3.6, 4.5, 4.6). Art is one made, mended object on a transparent ground: matte gouache blocks, dark-brown contour (`art-direction.md`).

| Category | Direction | Avoid |
|---|---|---|
| Weapon (gear) | Documented combat forms only. Show iron, wood, cane, skin, fibre, and the wear on the grip. | Royal `afena`, state swords, openwork gold blades (bible 4.5, 4.6) |
| Charm | One cord knot, one plain bead, or one small unmarked brass or wood token (bible charm language) | Any engraved symbol |
| Armor or clothes (gear) | Quilted cotton, layered strip-woven cloth, leather, basketry, restrained brass at seams. Cloth stays visible. | A generic fantasy breastplate; a printed fugu |
| Relic | Bell, vessel, bead strand, flywhisk-like object as an object, not a weapon (bible 3.6). Fictional in-world form. | Close copies of chiefly regalia |
| Consumable | Leaf wrap, cloth bundle, gourd or clay vessel, woven pouch | Glass potion bottles |
| Material | Raw stock: undyed handspun cotton hank, indigo-dipped strip, camwood cake, wood billet, cane, brass offcut | Gems, crystals, coins (D-06: never a price) |

Art colour follows real pigment: undyed cotton, indigo-black, pale one-dip indigo, camwood, forest-green dye, gold only as small leaf (bible 3.5). Label each item documented, adapted or invented (bible 14). Twi names wait for cultural validation.

**Grade pips.** Small diamonds, ink `#3D2817`, in a row at the bottom-left of the mark ring: 6 units at 64, 7 at 72, gap 3. Filled = grade steps; no hollow pips (the ladder is open, ITEM-005). Maximum 5 drawn. Shape and count carry grade. Realm HUD stage diamonds are 16 units, gold, elsewhere; low risk, checked in the mockup.

**Twin notch.** An ink-filled carved mark in the top-right of the ring, 12 units at 64, 14 at 72, 5 clear of the plate edge, from `mark_index` (`int()`; -1 = none).

| `mark_index` | Shape |
|---|---|
| 0 | Solid square |
| 1 | Corner triangle |
| 2 | Half disc |
| 3 | Two bars |
| 4 | Plus |
| 5 | Two-step stair |

Versus the others: notch = solid, top-right; pips = repeated diamonds, bottom-left; source mark = leaf outline, top-left. Position and form differ. Limit: 1 in 6 twin pairs share a shape.

**Source mark (top-left, 14 units at 64).** Held (carried from an earlier path): open leaf, outline with a gap in the stem side. Gathered (found this path): whole leaf, solid. On the Sanctum grid there is no mark. A plain leaf with a midrib only; no Adinkra form, and no Sankofa bird or heart (bible 3.4).

**Equipped slot (ITEM-003).** A blank 14-unit zone at the bottom-centre of the ring. No outline, no label. It is a layout hold; nothing draws there in 001a.

#### 3. Colour use

New tokens: none. `#DCCEB5`, `#D9C5A0` and `#785C2B` already appear in `LivingTreeSystem.tres`.

| Use | Token | Value | Contrast |
|---|---|---|---|
| Plate fill | Warm panel | `#F5E6D3` | ink 11.3:1 |
| Bed (Sanctum) | Chip tan | `#DCCEB5` | ink 8.9:1 |
| Bed (carried) | Parchment | `#D9C5A0` | ink 8.2:1 |
| Plate border, kind shape | Bronze ink | `#785C2B` | 5.1:1 on plate; 4.0:1 on bed |
| Pips, notch, brackets, tile text | Dark brown | `#3D2817` | 11.3:1 on plate |
| Count capsule (normal) | Plate fill, ink text, ink outline | | 11.3:1 |
| Count capsule (at limit) | Gold `#D4AF37` fill, ink 1.5 px keyline, ink text, underline | | text 6.6:1 |
| Cap gauge full, chip `warn.pack` outline | Gold `#D4AF37` + ink keyline | | gold on dark 9.1:1; keyline carries it on light |
| Text on dark surfaces | Cream `#F5E6D3` | | 15.7:1 on `#120E0C` |
| Secondary text | `#785C2B` on panel only | | 5.1:1 on `#F5E6D3` |

**Forbidden for item marks.**

| Colour | Reason |
|---|---|
| Soft blue `#7AB5C8` | Fearful (emotion), Info, and `Rare`. A blue mark reads as an Echo feeling or a notice. |
| Terracotta `#C85A54` | Inspired (emotion); close to Error `#E8412A`. Loss must not read as an error. |
| Forest `#2D6A4F` and Success green `#4CAF72` | Grieving; Success; `Uncommon`. Kept must not read as a reward flash. |
| Rarity colours for grade | Colour-only, and each one already means something else. |
| Weary tan `#8B7355` for text | 3.66:1. |

**Colour-blind rule.** Every state reads by shape or weight (section 1). Gold never stands alone: it comes with a frame (gauge), an underline (stack limit) or a label (chip). The grayscale check in section 7 is a gate.

**Surfaces.** Dark: canvas `#120E0C`, rail. Light: `SanctumCard`, result cards. Tiles go on either.

#### 4. Placeholder look vs final art

| | Placeholder (001a) | Final art (catalogue story) |
|---|---|---|
| Art slot | Hatch (45 degrees, 1 px `#785C2B` at 25%, 6 unit pitch) plus the kind shape | One painted icon per `type_id` |
| Outline | Solid (dashed is lost-only) | Same |
| Name | Grey bar, or `[Jeff's wording]` e.g. `Test piece A` | Display name from catalogue |
| Marks | Real data: pips, notch, leaf, badge | Same code, no change |

**Layout survives the swap** because slot, ring and silhouette rules are fixed now. Rules: one dominant shape, readable at 40 units; no text or symbol in art; contour at least 2 px at master size.

**Catalogue must deliver.**

| Asset | Count | Size |
|---|---|---|
| Item icon, transparent PNG | 1 per `type_id` | 256x256 master, art inside the central 160x160 |
| Category fallback icon | 6 (weapon, charm, armor or clothes, relic, consumable, material) | 256x256 |

The catalogue also supplies name, category, description and the label. No Notion row owns this (decisions OPEN). Pips, notch, leaf, capsule, brackets, kind shapes and `LoadMark` are 001a glyph work, not catalogue art.

#### 5. Surfaces

| Surface | Treatment | Existing style | New style |
|---|---|---|---|
| Inventory panel S1 | Cream card on dark canvas | `SanctumCard`, `SanctumHeaderCard` | None |
| Detail strip | Plaque: cream card, 2 px bronze rule above `Let it go` | `SanctumDetailPanel`, `SanctumRuleSoft` | None |
| Discard modal S2 | Centred cream card. `Keep it` is primary gold. `Let it go` is warm outline, never gold, never terracotta. | `SanctumModalPrimaryButton`, `SanctumModalSecondaryWarmButton` | None |
| Strip `Let it go` | Outline button (bronze border, ink text), 48 high | `SanctumTertiaryButton` | None |
| Result rows (kept, in the pack, lost) | One shelf under each group: kept solid 3 px bronze line, carried solid 1 px, lost dashed 2 px | `SanctumRuleGold` (reuse weight only), `RealmResolveCard` | `ItemShelfLost` (dashed rule) |
| Cap gauge | Row of cap pips; room pips hollow. Near full: ink frame and label. Full: gold fill, ink keyline, thick frame. | `SanctumProgressMarker` | `ItemGaugeFrame`, `ItemGaugeFull` |
| Sockets | Free: bed `#DCCEB5`, flat. Heavy: bed `#D9C5A0`, edge 2 lower. | none | `ItemBedFree`, `ItemBedHeavy` |
| Tile plate | Section 1 | none | `ItemPlate`, `ItemPlateKept`, `ItemPlateLost` |
| `LoadMark` | Satchel outline with 3 weave bands (basketry). Level 0..3 = bands filled 0..3; body sags wider at 2 and 3. No gold. | none | glyph set only |
| `PackLoadChip` | Neutral: `EmotionChip` panel shape, ink text. `warn.pack`: add gold outline with ink keyline. | `EmotionChip*` pattern | `PackLoadChipWarn` |

All new styles go in `assets/theme/LivingTreeSystem.tres`, never in `.gd`. Glyphs use `_draw()` or SVG, as `ThreadSlotItem` does.

#### 6. Tone of loss

Loss is a leaf let go: the tile does not break; it leaves a quiet outline.

| Rule | Reason |
|---|---|
| No red, no terracotta, no strike-through, no crack | `art-direction.md` bars shattered objects. The `ThreadSlotItem` crack line is not reused. |
| Ghost outline stays, art fades | Greyed-out reward is the one pattern found for missed loot [R4 COMMUNITY, Darkest Dungeon] |
| Lost beside kept, plain fact line | Warm, not coddling [R5 ARTICLE] |
| Fade to 35%, not 0 | The player can still read what left [R9 no silent loss] |

No recovery exists (D-19, D-20), so the look implies none.

#### 7. What the mockups show of my part

`anatomy.html` gets four panels.
1. **Swatch sheet:** every token in section 3 with its hex and measured contrast; the forbidden list with the swatch crossed out by a thin line.
2. **Mark sheet at 64, 72 and 3x:** kind shapes; pips; six notches; leaves; capsules; brackets; `LoadMark` 0 to 3.
3. **State strip:** one piece in the five states; one stack in the same states.
4. **Twin test:** two twins in colour and grayscale; the worst case (same notch).

Checks on the rendered PNGs (Jeff looks at these):

| # | Check |
|---|---|
| 1 | Grayscale: can I name kind, state and stack vs unique with colour removed? |
| 2 | At 64: can I tell all six notches apart, and tell a notch from a pip? |
| 3 | Gold on a light bed: does the keyline show? |
| 4 | Does lost look quiet, not hurt? Does it still show what left? |
| 5 | No soft blue, terracotta or rarity colour appears |
| 6 | Worst density (8 tiles on S5, full pack row): no mark touches an edge; text at least 12 px |

#### 8. Risks and questions for Jeff

| # | Question | Recommendation |
|---|---|---|
| A1 | Grade ladder is open (ITEM-005). Pips 1 to 3 only, and no rarity colour for grade? | Yes to both. |
| A2 | Six notch shapes: 1 in 6 twin pairs match. Accept, or raise `mark_count` (D-28)? | Accept; test in play. |
| A3 | Two leaf glyphs (held, gathered), or one? | Two. D-22 makes the line matter on S5. |
| A4 | Lost: fill 35%, marks 60%. Game-feel may want one value. | Two values; the player reads what left. |
| A5 | Fix the wrong contrast numbers in the design-system file? | Yes, after this story. |
| A6 | Who owns catalogue art (256 icon per `type_id`, 6 fallbacks)? | A catalogue story before ITEM-002. |
| A7 | Dashed outline lost-only; placeholder uses hatch. | Yes. |


---

## 10. Merged mockup proposal and the decisions it asked for

Source file: `mockup-proposal-merged.md` (removed in the cleanup of this folder).

**STATUS: historical summary. Jeff answered its decisions in D-31, D-32, then D-33 to D-35 (panels, not full screens). Where it says hub panel or rail destination, read D-33.**

### V2-ITEM-001a mockup proposal (merged, for Jeff)

**STATUS 2026-11-01: Jeff answered decisions 1 to 7 (see D-31 and D-32 in `decisions.md`).** Placement is B: a BottomRail destination with its own flow state. Every other recommendation was accepted. Where this file says "hub panel", read "inventory screen (new rail destination)"; the hub keeps a count card and the chip as entries to it.

Written in STE. Merges `mockup-proposal-1-ui-ux.md`, `mockup-proposal-2-artist.md`, `mockup-proposal-3-game-feel.md`. Proposal only: no mockup and no UI code exists. Jeff approves this file, then the three agents build the mockups, then Jeff approves the mockups, then the UI is built.
Evidence base: `research-ui-best-practices.md` and `research-comparison.md`. Most evidence is community or article level. Treat each use as a hypothesis to test in play.

#### 1. What the mockups will show

Eight surfaces, in the project's mockup format (standalone HTML, true-size canvases, Chromium PNG renders, magenta dashed tap targets, grey bars and `[Jeff's wording]` marks instead of final copy, README with OPEN decisions).

| # | Surface | Where | Reads |
|---|---|---|---|
| S1 | Inventory screen with the discard | new BottomRail destination `flow.inventory` (D-31) | `flow.inventory data.inventory` |
| S2 | Discard confirmation | ModalHost | selected row |
| S3 | Pack row at party prep | `flow.echo_party` | `data.inventory` pack and `pack_load` |
| S4 | Departure chip | party prep and hub | `pack_load`, `warn.pack` |
| S5 | Leave confirmation, tiles at risk | `ReturnHomeModal` | `carry_home_preview.items_at_risk` |
| S6 | Leave result, kept and lost tiles | `flow.resolve` | `data.items` |
| S7 | Defeat card, lost tiles | `flow.resolve` | `packs_lost` params items |
| S8 | Stage-clear card, item preview | `flow.resolve` | new key from D-30 (being built) |

17 files in `docs/stories/v2-item-001/mockups/v1/`: an overview and detail sheets per surface at 1280x720 and 1920x1080, plus `anatomy` (tile marks, states, colour tokens with measured contrast, tap targets, storyboards and CSS-only motion demos that respect reduced motion).

#### 2. Settled by the three proposals (no decision needed unless you object)

| Area | Proposal |
|---|---|
| Tile | One `ItemTile` for all eight surfaces. Plate 64 (1280) or 72 (1920) on its own bed. At most 3 marks per tile. Stack = doubled plate edge plus count capsule. |
| Kind shapes (placeholder) | gear = portrait rectangle, relic = hexagon, consumable = triangle, material = two bars. No circle, no diamond. |
| Marks | Grade pips (small diamonds, 1 to 3 for now), twin notch (six shapes from `mark_index`), source mark (open leaf = carried from before, whole leaf = found this path), blank reserved zone for ITEM-003's equipped mark. |
| Five states | In the Sanctum, carried in the pack, at risk (four corner brackets), kept (heavier border), lost (ghost outline, art at 35%, marks at 60%). All readable in grayscale. |
| Colour | No new tokens. Soft blue `#7AB5C8`, terracotta, forest green and the rarity colours are forbidden for item marks. Gold only for actionable or full, always with an ink keyline. |
| Placeholder look | Hatch plus kind shape, solid outline. Dashed outline is for the lost state only. Final art (256 px icon per `type_id`, six category fallbacks) comes from a catalogue story. |
| Discard | Select tile, then `Let it go` at the strip bottom, then ModalHost. Default focus `Keep it`. Esc, Back, B and an outside tap all mean `Keep it`. `Let it go` is far from Back and any sort or close control. 0.25 s open window and 0.6 s lock after confirm. No hold, swipe or drag. |
| Loss tone | A leaf let go: fade to 0.35, lift 8 units, 0.5 s. No red, shake, shatter or strike. No sound on defeat. |
| Pacing | Item sequence capped at 2.4 s. Reduced motion = 0.15 s fade. Result is true from frame 0. |
| Text | 12 px floor at 1280x720. Names on focus or tap. Items never shown as ids. |
| Core data the UI needs (small additions) | A display `name` on each row from the item definition; the D-30 stage-clear key. |

#### 3. Decisions for Jeff

| # | Decision | Recommendation | Cost of the other |
|---|---|---|---|
| 1 | Where the inventory lives: (A) a hub panel with no new flow state, or (B) a new BottomRail destination | A | B adds a state, controller and nav action, and moves the recorded Sanctum hash |
| 2 | Allow the discard on party prep (`flow.echo_party`) as well as the hub | Yes: widen the core check | Without it the chip must send the player to the hub |
| 3 | Result cards: first tap finishes the motion, second continues | Yes | A card with no skip is 0.75 s on defeat but forces waiting on repeat paths |
| 4 | Show finds that had no room: a tile row on the encounter card plus a mini pack row | Draw it in the mockups as parked for ITEM-002 (which owns find presentation); build only the core keys now | Building it now needs UI on the encounter card and has no real producer to test with |
| 5 | A blocked discard (`path_open`): disabled with a reason, or hidden | Disabled with a reason | A hidden rule cannot be learned |
| 6 | Artist defaults: pips 1 to 3 only and no rarity colour; six twin shapes (1 in 6 twin pairs share one); two leaf glyphs; lost fill 35% and marks 60% | Accept all four | Fewer shapes or one leaf lose information on the leave panel |
| 7 | Feel defaults: 0.25 s open window on modal `Let it go` and on the leave `Confirm`; one pulse on the gauge pip when the Sanctum first becomes full; the carried-piece glide after a discard | Accept all three | The leave `Confirm` change touches an existing modal |

Not proposed (and why): a recovery path or a small return for a discard (D-02, D-04, D-19, D-20, D-21 bar it without new rules; revisit with ITEM-004), a sort button, type-to-confirm (too heavy for one piece), undo (D-21).

#### 4. Findings you should know

- The design-system file states wrong contrast numbers: gold on the warm panel is 1.72:1, not 4.8:1, and warm tan is 3.66:1, not 5.2:1 (the artist recomputed them). Every gold mark gets an ink keyline. Fixing the file waits until after this story.
- The spiral (a full Sanctum, so a full pack, so fewer picks) has its cause and symptom minutes apart. The proposal bridges it with the same pack socket row at party prep, on the encounter card and on the stage-clear card. Decision 4 settles how much of that is built.
- No research source shows how a game marks an equipped piece against a spare twin. The twin notch is a proposal to test in play, in colour and in grayscale.
- Sound and haptic items are hints: the project has no audio layer.

#### 5. Build plan after approval

1. Mockups, built by the three agents in sequence: UI/UX designer (sheets and layout), artist (tiles, marks, swatches, anatomy), game feel (storyboards and CSS-only motion demos). Chromium renders the PNGs at true size. I view every PNG and fix defects before I show you.
2. You review the mockups and the README's OPEN list.
3. Then step 7: the UI build in `.tscn` (new theme styles in `LivingTreeSystem.tres`), then verification and your play test.
