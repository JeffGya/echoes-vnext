# V2-ITEM-001 consolidated design (sr-game-designer, v2)

Written in STE. Design only. D-01 to D-16 bind this design. Every player line is a PROPOSAL; Jeff owns copy. Word rules of ANSWERS #86 hold: Sanctum, path, lost.
Research is hypothesis only (`research-comparison.md`, evidence LOW).

## 0. Reuse and checked facts

**Reused from round 1:** the unique and stack record fields, the `{ result, reason_key, item_id, quantity }` result with `lost_quantity`, the five placeholders, the per-row seed idea, assumption A1 (a stack draws once), the fairness list.
**Dropped:** the `receipts` array (the row fate is the stamp now), the three leave lines, the "cap warning is not actionable" finding.
**Reused from round 2:** the departure chip as a shortcut, "unique pieces only", the `mark_index` idea. Motion detail is not repeated.

| Fact | Source |
|---|---|
| `add_row` rejects a row with no Ase and no Ekwan. An item-only row cannot be written. | `EarningsService.gd:49` |
| `items: []` is reserved on every row. | `EarningsService.gd:23` |
| `nothing_new` looks at Ase and Ekwan only. An item-only pack draws no leave roll. | `StageSettlementService.gd:295` |
| The leave roll is one draw on `stage.settle.<stage_id>.<run_count>.<settle_count>`, seeded from `realm_model.seed`. | `StageSettlementService.gd:362-364` |
| Rows carry `settled`, `lost`, `keep_on_defeat`. A defeat marks losable rows `lost`. | `EarningsService.gd:100-130`, `ActiveStageService.gd:481` |
| The fight row is written after a win here; the leave settle call is `VentureController.gd:365`. | `FlowEncounterState.gd:222` |
| "Some" share is `data.rewards.carry_shares.some` = 0.5. | `data/balance.json:1605-1609` |
| Roster Echoes hold `standing` and `rank` (V1 alias, kept in sync). The actor view from `EchoActor.from_echo` copies `rank`, `calling`, `vector_scores`, `dominant_vector`, `morale`, `fear`, `fear_base`; it does not copy `standing`. | `ProgressionService.gd:347`, `EchoActor.gd:35-60` |
| Standing runs 1 to 9. | `balance.json:1209-1210` (`max_rank`) |
| `economy.relics` is a number. The Resolve `relics` is an array. | `SaveSchema.gd:85`, `ResolveSnapshotBuilder.gd:178` |

## 1. The item journey

