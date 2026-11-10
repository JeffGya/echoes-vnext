# V2-ECONOMY-004 Part B: recipe and price contract (design round)

Author: sr-game-designer. Date: 2026-11-09. Status: PROPOSAL for the build plan. No code. No price numbers.

Binding decisions (not re-opened): D-01, D-04, D-122 to D-136, ANSWERS #83, #86 to #89.

## 0. What this contract is

Part B builds the SHAPE of a price. It does not build crafting (ECONOMY-003), the item catalogue (ITEM-002), the grade ladder (ITEM-005) or recycle (ITEM-004).

Part B delivers:
1. A recipe record shape in `data.inventory.recipes` (shipping block stays empty, D-131).
2. A rule set that checks one record (validation).
3. An afford check that returns one reason key.
4. A "pay both" method on `EconomyService` (D-132).
5. Placeholder recipes in `tests/fixtures/recipe_placeholders.json` only (D-131).

Part B has no player-facing element (D-133). No text, no screen, no animation.

Player experience goal (for later stories): the Keeper must feel that making an item is a real choice. Ekwan pays for matter and build capacity. Ase pays for shaping and attunement (GDD 19.2, 19.6). The player decides what to save for, and what to give up.

## 1. Research: how comparable games structure cost (JOB 1)

Scope: the cost contract. Sources are fan wikis and guides, so exact numbers vary by game version.

| Game | Currencies and inputs | Price by tier | Make vs upgrade | Second currency kept distinct |
|---|---|---|---|---|
| XCOM: Enemy Unknown (2012) | Money plus components (Alien Alloys, Weapon Fragments, Elerium). Engineer headcount is also a gate. | Higher tier needs more components. Example: Laser Rifle 12 engineers + 8 alloys; Mind Shield 15 engineers + 18 Elerium + 6 alloys. | Two lists. Engineering builds new items. Foundry improves existing ones. The guide says they follow different rules. A finished Foundry upgrade replaces the old version. | Components come only from missions. Money cannot buy them. |
| XCOM 2 (Proving Ground, Engineering) | Supplies (the generic currency) plus Alien Alloy, Elerium Crystal, and Elerium Core. | 35 Supplies early; 50 to 75 Supplies mid; late suits need 10 Alloy + 5 Crystal + 1 Core. In one table, 14 of 18 projects need exactly one Core. | Projects (new items) and upgrades are separate. | The Core is rare, found only as a mission reward or drop. It gates the item, so Supplies cannot replace it. |
| Gears Tactics | Sources found describe upgrades as FOUND in mission cases, sorted by rarity. They show no purchase price. | Rarity tiers exist. | Upgrades are applied in the Barracks. | Not applicable. |
| Fire Emblem: Three Houses (Blacksmith) | Gold plus Smithing Stones. | Higher weapon, higher gold and stones. Example from one guide: Iron Sword+ 310 gold + 6 stones. | Forge (improve) and repair are priced differently. Repair is cheaper in the one guide that lists both. | Stones are an item input, not a price. Gold alone cannot forge. |
| Battle Brothers | Crowns plus Tools (a consumable item). Repair costs Tools. | Tool count scales with the armor. About 1 crown per durability point in one forum report. | Repair only (no upgrade) in the sources found. | Tools are an item that crowns buy, so the item sits between money and the repair. |

Patterns that matter to us:
1. Two currencies is normal. A third thing (a rare input item) is what makes a high tier hard. This matches GDD 19.6 "item + Ekwan + Ase".
2. A generic money plus a component stays distinct when money cannot buy the component. Our rule D-125 does the same: an item is never a currency.
3. Cost grows by tier through explicit per-tier values in the lists found, not through a published formula.
4. Make and upgrade are priced as separate things in XCOM (2012) and Fire Emblem. An upgrade consumes or replaces an existing item.
5. XCOM 2012 also discounts price with workshop and engineer count. This is a price that falls with use. We do NOT adopt it in Part B (section 7).

