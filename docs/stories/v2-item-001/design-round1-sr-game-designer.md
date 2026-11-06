# V2-ITEM-001 design round 1 (sr-game-designer)

Written in STE. Design only. D-01 to D-10 bind this design. Copy lines are PROPOSAL; Jeff owns copy.
Research evidence is LOW overall (`research-comparison.md`). I use it as hypotheses and quote its labels.

## 0. Facts checked against code

| Fact | Source |
|---|---|
| A packs row has an `items` array, always empty. | `EarningsService.gd:23` |
| `add_row` rejects a row with no Ase and no Ekwan. An item-only row cannot be written today. | `EarningsService.gd:49` |
| `nothing_new` looks at Ase and Ekwan only. An item-only pack draws no leave roll today. | `StageSettlementService.gd:295`, `:344` |
| The leave roll is one draw on `stage.settle.<stage_id>.<run_count>.<settle_count>`. | `StageSettlementService.gd:362-364` |
| The "some" share is `data.rewards.carry_shares.some` = 0.5. | `data/balance.json:1605-1609` |
| A defeat marks losable rows `lost`. | `EarningsService.gd:120-130` |
| `economy.relics` is a bare number. The Resolve snapshot also has a `relics` array. Both are stubs. | `SaveSchema.gd:85`, `SaveService.gd:501`, `ResolveSnapshotBuilder.gd:178` |

## 1. Cap warning (question 1)

**Finding.** D-04 (item lost at a full cap) plus D-08 (no drop or recycle action) means the player cannot free a slot in this story. A cap warning is therefore not actionable. By the UI rules, a non-actionable signal must not look blocking. The warning informs. It does not gate.

**Recommendation.** Show cap pressure at five points. Information order follows AGENTS.md: world behavior, spatial UI, compact contextual UI, reference UI.

| # | Where | Order | What the player sees |
|---|---|---|---|
| 1 | Sanctum inventory view | Reference | Count against cap, always shown. A full state. |
| 2 | Departure (party prep and path select) | Compact contextual | A small room chip. It appears only when free room is at or below a config threshold. Quiet weight. |
| 3 | On the path, in the packs | World behavior, then compact | The packs read fuller as items join (game-feel round decides the visual). A room chip stays in the packs view. An item that will not fit carries a "no room" tag the moment it joins. |
| 4 | Leave confirmation | Compact contextual | Item count, room left, and the early-leave rule in words. |
| 5 | Path-end card | Compact contextual | Each item shows stored or lost, with a reason mark. The loss is an explicit event. |

Points 3 and 4 satisfy "before a path ends". Point 5 is the record, not the warning.

**Who chooses the loss.** The player does not choose. Rule: held items are never displaced. Arriving items enter in packs-row order. Items after the last free slot are lost with reason `overflow`. The tags in point 3 let the player predict this order. Reason: it is deterministic, explainable in one sentence, and it keeps D-04 intact.

**Cost of the alternative (player chooses).** It needs a modal, a discard action and a second save path. D-08 excludes inventory actions. See Options.

**Tag exactness.** At path end the "no room" tag is exact. Before a leave it is "may not fit", because the leave roll runs first and the cap check second.

PROPOSAL lines:

| Slot | Line |
|---|---|
| Room chip | `Room in the Sanctum: %d` |
| Tag on a joining item | `No room. It will be lost.` |
| Leave confirmation, risk | `If they leave now, they may carry less.` |
| Leave confirmation, finish | `If they finish the path, they carry all of it.` |
| Leave confirmation, room | `The Sanctum has room for %d more. The rest will be lost.` |

## 2. Leave roll and items (question 2)

**Rule check (D-03).** Outcome "nothing": all items lost. Outcome "all": all items go to intake. Outcome "some": each item entry draws alone at 0.5.

**Legible?** Yes, if the return card shows the fate of every item. A currency "some" is always exactly half. An item "some" is a coin flip per item, so a one-item pack is all or nothing. The expected value is equal. The felt value differs. The return card must say it per item.

**Recommended draw design.**

1. Seed path per item entry: `inventory.leave.<stage_id>.<run_count>.<settle_count>.<row_id>.<index>`. One draw: `randi_range(0,99) < share*100`. Read the share from `data.rewards.carry_shares.some`. Do not copy it into the new config.
2. Keying by row id and index makes each result independent of row order. Adding an item before a leave cannot reshuffle other items.
3. The existing `stage.settle` stream is not touched. Item draws happen only after the outcome is "some".
4. A stack entry draws once as a whole (assumption A1).
5. Fate is saved on each item entry (`carried` or `lost`, plus reason). Reload and retry then read the fate. They never redraw.
6. The packs must count items in `nothing_new`. An item-only pack must trigger the outcome roll. For item-free packs the behavior stays identical (step 1 characterization proves it).

**Fairness and exploit list.**

