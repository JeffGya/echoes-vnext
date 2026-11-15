# V2-ITEM-001b: pick-rule numbers (record of D-12)

Written in STE. These are the numbers Jeff approved as D-12 on 2026-11-10 (proposal by `mid-game-designer`, shown in full in the chat). They are PROPOSED DEFAULTS: they are tuned after the rate probe (D-09, LESSONS #38). Backend step C4 reads them into `data/balance.json` under `data.inventory.pick`. This file is the record until then.

Jeff approved the agent's assumptions A to E together with the numbers (D-12):
- A: tables are keyed by Calling id (6 rows), not by family.
- B: six stats (max_hp, atk, def, agi, int, cha); speed is left out.
- C: the vector sum and the trait sum are scaled by Judgment through `maturity_expression.identity_weight_scale` (trait 0.35, vector 0.35), as combat does. Calling, archetype and stat terms are not scaled.
- D: `afraid_pick_signature` sits in `maturity_expression.calling_behavior.<calling>`, beside `afraid_signature`.
- E: `freeze_at` compares with the curved, composure-softened afraid value (`EmotionStatusLean.curved_afraid`, then composure), not with raw fear.

Column order in every table: gear, relic, consumable, material. Every row sums to 0 across the four kinds, so no Calling, archetype or trait is greedy for all kinds.

## Appeal rule
```
identity = calling_pick[calling][kind]
         + sum(vector_score[v] * vector_pick_muls[v][kind])    (scaled by 1 + J * identity_weight_scale.vector)
         + sum(trait[t]        * trait_pick_muls[t][kind])     (scaled by 1 + J * identity_weight_scale.trait)
         + sum(stat[s]         * stat_pick_muls[s][kind])
         + archetype_pick[archetype_birth][kind]
sense    = worth * worth_weight * (sense_base + (1 - sense_base) * J)
worth    = kind_weight[kind] + grade_step * grade_index + quantity_gain * (min(quantity, quantity_cap) - 1)
state    = afraid * afraid_pick[kind] + bold * bold_pick[kind] + afraid * afraid_pick_signature[calling][kind]
Appeal   = identity + sense + state
freeze:  if afraid >= freeze_at, the chooser takes NOTHING (D-39; D-07 is superseded)
```
`J` is Judgment (0 to 1). `afraid` and `bold` come from the shared `EmotionStatusLean.state_ends`. An ungraded find has grade index 0.

## Scalars
| Key | Value |
|---|---|
| `kind_weight` | gear 3, relic 4, consumable 2, material 1 |
| `grade_step` | 1.5 per grade index |
| `quantity_gain` | 0.5 per extra unit |
| `quantity_cap` | 3 units counted |
| `worth_weight` | 6 |
| `sense_base` | 0.3 |
| `freeze_at` | 0.5 |

## calling_pick (points)
| Calling | gear | relic | consumable | material |
|---|---|---|---|---|
| okofor | 6 | -2 | 4 | -8 |
| onyamesu | -4 | 0 | 8 | -4 |
| aduro | 8 | -4 | -2 | -2 |
| sum_okwanfo | -2 | 6 | -2 | -2 |
| okomfo | -6 | 8 | 2 | -4 |
| kra_soro | 2 | -6 | 4 | 0 |

## archetype_pick (points)
| Archetype | gear | relic | consumable | material |
|---|---|---|---|---|
| valiant | 6 | -2 | -2 | -2 |
| proud | 2 | 6 | -4 | -4 |
| ambitious | 4 | 2 | -2 | -4 |
| canny | -2 | -4 | 2 | 4 |
| loyal | 2 | -2 | 4 | -4 |
| stoic | 2 | -4 | 0 | 2 |
| devout | -2 | 6 | 0 | -4 |
| empathic | -4 | 0 | 6 | -2 |
| reflective | -4 | 4 | -2 | 2 |

## vector_pick_muls (per score point)
| Vector | gear | relic | consumable | material |
|---|---|---|---|---|
| vanguard | 0.09 | -0.03 | 0 | -0.06 |
| protector | 0.09 | -0.03 | 0.03 | -0.09 |
| seeker | -0.06 | 0.09 | 0 | -0.03 |
| pillar | 0.03 | 0 | 0.06 | -0.09 |
| strategist | 0 | 0.06 | -0.06 | 0 |
| skeptic | 0 | -0.09 | 0.03 | 0.06 |
| devoted | -0.03 | 0.09 | 0 | -0.06 |
| opportunist | 0.03 | 0 | -0.09 | 0.06 |
| mediator | -0.06 | 0 | 0.06 | 0 |
| nurturer | -0.09 | -0.03 | 0.09 | 0.03 |

## trait_pick_muls (per trait point)
| Trait | gear | relic | consumable | material |
|---|---|---|---|---|
| courage | 0.2 | -0.2 | 0 | 0 |
| wisdom | -0.1 | 0.1 | -0.1 | 0.1 |
| faith | -0.1 | 0.1 | 0.1 | -0.1 |

## stat_pick_muls (per stat point; six stats, no speed)
| Stat | gear | relic | consumable | material |
|---|---|---|---|---|
| max_hp | 0.025 | 0 | -0.025 | 0 |
| atk | 0.07 | -0.07 | 0 | 0 |
| def | 0.15 | 0 | 0 | -0.15 |
| agi | -0.12 | 0 | 0.12 | 0 |
| int | -0.07 | 0.07 | 0 | 0 |
| cha | 0 | 0 | 0.12 | -0.12 |

## State tables (points at full afraid or full bold, 1.0)
| Key | gear | relic | consumable | material |
|---|---|---|---|---|
| `afraid_pick` | 4 | -8 | 16 | -12 |
| `bold_pick` | 6 | 10 | -8 | -8 |

## afraid_pick_signature (points at full afraid; in `maturity_expression.calling_behavior.<calling>`)
| Calling | Signature | Combat parallel |
|---|---|---|
| okofor | consumable +8, gear +4 | `afraid_signature` protect_ally +10 |
| onyamesu | relic -8 | move -15 |
| aduro | gear +6, consumable -4 | melee +8, guard -5 |
| sum_okwanfo | none | none |
| okomfo | relic +8 | idle +15 |
| kra_soro | consumable +6, material +4 | move +12, idle -8 |

## Config shape (for step C4)
Tables live under `data.inventory.pick` in the style of the `data.inventory` block (`_xxx_comment` keys). `afraid_pick_signature` lives in `maturity_expression.calling_behavior.<calling>`. `ConfigValidator` rules: every row has exactly the four kinds; values are finite; one row per Calling, archetype, vector, trait and stat; `afraid_pick`, `bold_pick` and signature values stay within an absolute limit (proposed 30).

## Status
- The Judgment, composure and status values used in the proposal's character table were illustrative, not measured. The rate probe P2 measures the real difference between a Standing 1 and a Standing 9 chooser. Its pass line is still OPEN (D-09).
- Vector scores are about 60 at birth and nothing in play grows them today. If a later story grows them into the hundreds, the vector term will outweigh sense. Re-check then.