Could not confirm:
- Any Gears Tactics purchase price. The sources found show none. Treat as "no craft cost" until a better source exists.
- Exact XCOM 2012 cost tables. Sources disagree by version.
- Battle Brothers ammunition prices in the base game. Only a mod listed them.
- Whether Fire Emblem stones relate to gold by a fixed ratio. The Fire Emblem wiki page does not say.
- XCOM 1 versus XCOM 2012: this research covers XCOM: Enemy Unknown (2012) and XCOM 2. The 1994 game was not researched.

Sources:
- https://www.gamepressure.com/xcomenemyunknown/production-and-improvement-of-equipment/ze4226
- https://www.gamepressure.com/xcom2/projects-proving-ground/z38551
- https://www.gamesradar.com/xcom-enemy-unknown-research-and-engineering-guide (search result only, not opened)
- https://www.gameshedge.com/gears-tactics-weapons-and-armor-upgrade-guide/
- https://samurai-gamers.com/fire-emblem-three-houses/forging-guide/ (search result only, not opened)
- https://www.fireemblemwiki.org/wiki/Smithing_Stone
- https://steamcommunity.com/app/365360/discussions/0/2951503378093616777 (Battle Brothers forum, search result only)

### Notes for ECONOMY-003 (display)

How those games SHOW a price. Not part of the Part B contract.
1. XCOM 2012 Engineering lists price, minimum staff, and required components in stock on one row. The Foundry list looks like a research screen.
2. XCOM 2 shows each cost resource as its own icon and count.
3. Battle Brothers shows the Tool count on hover once the item is set for repair.
4. The input item is shown next to the currency price, not inside it.
5. A recipe the player cannot afford stays visible. The short resource is the thing to mark, not the whole row.

## 2. Recipe record contract (JOB 2)

### 2.1 Location and shape

`data.inventory.recipes` is a Dictionary keyed by OUTPUT `type_id`. Each value is a Dictionary keyed by GRADE KEY. Each value of that is a "route" Dictionary with up to two optional sub-records: `make` and `upgrade`. Both sub-records share one shape, the "price record".

```
recipes: {
  "<output type_id>": {
    "<grade key>": {
      "make":    { price record },
      "upgrade": { price record }
    }
  }
}

price record: {
  "inputs": [ { "type_id": String, "count": int }, ... ],
  "cost":   { "ekwan": int, "ase": int }
}
```

Example (fixture style, placeholder ids only; the numbers are zero because this round sets no price):

```
"ph_weapon_a": {
  "g1": {
    "make":    { "inputs": [ { "type_id": "ph_material_a", "count": 2 } ],
                 "cost": { "ekwan": 0, "ase": 0 } }
  },
  "g2": {
    "make":    { "inputs": [ { "type_id": "ph_material_a", "count": 4 } ],
                 "cost": { "ekwan": 0, "ase": 0 } },
    "upgrade": { "inputs": [ { "type_id": "ph_weapon_a", "count": 1 },
                             { "type_id": "ph_material_a", "count": 1 } ],
                 "cost": { "ekwan": 0, "ase": 0 } }
  }
}
```

The fixture file `tests/fixtures/recipe_placeholders.json` must carry a case with non-zero costs, so the afford check is testable. Those numbers are test numbers and are not a price proposal.

### 2.2 Field rules

| Field | Type | Required | Rule |
|---|---|---|---|
| output key (`type_id`) | String | yes | Must exist in `data.inventory.definitions`. |
| grade key | String | yes | A grade in `data.inventory.grades`, or the key `ungraded` for a type whose definition grade is `""` (consumable, material). |
| `make` / `upgrade` | Dictionary | at least one per grade key | An empty route (neither) is invalid. |
| `inputs` | Array | yes (may be empty) | Each entry `{ type_id: String, count: int >= 1 }`. `type_id` must exist in definitions. No duplicate `type_id` in one record. |
| `cost` | Dictionary | yes | Exactly the keys `ekwan` and `ase`. A missing key is NOT zero (section 4, edge 4). |
| `cost.ekwan`, `cost.ase` | whole number >= 0 | yes | See section 4, edge 5. |