| Issue | Severity | Answer |
|---|---|---|
| Double jeopardy: an item survives the roll, then overflows at intake. | Medium | Say so on the leave confirmation (room line). |
| No protection for a valuable item. One piece can vanish while junk survives. | Medium | Accepted by D-03. Jeff may want a later protect rule. |
| Replays farm items. Replay factor scales currency. Items are not scaled. | High for ITEM-002 | Out of scope here. ITEM-002 must own a repeat rule. |
| Reload before a leave gives the same outcome. | Low | Same as currency today. The per-item seed adds no new leak. |

**What the player is told before leaving.** Hypothesis from research: XCOM 2 states that calling extraction early gives up loot. This is CONFIRMED by the 2K support FAQ (pass 3), but the FAQ is about ten years old. The XCOM 2 precedent is a total forfeit. Ours is softer. Recommendation: tell the rule in words, show no odds (the config comment says odds are never shown), and show the item count. Use the three lines in section 1. Do not use "banked", "settled" or "roll" in any tooltip (phase 7 copy rule).

## 3. Inventory shape (question 3)

D-01, D-05 and D-06 fix the model. Save block: `inventory`, additive, default empty.

**Unique piece (gear or relic).**

| Field | Type | Where | Note |
|---|---|---|---|
| `id` | String | Save | Minted at intake from a counter in the block. No RNG. |
| `type_id` | String | Save | Key into the config definitions. |
| `kind` | String | Save | `gear` or `relic`. Config wins for display. The saved value is used only if the definition is missing. |
| `grade` | String | Save | Per piece, because gear 1.1 differs from 1.2. Valid values come from `data.inventory.grades`. |
| `held_by` | String | Save | `""`. Reserved (D-09). I assume relics carry it too, because GDD 19.3 slot 4 is equippable (A2). |
| `cost` | `{ ekwan, ase }` | Config definition only | Ekwan = material and build cost. Ase = shaping and attunement cost. This story sets no value. |

**Stack (consumable or material).**

| Field | Type | Where |
|---|---|---|
| `type_id` | String | Save (the key) |
| `kind` | String | Save: `consumable` or `material` |
| `quantity` | int | Save |
| `stack_limit` | int | Config (default plus optional per-type override) |
| `cost` | `{ ekwan, ase }` | Config definition only |

A stack has no instance `id`. A stack has no `grade`. Two grades of one consumable are two types.

**Save block.** `inventory = { version, next_seq, items: [unique...], stacks: [stack...], receipts: [intake keys] }`. A receipt key is `<row_id>.<index>`. A repeated intake finds the receipt and returns `duplicate`. Receipts older than the current run may be pruned (config count).

**Config block `data.inventory`.** `unique_cap`, `stack_limit_default`, `kinds_enabled` (the `grade_enabled` pattern), `grades`, `recycle_yield_ekwan` per grade (keys only, values empty, D-02), `warn_room_at`, `definitions` (empty in shipping). Every number follows ANSWERS #83.

**Packs entry before intake.** `{ type_id, kind, grade, quantity, fate, reason_key }`. It has no instance `id`. The row must allow zero Ase and Ekwan when it holds items.

**Intake result.** `{ result, reason_key, item_id, quantity }` as in the plan, with two additions (A3): `lost_quantity` for a partial stack, and the reason `unknown_type` for a `type_id` with no definition. Reasons: `ok`, `overflow`, `unknown_kind`, `unknown_type`, `kind_disabled`, `stack_limit`, `duplicate_id`. Reasons for a loss outside intake: `leave_none`, `leave_some`, `defeat`.

## 4. Placeholder item set (question 4)

Placeholders are fixtures, not content. They carry no real weapon name or action profile (bible sections 3.6 and 4.1: a weapon needs a combat action; ITEM-003 owns that).

| Id | Kind | Proves |
|---|---|---|
| `ph_weapon_a` | gear, category weapon | Unique piece. Two intakes make two ids (1.1 versus 1.2). |
| `ph_charm_a` | gear, category charm | A second gear category. |
| `ph_relic_a` | relic | Relic path. Also the disabled kind: the test turns `kinds_enabled.relic` off. |
| `ph_consumable_a` | consumable stack | Stack, merge and `stack_limit`. |
| `ph_material_a` | material stack | Material guardrail: no price, no balance. |
| (no definition) | `ph_unknown` | `unknown_kind`. A test literal only. |

Cap tests set `unique_cap` low in a test config. That needs no extra item.

**Where they live.** In a separate file `data/test_fixtures/inventory_placeholders.json`. The shipping `data.inventory.definitions` stays empty. Ids start with `ph_`. A test asserts three things: no `ph_` id in `data/balance.json`, no `ph_` item in a new save, and the fixture loads only through the test producer. Jeff's play test (plan step 7) needs placeholders in the running game. A debug-panel producer on layer 128 serves that (A4).

**Catalogue owner.** No Notion row owns the real item catalogue (names, categories, grades, art, descriptions). Flag for Jeff: a catalogue story is needed before ITEM-002 builds real drops.

## 5. Views (question 5)

Requirements only. No layout.

**Sanctum inventory view (read-only).**