Two kinds of item location exist. **Gathered** items sit on the stage record, in item rows of `stage.earnings` (ANSWERS #87: one list, a new source adds a row). **Held** items sit in the Sanctum inventory or in the pack overflow (`inventory.pack`).

| Step | Who decides | What can be lost | Reason key | Saved |
|---|---|---|---|---|
| Found (after a won encounter) | The producer (test) now; ITEM-002 later | Nothing yet | none | `inventory.next_seq` (id minted per unique find) |
| Echo choice | The chooser Echo (section 3), seeded | The finds the Echoes leave | `no_room` (pack full) or `left` | One item row per taken piece; one `left_items` entry per left piece; a decision stamp |
| In the pack (gathered) | Nobody | Early leave, defeat | see below | Item rows on the stage record |
| Keeper swap | The player, once per path | Nothing new: the dropped piece becomes "left" | `swap_used`, `not_left`, `not_gathered`, `path_not_live` on refusal | `stage.swap_used`, both lists |
| Early leave | The existing outcome draw, then one draw per item | Outcome none: all. Outcome some: each item at 50% | `leave_none`, `leave_some` | Row `settled`; entry `fate` |
| Path end (cleared) | The code, no draw | Nothing | none | Row `settled`; entry `fate` |
| Defeat | The code | All gathered items | `defeat` | Row `lost` |
| Sanctum intake | The code, by order | Stack surplus; a direct arrival with no room | `stack_limit`, `overflow` | `inventory.items`, `inventory.stacks` |
| Overflow into the pack | The code, when the Sanctum unique cap is full | Nothing | `to_pack` (a result, not a loss) | `inventory.pack` |
| Lost | none | Final | `overflow`, `stack_limit`, `left_behind` | Entry `fate: lost` plus key |

**Bug check, confirmed.** Fix: `add_row` accepts a row whose `items` array is not empty. `nothing_new` also requires "no unsettled item rows". Item-free packs behave as before; a characterization test proves it first.

## 2. The two containers

**Intake order** (one function, one pass, in item-row order):
1. A stack goes to its Sanctum stack. Surplus above `stack_limit` is lost (`stack_limit`). Stacks never enter the pack. Stacks have no total cap (D-05), so they never meet the unique cap.
2. A unique piece goes to the Sanctum if `items.size() < unique_cap`.
3. Else it goes to `inventory.pack` (result `packed`, key `to_pack`). It already holds a pack slot from the gathered step, so this always fits.
4. Else it is lost (`overflow`). This case needs an arrival that never held a pack slot.

**Finding for Jeff (D-16).** Through the pick route, step 4 is unreachable: a gathered piece already holds a slot. The `overflow` loss is reachable only by a "direct arrival" that skips the Echo choice (for example a path-end reward in ITEM-002). The intake API has a `direct` mode so a test proves step 4 (A1).

**Where the pack lives.** Root save block `inventory.pack` (array of unique records). It survives reload and path change because it is not on a stage record. Additive only.
**Free pack room** = `pack_capacity` minus `inventory.pack.size()` minus the unsettled, unlost item rows of the live stage.

**How the pack empties: automatic. Recommended.** A function moves held pack pieces into the Sanctum, oldest first, while room exists. It runs at two points only: after Sanctum intake, and after the discard action. No new player action is needed (D-08 excludes inventory actions).
*Cost of a keeper "move" button:* a second inventory action outside D-08, a second save write and confirmation. Carried pieces have no use until ITEM-003.
**Invariant:** `inventory.pack` is non-empty only while the Sanctum unique cap is full. A test asserts it after every mutation.

**New path with items in the pack.** The pack goes with the party. The held pieces fill slots, so the party starts with less free room. This is D-16 as decided.

**Are old pack items rolled again? Recommendation: no. Held pieces are safe.** They are exempt from the early-leave roll, from the defeat loss and from the path-end bank. ANSWERS #87 covers what is "earned on a path". A held piece was earned before this path and already passed its roll or bank. D-16 also says an overflow item "is not lost".

| Option | Exploit risk |
|---|---|
| **Held pieces safe (recommended)** | The pack becomes a second safe store of `pack_capacity` slots. The cost is path room, which is the stated disadvantage. No way to turn a gathered piece into a held piece without the roll, so the roll cannot be dodged. Overflow farming gives nothing: the pack stops at `pack_capacity`. |
| Held pieces rolled again | An early leave can destroy pieces that D-16 called not lost. A room penalty becomes a loss penalty and section 9 worsens. |

Label: ASSUMED (A2). Jeff decides.

## 3. The Echo choice rule

**Call site.** After a won fight, beside `record_fight_earnings` (`FlowEncounterState.gd:222`). The input is the list of finds of that encounter. Only a victory decides. A defeat loses the gathered items (`defeat`).

**Chooser.** The party member with the highest Standing among members not knocked out at the fight end; ties go to party order (`active_party_ids`). Field: roster `standing`, fallback `rank` (pattern of `WeavingRiteService.gd:54`). The actor view has `rank` only, and that is the same number.
*Why best Echo:* one face the player can name. An average has no face and is a hidden number. "The Echo that fought" needs combat attribution that does not exist. Mechanics-developer confirms the knocked-out source (A3).

**Ranking without a catalogue.** Rank key per find:
`worth = grade_index * 100 + kind_weight`
- `grade_index` = position of `grade` in `data.inventory.grades`, an ordered list (low to high). ITEM-005 owns the ladder; here the list is only an order. Stacks have no grade: index 0.
- `kind_weight` from `data.inventory.pick_kind_weight` (PROPOSAL order: relic, gear, consumable, material).
- A grade missing from the list gets index 0. If the list is empty, every find ties on grade and the kind weight decides. Ties go to find order.

**The rule, `standing_v1`.** For each free pack slot, in order:
1. Draw `a = randi_range(0,99)` and `b = randi()`, always both (fixed two draws per slot).
2. `wise_pct = clamp(wise_base + wise_per_standing * (standing - 1), 0, wise_max)`.
3. If `a < wise_pct`, take the highest `worth` among the remaining finds. Else take the find at index `b mod remaining`. This may still be the best find.
4. Stop when slots or finds run out.
A low Standing takes a random find more often. When finds do not exceed free room, the Echoes take all.

**Seed path.** New root `inventory.pick.<stage_id>.<run_count>.<situation_id>`, from `realm_model.seed` through `CampaignSeed.get_rng_from`. Not `stage.settle`. Not EchoFactory. Draw count: two per slot filled. A decision stamp (`stage.pick_stamps`, a list of situation ids) makes it exactly-once across reload and a repeated final snapshot.

**The SEAM (interface).** One pure function, replaceable.

| Part | Content |
|---|---|
| Input `finds` | `[{ find_id, type_id, kind, grade, quantity }]` |
| Input `free_slots` | int |
| Input `chooser` | `{ echo_id, name, standing }` used now; `calling`, `vector_scores`, `dominant_vector`, `morale`, `fear`, `fear_base` named, passed, unused |
| Input `party` | ordered ids |
| Input `rng_path`, `config` | the seed path above; `data.inventory.pick` |
| Output | `{ model: "standing_v1", chooser_id, taken: [find_id], left: [find_id], draws: int }` |

The writer applies the output. The stamp stores `model` and `chooser_id`. The later model replaces the function and writes the same output, so the save does not change.

**How the player reads it.** Visual first: the chooser's portrait sits on every taken tile; left tiles show on the path view in a "left" row with the same portrait, dimmed. A swap action shows next to it. Text is a tooltip. PROPOSAL: `%s took this.` / `%s left this.`

## 4. The keeper swap

- **One per path.** Flag `stage.swap_used` on the stage record. A replay makes a new stage record, so the flag resets. A leave and a return keep the same record, so the flag stays.
- **"Left"** = a find the Echoes did not take, because the pack was full. List `stage.left_items`, entries `{ id, type_id, kind, grade, quantity, from: "echoes"|"keeper" }`. It persists with the stage, so it survives reload and leave. The dropped piece joins it (`from: "keeper"`).
- **Action** `inventory.swap.apply`, payload `{ take_id, drop_row_id }`, through `FlowRuntime.dispatch` and a controller. One mutation: check the flag, move both pieces, set the flag, request one save. A refusal changes nothing.
- **Valid targets.** `take_id` must be on the left list. `drop_row_id` must be an unsettled, unlost item row of this stage. Held pack pieces cannot be dropped (that would be a second discard).
- **Exactly-once and undo.** The flag blocks a second swap. No undo exists; a confirmation says so.
- **Exploits:** after the leave draw the rows are settled, so the target check fails (`not_gathered`). A swap is one-for-one and creates no items.
- **Versus a good Echo choice.** The swap overrides freely. It is the player's one say. Cost of blocking it: the keeper loses the only fix for an early-junk pack. A full pack from early finds can lock out a later find (no regret in the rule), and the swap is the cure.

## 5. The free-a-slot discard (D-11)

- **Rule.** Unique pieces only, in the Sanctum inventory. Stacks are out: they never meet the unique cap, and a stack at its limit loses its surplus.
- **One action type, many uses.** Each use discards one piece. ASSUMED (A4): D-11 limits the kind of action, not the count. If Jeff limits it to once per path, section 9 gets worse.
- **Write.** Action `inventory.discard.apply`, payload `{ item_id }`, through `FlowRuntime.dispatch`. The piece is removed from `inventory.items`, then the pack auto-move runs, then one save request. Only valid in the Sanctum, before departure. A piece with a non-empty `held_by` is refused (`equipped`; unreachable until ITEM-003).
- **Pack.** The discard frees the pack through the auto-move: one pack piece moves in, one pack slot frees. No direct pack discard exists: one place, one confirmation, one test.
- **Nothing to discard.** Cap 0, or every piece equipped (ITEM-003; flag to that story). The button does not show.

## 6. Record shapes

**Unique piece** (`inventory.items[]` and `inventory.pack[]`; saved):

| Field | Note |
|---|---|
| `id` | String, `it.<seq>`, from `inventory.next_seq`. No RNG. |
| `type_id`, `kind` (`gear`\|`relic`), `grade` | Per piece. `kind` and `grade` are saved because gear 1.1 differs from 1.2. |
| `held_by` | `""`. Reserved (D-09). Relics carry it too. |

**Stack** (`inventory.stacks[]`): `type_id`, `kind` (`consumable`\|`material`), `quantity`. No id, no grade.
**Item row** (in `stage.earnings`, source `item`): the existing row fields with `ase: 0`, `ekwan: 0`, `scaled: false`, `id: "item:<situation_id>:<n>"`, `items: [entry]`. One entry per row.
**Pack entry** (inside a row): the piece or stack fields, plus `fate` (`gathered`, `carried`, `lost`), `reason_key`, `chooser_id`.
**Intake result:** `{ result, reason_key, item_id, quantity }`, plus `lost_quantity`.
- `result`: `stored`, `packed`, `partial`, `lost`, `rejected`.
- Reason keys: `ok`, `to_pack`, `overflow`, `stack_limit`, `unknown_kind`, `unknown_type`, `kind_disabled`, `duplicate`. Path keys: `left`, `no_room`, `left_behind`, `leave_none`, `leave_some`, `defeat`. Action keys: `swap_used`, `not_left`, `not_gathered`, `path_not_live`, `equipped`.

**Cost shape** `cost: { ekwan, ase }` lives only in config definitions. Ekwan = material and build cost. Ase = shaping and attunement cost. No value is set here (ECONOMY-004 Part B). Not saved.
**Saved:** the `inventory` block, item rows, `stage.left_items`, `stage.swap_used`, `stage.pick_stamps`. **From config definitions:** display name, `cost`, stack limit overrides, recycle-yield key.
**Block** `data.inventory`, numbers unset: `unique_cap`, `pack_capacity`, `stack_limit_default`, `kinds_enabled`, `grades` (ordered), `pick_kind_weight`, `pick.{wise_base, wise_per_standing, wise_max}`, `recycle_yield_ekwan` (keys per grade, empty), `warn_room_at`, `warn_pack_free_at`, `definitions` (empty in shipping). The leave share is read from `data.rewards.carry_shares.some`; it is not copied. A static getter `ConfigService.get_inventory_cfg` reads the block. Save name: use `inventory.items`, never `relics`.

## 7. Placeholder set and the catalogue

Set (reused): `ph_weapon_a`, `ph_charm_a`, `ph_relic_a`, `ph_consumable_a`, `ph_material_a`; new `ph_armor_a` (covers GDD 19.3 slot 3) and fixture grades `ph_g1` to `ph_g3` so the pick rule has an order to test. No real weapon names (bible 3.6, 4.1).
**Where.** Fixture and producer sit under `tests/` (for example `tests/fixtures/inventory_placeholders.json`). Reason: everything under `res://` ships (`export_presets.cfg` filters are empty), so a `data/` fixture would ship. The fixture overlays config only inside a test or the debug producer. Jeff's play test uses a debug action `debug.inventory.produce` (DebugController, layer 128). Guard tests: no `ph_` id in `data/balance.json`; none in a new save; no non-debug code calls the producer.
**Catalogue owner.** No Notion row owns names, categories, grades, art or descriptions. FLAG: Jeff decides on a catalogue story before ITEM-002. ITEM-005 owns the grade ladder. The `grades` list here is a placeholder for it.

## 8. View requirements

| View | Show at a glance | Keep out |
|---|---|---|
| **Sanctum inventory** (read-only except the discard) | Count against `unique_cap`, a full state. Pieces by kind, icon, grade mark, twin mark. Stacks as tiles with a quantity badge and an at-limit mark. The discard button on a selected piece. | Ase and Ekwan balances. Threads and partial recoveries (GDD 14.2). Ids. `held_by`, cost, yield. Recycle, equip, sell. |
| **Packs on the path** | Gathered tiles with the chooser portrait; the free-room count; the left row; the swap action (spent state after use); the leave confirmation with per-item marks. At the path end, each item as stored, in the pack, or lost, with a reason mark. | A merged total with currency. Odds. A material as a number. |
| **Pack in the Sanctum (carried load)** | Pack sockets: filled by held pieces, empty ones free. Shown at party prep and on the departure chip. The chip is quiet by default, gold at `warn_pack_free_at`. | Same as above. |

Items use tiles in their own region. The line `In their packs: <Ase> Ase and <Ekwan> Ekwan.` stays a number line.
PROPOSAL lines: `The Sanctum is full. These stay in their packs.` / `They have less room to carry this time.` / `Lost. There was no room.` / `Lost. They did not get it out.` / `Lost. The party fell.` / `They left this behind.` / `Let this go? It cannot be brought back.`

## 9. The disadvantage (D-16)

**Fair?** Yes. The player causes it by filling the Sanctum. The cost is room, not pieces. It is bounded by `pack_capacity`.
**Readable?** Only if shown before departure and on the leave confirmation. Otherwise it repeats the Darkest Dungeon silent-loss complaint (evidence Medium).
**Spiral?** A stall, not a lock. Trace: Sanctum full, path ends fill the pack to `pack_capacity`, free room is 0, the Echoes pick nothing. Nothing is lost, because held pieces are safe. The way out is the discard: one piece for one pack slot.

| Guard rail | Inside decisions? |
|---|---|
| Held pieces safe from roll and defeat (section 2) | Yes. Recommended. |
| Only unique pieces overflow; stack surplus is lost, not parked | Yes. Recommended. It stops a stack from holding a pack slot with no relief. |
| Discard auto-moves a pack piece in (one discard frees one pack slot) | Yes. Recommended. |
| Carried load visible at party prep, chip gold at `warn_pack_free_at` | Yes. Recommended. |
| A floor: overflow may fill at most `pack_capacity - pack_min_free` slots; the next piece is lost (`overflow`) | NO, it softens D-16 the other way. OPTION for Jeff. Cost: a lost piece the player could not avoid. Benefit: picks never reach 0. |

## 10. Scope and risks

**New work from D-11 to D-16:** the pack container, auto-move, the discard action, the pick seam with `standing_v1`, the left list and swap, the item rows and per-item leave draws, the pack view. **For follow-up:** the full Echo decision model (Calling, vectors, emotion; Notion row needs Jeff's yes), real drops (ITEM-002), equip (ITEM-003), recycle (ITEM-004), the grade ladder (ITEM-005), crafting with materials (D-07).
**One subject?** Borderline. The subject is "how items travel from a path to the Sanctum". It holds, but it is large. **Cut line if Jeff wants it smaller:** 001a = containers, intake, item rows, leave draws, discard, Sanctum view. 001b = Echo choice, left list, swap, packs view. In 001a the producer fills the pack in find order through a default `take_in_order` seam function. The seam stays, so 001b needs no save change.

| Risk | Note and mitigation |
|---|---|
| Dead end | Sanctum full plus an all-equipped Sanctum (ITEM-003). Flag to ITEM-003: equipped pieces must not block relief. |
| Exploits | Section 2 and 4. Replay farming of items is ITEM-002's rule to own. |
| Determinism, save | New roots `inventory.pick.*`, `inventory.leave.*`. Outcome draw unchanged for item-free packs. Ids from a counter. Additive `inventory` block with a repair pass; stage fields default safely. |
| Name clash | `economy.relics` (number), Resolve `relics` (array) and relic items stay apart; use `inventory.items`. |
| GDD (list only) | 19.3 slot 4 shares "relic or consumable", while D-05 caps relics only. 19.8 says gear is claimed "through Echo choice events"; D-12 uses "Echo choice" for pickup: use two names. 19.10 and 21.1 list the cap structure as open; D-05, D-13, D-16 now set the structure. 19.7 "recycle returns Ekwan only" matches D-02. |

## OPEN — questions and assumptions

- ASSUMED: A1. With one slot budget, D-16's "both full, item lost" is reachable only for a direct arrival (no Echo choice). Jeff confirms that is intended.
- ASSUMED: A2. Held pack pieces are safe from the roll, the bank and defeat. Alternative: rolled again (section 2).
- ASSUMED: A3. "Not knocked out" is readable at the fight end; the chooser is the highest Standing among them.
- ASSUMED: A4. The discard is one action type, usable many times per Sanctum visit.
- ASSUMED: A5. One item row holds one entry. A stack draws once as a whole.
- ASSUMED: A6. Stack surplus above the limit is lost and never enters the pack.
- ASSUMED: A7. The keeper swap may drop only gathered pieces, not held ones.
- BLOCKED: Numbers for `unique_cap`, `pack_capacity`, `stack_limit_default`, `pick.*`, `warn_room_at`, `warn_pack_free_at` (Jeff, D-05, D-13).
- BLOCKED: Does Jeff want the guard-rail floor `pack_min_free` (section 9)? It changes D-16.
- BLOCKED: Is the full Echo model a follow-up with a new Notion row? Jeff's yes is needed.
- BLOCKED: Which story owns the item catalogue? No Notion row exists.
- BLOCKED: Split the story at the section 10 cut line?