### 2.3 How a grade is keyed, and what a missing grade means

1. The grade key is a plain string from `data.inventory.grades` (ITEM-005 owns the ladder). Part B does not fix any grade name.
2. A grade key that is not in `grades` (and not `ungraded`) is a validation error.
3. A missing grade key means: this type cannot be made at that grade. It is NOT free and NOT inherited from a lower grade. The afford check returns `unknown_recipe`.
4. The definition holds one `grade` today (`data.inventory.definitions`, `_definitions_comment`). Whether a recipe grade key must equal that field is an ITEM-005 question. Part B checks only that the key is on the ladder.

### 2.4 Make versus upgrade: one shape, two sub-records

Decision: two sub-records under one grade key, one shared price record shape.

Reasons:
1. The two games with an upgrade path (XCOM 2012, Fire Emblem) price make and upgrade separately. An upgrade is normally cheaper than a new make, because the player already holds the base item.
2. One shape means one validator and one afford check. A flag on one record would hide that an upgrade also needs a base item.
3. The base item of an upgrade is an ordinary `inputs` entry (for example `ph_weapon_a` count 1). No second mechanism exists. ECONOMY-003 decides which held item is consumed.
4. Validator rule for `upgrade`: `inputs` must hold at least one item whose definition `kind` is `gear` or `relic`. This stops a record that calls itself an upgrade but has no base.

Part B builds the check and the pay method for a price record. It does not need to know if the record came from `make` or `upgrade`. The caller picks the route.

### 2.5 The reserved `cost` on an item definition

1. Part B REMOVES it (D-137, Jeff, 2026-11-09). This supersedes the earlier line "it stays reserved" (D-124). Part B removes the field and its comment text from `data/balance.json` (`_definitions_comment`) and from `tests/fixtures/inventory_placeholders.json`, and fixes the tests that name it (`inventory_service/item_definition_cost_is_read_by_nothing` is rewritten or deleted). ANSWERS #88 allows the removal with no bridge.
2. The recipe price record is the ONLY price the pay method reads.
3. A flat price on a non-crafted route (for example a future Sanctum offer) gets its own field when a story owns that route.
4. A price must never be read as a sell value or a worth. An item is never a currency (D-125).
5. Part B adds a note about the removal to `docs/stories/v2-item-001/basis-for-001b-and-later.md`, the note for ITEM-001b.

### 2.6 Currency meaning

1. Ekwan = matter and build capacity. The Ekwan part of a price is the cost of the thing existing.
2. Ase = shaping and attunement. The Ase part is the cost of the thing being made right and bound to the house.
3. Neither currency is derived from the other. No conversion between them exists in the contract.
4. Recycle (ITEM-004) returns Ekwan only. That key stays `recycle_yield_ekwan` (D-126).

### 2.7 Validation rules

A validator checks the whole `recipes` block. It runs in a data test over the shipping block and over the fixture. It also runs for one record at lookup time (defence for a bad fixture).

1. `recipes` is a Dictionary. Empty is valid (shipping today).
2. Every output key exists in `definitions`.
3. Every grade key is on the ladder or is `ungraded`.
4. Every route has `make`, `upgrade`, or both.
5. Every price record has `inputs` (Array) and `cost` (Dictionary with exactly `ekwan` and `ase`).
6. Every `cost` value is a whole number >= 0 (section 4).
7. Every `inputs` entry has an existing `type_id` and `count` >= 1; no duplicate `type_id`.
8. An `upgrade` record has a `gear` or `relic` input (section 2.4).
9. No placeholder id (`ph_*`) appears in `data/balance.json` (D-131). The shipping data test enforces this.
10. Shipping warning, not error: a record whose `ekwan` and `ase` are both 0 (D-04: a free make breaks "hard to earn").