| Show at a glance | Keep out |
|---|---|
| Count of unique pieces against the cap, and a full state | Ase and Ekwan balances |
| Pieces grouped by kind, with icon, name, grade mark | Threads and partial recoveries (GDD 14.2: they are not items) |
| Stacks as a tile with a quantity badge, and an at-limit mark | Item ids (UI rule) |
| An overflow-risk state when room is at or below the threshold | `held_by`, cost, recycle yield (not set, not used) |
| | Any action: recycle, drop, equip, sell |

**Packs view on the path.**

| Show at a glance | Keep out |
|---|---|
| Item tiles in the packs, each with a state: in the packs, no room, lost, carried | A merged total with currency |
| The room chip | Odds |
| The count line on the leave confirmation | Materials as a number in a header |

**Telling items apart from currency and recoveries.** Items use tiles with icons in their own region. Ase and Ekwan stay as the existing numeric line `In their packs: <Ase> Ase and <Ekwan> Ekwan.` Items get a separate second line. A material shows only as a stack tile with a quantity badge. It has no total, no price tag and no balance (D-06). The snapshot projection carries no Thread or partial-recovery key. A test asserts that.

PROPOSAL lines: `Also in their packs: %d things.` / `Stored in the Sanctum.` / `Lost. There was no room.` / `Lost. They left too soon.` / `Lost. The party fell.` Word rules from ANSWERS #86 hold: no "home", no "stage".

## 6. What this story must not build (question 6)

| Story | Not built here |
|---|---|
| ITEM-002 | Real drops, `loot_results` delivery, relic finds, the `guide_spirit_protected` entitlement, drop cadence, a replay rule for items |
| ITEM-003 | Equipping, slots, loadouts, action profiles, weapon fields, any write to `held_by` |
| ITEM-004 | Recycling, upgrades, rite offerings, recycle values, drop or discard actions |
| ITEM-005 (order 259) | Rarity ladder, grade spread. Here `grade` is an opaque config key. |
| ITEM-005 (order 249.2) | Death-formed relics |
| ECONOMY-003 | Recipes, first crafted item, crafting costs, Sanctum projects, using materials |
| ECONOMY-004 Part B | Any Ase or Ekwan price, any `cost` value |
| Unowned | The item catalogue, cap growth through the Sanctum |

## 7. Risks (question 7)

| Risk | Detail | Mitigation |
|---|---|---|
| Dead end (highest) | Junk fills the cap. D-08 gives no way to free a slot. Every later find is lost. | Do not ship ITEM-002 real drops before a relief action exists (ITEM-004 or a discard). Or set the cap high. Jeff decides. |
| Hoarding | Free hold and no sell. Stacks grow to the limit. | Per-stack limit. Stack types are bounded by the catalogue. |
| Exploit | Duplicate on reload or retry. Replay farming. | Receipts and per-entry `fate`. Replay rule goes to ITEM-002. |
| Determinism | New draws only. | New seed root `inventory.`. No `stage.settle` change. No EchoFactory change. Ids come from a counter. |
| Save safety | Additive only. | New block with a repair. `economy.relics` and the Resolve `relics` array stay as they are. Old rows already have `items: []`. |
| Name clash | `relics` number and array versus relic items. | Keep separate. Name the new key `inventory.items`. |
| GDD | 19.10 and 21.1 list "inventory cap structure" as open. D-05 sets the structure but not the numbers. | Report only. Do not edit the GDD. GDD 19.3 "relic or consumable" shares one slot. D-05 caps relics but not consumables. This is compatible but should be stated. |

## Options for Jeff to consider (not decisions)

These do not reverse D-04. Each softens how the loss feels. Research labels: Stardew swap screen and Darkest Dungeon 2 stop-and-discard are community level (corroborated). Darkest Dungeon (original) silent loss draws complaints.

| Option | Trade-off |
|---|---|
| A. Swap or discard choice at arrival | Player picks the loss. Needs a modal, a discard action, and a change to D-08. Costs scope. |
| B. Bounded overflow list (for example 3 slots, kept until the next arrival) | Rescues rare finds. Adds a second container, an expiry rule and save shape. Softens D-04. |
| C. Best-grade-first intake order | The best items take free slots first. No UI choice. Less predictable than row order. |
| D. One pre-departure "free a slot" action | Removes the dead end. Smallest change. It is an inventory action, so it needs a change to D-08. |

## OPEN — questions and assumptions

- ASSUMED: A1. A stack entry draws once as a whole, not per unit.
- ASSUMED: A2. Relic records carry `held_by` like gear.
- ASSUMED: A3. The intake result gains `lost_quantity` and the reason `unknown_type`.
- ASSUMED: A4. A debug-panel producer counts as the "test-only producer" so Jeff can play with placeholders.
- ASSUMED: A5. The per-item tags and the path-end stored or lost marks are in scope. D-08 says "Resolve-card reason lines" are not selected. I read that as the general reason-line system.
- ASSUMED: A6. Intake order is packs-row order, and held items are never displaced.
- BLOCKED: Cap number, stack limits and `warn_room_at` need Jeff (D-05).
- BLOCKED: Does Jeff accept an unactionable cap warning, or does he pick Option A, B or D? This is the main design question of this round.
- BLOCKED: Who owns the item catalogue? No Notion row exists.
