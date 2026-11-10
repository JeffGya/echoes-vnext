# V2-ECONOMY-004 Part B: placeholder price proposal

Author: mid-game-designer. Date: 2026-11-09. Written in STE.
Every number in this file is a PROPOSAL. Jeff sets the final numbers (D-127).
Nothing is in `data/balance.json`. The prices go in `tests/fixtures/recipe_placeholders.json` only (D-131).
Tags: READ = from a file I opened. COMPUTED = my arithmetic. ASSUMED = not verified.
Binding: D-04 (rewards must feel hard to earn), D-124 (cost = `{ ekwan, ase }` plus item inputs), D-125 (an item is never a currency), GDD 19.6 (Ekwan pays material and build cost; Ase pays shaping and attunement).

## 1. Income and sinks (from the repo)

Unit used below: 1 "path" = one path of the first realm (`realm.01`), first run, party of 5.

### 1.1 Income per path

| Path type | Ase per path | Ekwan per path | Basis |
|---|---|---|---|
| First realm (`realm.01`), first run | 44 | 3.6 | COMPUTED. `phase7-encounter-pay-design.md` section 2.2 (objectives 24.9 + fights 4.5 + found 4.5 + stipend 10 = 43.9). Ekwan: mean of `objective_ekwan` = 25/7 = 3.57, 1 objective per path. |
| Second realm (`realm.02`), first run | 69 | 6.7 | COMPUTED. Same file, section 2.2 (69.2). Ekwan: 1.5 objectives x 3.57 x 1.25. |
| Third realm | 81 | 8.0 | COMPUTED. Scale 1.50. ASSUMED path shape = `realm.02`. |
| Fourth realm | 105 | 10.7 | COMPUTED. Scale 2.00. Same assumption. |
| Replay of `realm.01` | 20 | 1.25 | COMPUTED. Same file, section 2.2. Replay factor 0.35; stipend cap 5. |
| Whole `realm.01` (3 to 4 paths, mean 3.5) | about 154 | about 12.5 | COMPUTED. `data/realms.json` `stage_count_min` 3, `stage_count_max` 4. |

Config behind the table:

| Value | Where |
|---|---|
| Objective Ase: pursue 16, combat 20, recover 24, protect 24, endure 28, shrine 30, guide_spirit 32, boss 0 | `data/balance.json:1548` |
| Objective Ekwan: pursue 2, combat 2, protect 3, guide_spirit 3, endure 4, recover 5, shrine 6, boss 0 (only Ekwan source, ANSWERS #84) | `data/balance.json:1559` |
| Won normal fight: 6 Ase, no Ekwan | `data/balance.json:1570` |
| Stipend: 2 Ase per Echo home, cap 10 (replay cap 5), not scaled | `data/balance.json:1576-1578` |
| Realm scale step 0.25; replay factor 0.35 | `data/balance.json:1582-1584` |
| Good Claimant contact: 20 Ase | `data/balance.json:1611` |
| Online accrual 0.3 Ase per minute; first trial 40 Ase once | `data/balance.json:79`, `data/balance.json:96` |

Ekwan grows faster than Ase from realm to realm. Reason: the scale applies to objectives only, and the stipend (10 Ase) does not scale. From `realm.01` to `realm.02`, Ase grows x1.57 and Ekwan grows x1.87.

### 1.2 Sinks

| Currency | Sink | Price | Where |
|---|---|---|---|
| Ase | Summon an Echo (uncalled) | Echo 2 and 3: 60; 4: 70; 5: 85; 6: 100; 7: 120; 8: 145; 9: 175; 10: 210; 11: 250; 12: 300; 13: 360; 14 and up: 430 | `data/balance.json:103-117` |
| Ase | Called / chosen summon extra | +90 / +340 over the uncalled price | `data/balance.json:119-120` |
| Ase | Unlock a skill (14 skills) | 60 each | `data/balance.json:2582` (first of 14) |
| Ase | Retreat before round 1 | 10 | `data/balance.json:1912` |
| Ase | Assign an Echo to an institution | 5 | `data/balance.json:3116` |
| Ase | Break a vow, level 1 / 2 / 3 / 4 | 60 / 120 / 250 / 500 | `data/balance.json:2901` onward |
| Ekwan | Establish Hearth / Training Grounds | 10 / 15 | `data/balance.json:3115`, `data/balance.json:3128` |
| Ekwan | Remove an Echo from an institution | 3 | `data/balance.json:3117` |
| Ekwan | Break a vow, level 2 / 3 / 4 | 20 / 50 / 100 | `data/balance.json:2901` onward |

Note: D-61 plans a skill price of 60 / 90 / 120 by Standing. The balance file shows 60 for all 14 skills today. I use 60.

Facts that drive the proposal:
1. Ekwan has few sinks. Both institutions cost 25 Ekwan in total. That is about 7 paths of income.
2. Ase has many sinks and overflows (D-04). An item price in Ase is the sink D-04 expects from Part B.
3. Summon and skill prices do not change with the realm. Income does.

## 2. Price proposals

Unit: "paths" = price divided by the first-realm income of section 1.1 (44 Ase, 3.6 Ekwan). All numbers are PROPOSAL.
Inputs are the item cost from D-124. They carry the "matter" of the item, so the Ekwan part can stay small on attuned items.

| # | Recipe (fixture id) | Inputs | Ekwan low / mid / high | Ekwan in paths | Ase low / mid / high | Ase in paths |
|---|---|---|---|---|---|---|
| 1 | `ph_weapon_a` g1 make | `ph_material_a` x2 | 4 / 7 / 11 | 1.1 / 1.9 / 3.1 | 15 / 25 / 40 | 0.3 / 0.6 / 0.9 |
| 2 | `ph_weapon_a` g2 make | `ph_material_a` x4 | 8 / 14 / 20 | 2.2 / 3.9 / 5.6 | 25 / 45 / 70 | 0.6 / 1.0 / 1.6 |
| 3 | `ph_weapon_a` g2 upgrade | `ph_weapon_a` x1, `ph_material_a` x1 | 5 / 10 / 14 | 1.4 / 2.8 / 3.9 | 16 / 32 / 48 | 0.4 / 0.7 / 1.1 |
| 4 | `ph_charm_a` g1 make | `ph_material_a` x1 | 2 / 3 / 5 | 0.6 / 0.8 / 1.4 | 30 / 45 / 60 | 0.7 / 1.0 / 1.4 |
| 5 | `ph_relic_a` g2 make | `ph_material_a` x2 | 3 / 5 / 8 | 0.8 / 1.4 / 2.2 | 55 / 80 / 115 | 1.3 / 1.8 / 2.6 |
| 6 | `ph_consumable_a` ungraded make | `ph_material_a` x1 | 1 / 2 / 3 | 0.3 / 0.6 / 0.8 | 6 / 10 / 15 | 0.1 / 0.2 / 0.3 |

Not priced: `ph_armor_a`. Suggested copy of row 1 with Ekwan about 20% higher (armor is material-heavy). It adds no new test.

Design rules I used (each rule is also a check for Jeff):

| Rule | Check on the table |
|---|---|
| Material-heavy items: Ekwan is the heavier price in paths. | Rows 1, 2, 3, 6: Ekwan paths exceed Ase paths in every column. |
| Attuned items (charm, relic): Ase is the heavier price in paths. | Rows 4, 5: Ase paths exceed Ekwan paths in every column. Reason: one path pays 12 times more Ase than Ekwan. A heavy Ase price needs a large Ase number. |
| A grade-1 make costs about 1 to 2 paths of Ekwan at the middle (contract section 3.2 intent). | Row 1 mid: 1.9 paths. Row 4 mid: 0.8 path. Row 4 is lower on purpose; the charm is an Ase item. |
| An upgrade costs less than a make of the same grade. | Row 3 is about 70% of row 2 in all three columns. |
| No shortcut: base make + upgrade is not cheaper than a direct make of the higher grade. | Row 1 + row 3 = Ekwan 9 / 17 / 25 and Ase 31 / 57 / 88. Row 2 = 8 / 14 / 20 and 25 / 45 / 70. Row 1 + row 3 is higher in every column. |
| A higher grade costs more. | Row 2 above row 1; row 5 above row 4. |
| A make is never free (D-04, D-138). | Smallest value in the table is 1 Ekwan and 6 Ase. |

Why the middle value is the one to start with: it makes the player pick. At the start of `realm.01`, after 3 paths the player holds about 11 Ekwan and 130 Ase. Hearth (10 Ekwan) and one weapon (7 Ekwan) compete for the same Ekwan. A summon (60 Ase) and a charm (45 Ase) compete for the same Ase.

## 3. Check against the other sinks

| Other sink | Risk | Result |
|---|---|---|
| Summon, 60 to 430 Ase | An item that costs more Ase than the next Echo makes the Echo cheaper than gear. That reverses the pillar (people before things). | Every g1 item is at or under 60 Ase in all columns. The charm high value is 60 and equals the cheapest summon. Rows 2 and 5 (g2) exceed 60 at the high value (70, 115). That is intended: a g2 item is a late luxury. Relic high (115) is near the Echo 7 price (120). Jeff may cap row 5 high at 100. |
| Summon, delay effect | A player who buys a full set delays the next Echo. | Weapon + charm + relic at the middle value = 150 Ase = 3.4 paths. The next Echo costs 1.4 to 2.3 paths of income. The player must choose. That is the intended choice (D-04), not a sink that breaks cadence. |
| Skill unlock, 60 Ase | A cheap item makes a skill pointless. | No item at the middle value is below 10 Ase except the consumable. Skills are permanent growth for an Echo. Items at 25 to 80 Ase do not replace them. Pass. |
| Institutions, 10 / 15 Ekwan | Items cost less Ekwan than an institution and drain Ekwan first. | Row 1 mid (7) is below Hearth (10). Both compete. Hearth stays attractive because it is permanent. Warning: if Ekwan items stay under 7, the 25 Ekwan of both institutions is the only thing the player saves for. Rows 2 and 3 (14 and 10) are above Hearth. Pass, with a measure in section 6. |
| Retreat, 10 Ase | A consumable cheaper than a retreat makes the retreat pointless if the consumable does the same job. | Row 6 low (6) is below 10. The consumable effect is not designed yet. Keep row 6 mid at 10 or higher until ITEM-002 defines the effect. FLAG for ITEM-002. |
| Assign (5 Ase) and remove (3 Ekwan) | None. | The smallest item price (1 Ekwan, 6 Ase) is near these. They are small service fees. Pass. |
| Vow break, 60 to 500 Ase | A relic at 115 Ase is near the level 2 vow break (120). | The two have different meaning. No dominance. Pass. |
| Replay | Replay income is 20 Ase and 1.25 Ekwan. | Row 1 mid costs 5.6 replay paths of Ekwan. Replay is a poor way to earn items. This is consistent with D-04 and with the replay factor (D-54). |

## 4. Should a fixed price scale with the realm? (question from the contract)

Income per path by realm (section 1.1), rounded: Ase 44 / 69 / 81 / 105. Ekwan 3.6 / 6.7 / 8.0 / 10.7.
Both options below use row 1 mid (7 Ekwan, 25 Ase) and row 5 mid (5 Ekwan, 80 Ase). COMPUTED.

Option A: the price stays fixed (flat).

| Item | Realm 1 | Realm 2 | Realm 3 | Realm 4 |
|---|---|---|---|---|
| Row 1 Ekwan, price 7, paths | 1.9 | 1.0 | 0.9 | 0.7 |
| Row 1 Ase, price 25, paths | 0.6 | 0.4 | 0.3 | 0.2 |
| Row 5 Ekwan, price 5, paths | 1.4 | 0.7 | 0.6 | 0.5 |
| Row 5 Ase, price 80, paths | 1.8 | 1.2 | 1.0 | 0.8 |

Option B: the price scales with the same rule as income (x1.00 / 1.25 / 1.50 / 1.75, rounded to a whole number).

| Item | Realm 1 | Realm 2 | Realm 3 | Realm 4 |
|---|---|---|---|---|
| Row 1 Ekwan, price 7 / 9 / 11 / 12, paths | 1.9 | 1.3 | 1.4 | 1.1 |
| Row 1 Ase, price 25 / 31 / 38 / 44, paths | 0.6 | 0.5 | 0.5 | 0.4 |
| Row 5 Ekwan, price 5 / 6 / 8 / 9, paths | 1.4 | 0.9 | 1.0 | 0.8 |
| Row 5 Ase, price 80 / 100 / 120 / 140, paths | 1.8 | 1.4 | 1.5 | 1.3 |

Facts:
1. Under option A, a g1 weapon costs about one path of Ekwan by realm 2 and under one path by realm 3. D-04 weakens.
2. Under option B, the cost stays near 1 to 1.4 paths. The 0.25 step undercorrects, because Ekwan income grows x1.87 in realm 2. A scale that holds the Ekwan paths constant would need x1.9 / x2.2 / x3.0 for realms 2 to 4. That is far above the 0.25 step.
3. Option B needs a new rule: which realm sets the price (current realm, or highest realm reached). It also needs one more field on the record (contract OPEN block, last BLOCKED line). A price that depends on the highest realm reached punishes a player who replays an early realm.
4. The research table (contract section 1) shows XCOM and Fire Emblem use explicit values per tier. No source shows a price that scales with the map.
5. The grade ladder (ITEM-005) is the natural climb. A later-realm player makes g2 and g3 items, which carry higher prices (rows 2 and 5 already show this).
6. Summon and skill prices also stay flat by realm. Option A is consistent with them.

Recommendation: option A (flat price), with the climb carried by the grade. Jeff decides.
Conditions for the recommendation:
1. A measurement shows that late-realm items stay a real choice. If a g1 make drops below 0.7 path of Ekwan at realm 3, raise the g2 and g3 prices instead of adding a realm field.
2. If Jeff wants a realm-linked price anyway, use option B with a step larger than 0.25 and a clear "highest realm reached" rule. That decision belongs to a new story, not to Part B.

## 5. Where these numbers go

1. `tests/fixtures/recipe_placeholders.json` only (D-131). The shipping `data.inventory.recipes` block stays empty.
2. Use the middle column for the main afford-check test. Use the low and high columns for edge tests, for example "short Ekwan only" and "short both".
3. The low and high columns are a range for Jeff to choose from. The fixture needs one value each.
4. Real items and real prices come with ITEM-002. These values do not carry over unchanged.

## 6. Measurements for qa-verifier or the main chat (not run here)

| Check | Why |
|---|---|
| Real Ekwan per path on generated `realm.01` and `realm.02` (objectives per path, visit share 0.75) | The income column is COMPUTED from the generator, not run (`phase7-encounter-pay-design.md:24-36`). The Ekwan unit (3.6) drives every "paths" number. |
| Paths to the first Hearth and first g1 weapon in a played run | Confirms the Hearth versus weapon choice in section 3. |

## OPEN — questions and assumptions
ASSUMED: One path of `realm.01` pays 44 Ase and 3.6 Ekwan (party of 5, first run, visit share 0.75). | WHY: It is the COMPUTED figure in `phase7-encounter-pay-design.md` section 2.2 and the mean of `objective_ekwan`. Nobody has measured it. | WRONG IF: The probe at step 7.0 of that file finds a different visit share or objective count. Every "paths" number then shifts.
ASSUMED: Realms 3 and 4 have the same path shape as `realm.02` (1.5 objectives, 6.5 situations). | WHY: `data/realms.json` has no entry for them. | WRONG IF: A later realm uses a different stage or objective count. The option A and B tables for realms 3 and 4 change.
ASSUMED: "Heavier" on an attuned item means more paths of income, not a larger raw number. | WHY: Raw numbers always favour Ase (12 times the income). | WRONG IF: Jeff wants the raw number rule. Then rows 1 to 3 would also need Ase above Ekwan, and the Ekwan-heavy rule fails.
ASSUMED: An upgrade consumes its base item (listed in `inputs`), as the contract assumes. | WHY: Contract section 2.4. The no-shortcut check in section 2 depends on it. | WRONG IF: ECONOMY-003 keeps the base item. Then an upgrade could cost less than shown.
ASSUMED: Skill unlock stays 60 Ase for all 14 skills. | WHY: `data/balance.json:2582` and the 13 lines after it show 60 for each skill. | WRONG IF: D-61 (60 / 90 / 120 by Standing) is built later. Skills then cost more and the check in section 3 gets easier.
BLOCKED: Does a fixed price scale with the realm? | CHECKED: `data.rewards.realm_scale_step`, D-55, D-63, contract OPEN block, research in contract section 1. | NEED: Jeff's choice between option A and option B (section 4). I recommend A.
BLOCKED: What does the consumable do, and is it a rival to the 10 Ase retreat? | CHECKED: `tests/fixtures/inventory_placeholders.json`, `data.inventory.definitions`. The placeholder has no effect. | NEED: ITEM-002 defines the consumable. Then re-check row 6.