## 3. Pillar check and the base for a later price proposal

### 3.1 Design pressure answers

| Question | Answer |
|---|---|
| Legible without an ID or raw number? | Not applicable in Part B. ECONOMY-003 must show the price as two currency counts with an input item. No `type_id` shows. |
| Survives a player who never reads it? | Yes. Part B has no player-facing element. A player who never crafts loses nothing. |
| Decision or delay? | Decision, by design: Ekwan and Ase both have other uses (section 3.2), so spending on an item means not spending elsewhere. Part B adds no timer. |
| Interacts with fear and emotion? | No. Making an item is a Keeper action. This is correct for Part B. Echo interior life is untouched. |
| Standing 1 / 6 / 9? | Standing 1: shipping `recipes` is empty, so nothing is lost. Standing 6 and 9: unlock gating by Standing is an ECONOMY-003 or ITEM-002 question, not Part B. |

### 3.2 Existing income and sinks (from the repo)

Numbers below come from `data/balance.json` and `core/`. They are the base for the later price proposal by `mid-game-designer`. This document proposes no price.

Ase income:
| Source | Value | Where |
|---|---|---|
| Objective payout, by type | pursue 16, combat 20, recover 24, protect 24, endure 28, shrine 30, guide_spirit 32, boss 0 | `data.rewards.objective_weights` |
| Won normal fight | 6 | `data.rewards.encounter_weights.fight` |
| Echoes stipend | 2 per Echo home, cap 10 (replay cap 5) | `data.rewards.echo_home_*` |
| Scale and factors | realm scale step 0.25 per realm; replay factor 0.35; defeat factor 0.25 | `data.rewards` |
| Online and offline accrual | 0.3 per minute online base; offline is capped and tapers (GDD 19.2) | `data.economy` |
| One-time | awakening grant 40; first trial reward 40 | `data.economy`, `data.keeper_intro` |

Ekwan income:
| Source | Value | Where |
|---|---|---|
| Objective payout, by type (only source, ANSWERS #84) | pursue 2, combat 2, protect 3, guide_spirit 3, endure 4, recover 5, shrine 6, boss 0 | `data.rewards.objective_ekwan` |
| Scale and factors | same realm scale and replay factor as Ase | `data.rewards` |

Ase sinks:
| Sink | Value | Where |
|---|---|---|
| Summon | 60 to 430 by Echo number, flat from Echo 14 | `data.summoning.price_by_echo_number` |
| Skill unlock | 60 each (14 skills) | `unlock_conditions.ase_cost` |
| Retreat | 10 | `data.encounter` area, `retreat_ase_cost` |
| Institution assign | 5 | `data.institutions.*.assign_ase_cost` |
| Vow break | 60 / 120 / 250 / 500 by level | `vows.*.breaking_costs` |

Ekwan sinks:
| Sink | Value | Where |
|---|---|---|
| Establish institution | Hearth 10; Training Grounds 15 | `establish_ekwan_cost` |
| Remove an Echo from an institution | 3 | `unassign_ekwan_cost` |
| Vow break | 0 / 20 / 50 / 100 by level (level 1 has none) | `breaking_costs` |

Findings for the price proposal (facts, not prices):
1. Ekwan income per objective is 2 to 6. Its sinks today are 3 to 100. Ekwan has few sinks and little income, so an item price in Ekwan is a multi-path saving goal.
2. Ase has many sinks and larger income. D-04 says Ase overflows. An Ase price on an item can act as a sink, but must not just drain the overflow without a choice.
3. Ase and Ekwan scale by the same realm scale and replay factor. A price is flat. Later realms therefore make a fixed price cheaper. The price proposal must decide if prices scale with realm. This is a question for `mid-game-designer`.

Intent for the price proposal (PROPOSED DEFAULT, for `mid-game-designer` to author):
1. A grade-1 make should cost about one to two normal paths of Ekwan income (PROPOSED DEFAULT range).
2. An upgrade should cost less than a make of the same grade (PROPOSED DEFAULT: yes, shape only).
3. Test every price against D-04: "does a player at Standing 1 with typical income have to give something up?"

## 4. Edge cases for the builder (JOB 3)

Reason keys: `ok`, `short_ase`, `short_ekwan`, `short_both`, `unknown_recipe`, `bad_cost`.

Check order (first match wins):
1. Lookup fails: `unknown_recipe`.
2. Price record fails validation: `bad_cost`.
3. Compare each currency with a cost above 0 against the balance:
   - both short: `short_both`
   - only Ase short: `short_ase`
   - only Ekwan short: `short_ekwan`
   - neither short: `ok`

The afford check changes nothing. The pay method calls the afford check first, then spends. If the key is not `ok`, nothing is spent (D-132).

| # | Case | Required behaviour | Key | Reason |
|---|---|---|---|---|
| 1 | Cost is 0 in one currency | Valid. That currency is never short. The pay method skips the spend call for that side. | `ok`, or a `short_*` for the other side | `EconomyService.spend_ase` and `spend_ekwan` return false and log a denied line for any amount <= 0 (`core/economy/EconomyService.gd` lines 64 to 70 and 306 to 312). A zero side that calls them would look like a failed payment. |
| 2 | Both costs are 0 | Valid in core. Check returns `ok`. Pay spends nothing and writes one log line. The shipping data test warns (rule 10). | `ok` | The fixture uses 0 today. Core must not decide that free is wrong; data review does (D-04). |
| 3 | Output type does not exist | No record, or a record whose type is not in `definitions` (or an input type not in `definitions`): never pay, never crash. The data test fails on the bad record. | `unknown_recipe` | A missing recipe and a broken recipe both mean "cannot make this". |
| 4 | A grade has no price | Missing grade key: `unknown_recipe`. Never inherit a neighbour grade. Never treat as free. `cost` present but a currency key missing: `bad_cost`, not 0. | `unknown_recipe` or `bad_cost` | A silent free item breaks D-04. A missing number is a data fault. |
| 5 | A cost that is not a whole non-negative integer | Reject: negative, fraction (5.5), string, bool, null, NaN, infinity. | `bad_cost` | A price must be exact. See note below. |

Note for edge 5: Godot parses every JSON number as a float. `balance.json` shows `40.0` and `10` side by side, and existing code reads costs with `int(...)` (`InstitutionService.gd` line 154). The validator must therefore ACCEPT a float with no fractional part (for example `10.0`) and convert it to int once. It must REJECT `10.5`. Confirm the parse behaviour with `mechanics-developer` (ASSUMED below).

Further rules:
1. Afford and pay never read the `inputs` list in Part B. The held-item check and the item consumption belong to ECONOMY-003. A key `short_items` is reserved for that story and Part B never returns it.
2. `inputs` and `cost` are never merged. An input item has no Ase or Ekwan worth (D-125).
3. The pay log line carries the output `type_id`, the route (`make` or `upgrade`), and both amounts. Reason string follows the existing form (for example `craft.<route>.<type_id>`; the exact string is a builder choice, ANSWERS #83 applies to numbers only).
4. Hold, move and destroy stay free. Destroy returns nothing (D-126).

## 5. Seams

| Existing piece | How Part B touches it |
|---|---|
| `EconomyService` | New "pay both" method (D-132). Reads `get_ase`, `get_ekwan`; calls `spend_ase`, `spend_ekwan` only for a cost above 0. Existing methods unchanged. |
| `data.inventory` | New `recipes` block, empty in shipping. `definitions.cost` is removed (D-137). |
| `InventoryService` | No change. Items in the packs keep `ase` 0 and `ekwan` 0 (D-125). |
| `EarningsService` and the packs | No change. |
| Save and snapshot | No new save field, no new snapshot field. Part B stores no state. |
| ECONOMY-003 | Reads the same record. Adds the held-item check, the consume step, the screen and the text. |
| ITEM-002 / ITEM-005 | ITEM-002 fills `recipes` with real items. ITEM-005 fixes the grade ladder and the grade-versus-definition question. |
| ITEM-004 | Recycle and `recycle_yield_ekwan`. |

## 6. Failure modes

1. Player ignores it: nothing happens. Shipping `recipes` is empty.
2. Player exploits it: no loop exists. Pay is atomic (both currencies or none) and the packs hold no currency value for an item (D-125), so an item cannot be turned back into currency in Part B.
3. Standing 1: no recipe exists. Nothing is blocked.
4. Partial spend: if the second spend call failed after the first succeeded, currency would vanish. The pay method must check both balances first (D-132) so this cannot happen.
5. A placeholder id in shipping data: rule 9 fails the data test.

## 7. Explicit deferrals

| Item | Goes to |
|---|---|
| Crafting action, held-item check, item consume, `short_items` | V2-ECONOMY-003 |
| Price display, cannot-afford state and text, pay feedback, mockups | V2-ECONOMY-003 (D-133) |
| Real items and real prices | V2-ITEM-002, then `mid-game-designer` price proposal (D-127) |
| Grade ladder, grade-versus-definition link | V2-ITEM-005 |
| Recycle yield | V2-ITEM-004 |
| Price that changes with realm, with use, or with a building (as in XCOM 2012 workshops) | Not designed. A new decision from Jeff is needed. |
| Standing gate on a recipe | ECONOMY-003 or ITEM-002 |
| Deleting the reserved definition `cost` | DONE in Part B (D-137). Not deferred. |

Game-feel agent: NOT needed for this contract. It changes nothing the player feels. It contains no price that rises with use and no feedback. A game-feel dispatch becomes right in ECONOMY-003 (pay feedback) or if a price that changes with use is added later.

## OPEN — questions and assumptions
ASSUMED: The key `ungraded` marks recipes for types whose definition grade is `""` | WHY: JSON allows an empty key, but it is easy to lose in a diff | WRONG IF: ITEM-005 gives every type a grade, so no ungraded type exists
ASSUMED: Godot parses every JSON number as a float, so the validator accepts `10.0` and rejects `10.5` | WHY: `balance.json` mixes `40.0` and `10`, and existing code reads costs with `int(...)` | WRONG IF: `mechanics-developer` finds the loader keeps ints as ints (the rule still holds, it is only simpler)
ASSUMED: Part B checks that a recipe grade key is on the ladder, not that it equals the definition `grade` | WHY: `data.inventory.grades` is `[]` and ITEM-005 owns the ladder | WRONG IF: ITEM-005 decides grade is per instance, not per definition (then the key meaning changes)
ASSUMED: An upgrade lists its base item as an ordinary input | WHY: one mechanism, one validator | WRONG IF: ECONOMY-003 needs the upgraded item to keep its own state (history, name), which a consume-and-make step would lose
ASSUMED: The shipping data test only WARNS on a both-zero price | WHY: the fixture uses zero and core should not judge price | WRONG IF: Jeff wants a free make to fail the build
ASSUMED: Nothing about Standing gates a recipe in Part B | WHY: no GDD text in 19.2, 19.5, 19.6, 19.10 or 21.1 sets one | WRONG IF: Jeff wants a Standing gate in the record shape now
ANSWERED (Jeff, 2026-11-09, D-137): the reserved `definitions[type].cost` is removed in Part B, not at ITEM-002.
BLOCKED: Should a fixed price scale with realm like the income does (income gets +0.25 per realm, a flat price gets cheaper)? | CHECKED: `data.rewards.realm_scale_step`, D-63 | NEED: `mid-game-designer` price proposal and Jeff's choice (not a Part B shape question, but the record would need one more field if yes)
BLOCKED: Gears Tactics purchase cost | CHECKED: two web searches and two page fetches | NEED: a Gears Tactics wiki or play session; or drop it as a reference
