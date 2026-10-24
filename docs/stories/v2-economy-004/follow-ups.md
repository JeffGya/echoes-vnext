# V2-ECONOMY-004 — follow-ups (noted, not built here)

Written in STE. One line per item: what, why, source decision. No Notion row exists for any of them. Jeff decides owner and order.

| # | Follow-up | Why | Source |
|---|---|---|---|
| 1 | Directives that trade speed for survival (more than the two scouting Directives) | A quick-win reward is only a fair risk choice if a player lever exists. Jeff: "we will add more directives". | D-47, D-49, D-56 |
| 2 | Rank and Thread redesign: marks ("All home", "Swift"), rank pay, a death always compromises the Thread | Almost every win is S now; GDD §14.3 wants deaths to lower Thread quality. Waits for follow-up 1 and the risk probe. | D-49, D-50, `phase5-risk-and-rank.md` |
| 3 | Banner `surface` shows the objective being fought, not the first objective | Fingerprint FINAL moves again when built. | D-08 |
| 4 | Pre-entry reward ESTIMATE of Ase and Ekwan in the stage overview (per revealed objective, "if overcome") | Jeff: "would be nice". Must not break hidden objectives (GDD §20.7, §20.8). | D-38 |
| 5 | Pre-fight cue that a quick win exists (not the target round) | Needed for a visible goal; target stays hidden. | D-51 |
| 6 | Result-moment sequence: party shown, each Echo marked "home", count completes, then the Ase figure; Sanctum consequence pass names survivors | Keeping Echoes alive must feel rewarding. | D-42, `phase5-echoes-alive-recheck.md` |
| 7 | Summon price rises with roster size; the price lever regulates population size | Keeps balance as the house grows. Design is in `phase5-tuning-proposal.md`; build scope judged at the build plan. | D-55 |
| 8 | Any non-Ase reward for survival (Standing, bond gain) | Canon names none. A new mechanic. | D-42 |
| 9 | Repeat return-home partial payout has no stamp and can pay on each return | Exploit, smaller after D-14. | Phase 3b design check, B5 |
| 10 | Optional objectives become truly skippable (DECIDED, D-82; built as step 5.9) | Risk choice. | D-82 |
| 11 | `guide_spirit` required: config flag changed to true (DECIDED, D-83; built in step 5.9) | Closes D95. | D-83 |
| 12 | Boss encounter contract (D96) | The boss is a stub and pays 0. | D-02, D-10 |
| 13 | Vow-break Ekwan prices (20 to 100): goals or penalties? | Matters for Part B. | D-32 note |
| 14 | `relic_secured` reason shows raw under VICTORY (`CombatState.gd:299`, no mapping in `ResolveScreen._format_reason`) | Found by UI QA. | UI session |
| 15 | Hard-coded 0.25 defeat consolation factor (`EconomyService.gd`) while `data.rewards.defeat_factor` exists | Tunable in code. | Phase 3 proposal |
| 16 | Stale block-count comments ("SIXTEEN BLOCKS", "SEVENTEEN-BLOCK") | Doc hygiene. | Phase 3c/4 reports |
| 17 | `VowService.gd:340` comment says "clamp to zero if broke"; `spend_*` denies the whole spend | Comment disagrees with code. | Phase 1/4 reports |
| 18 | Notion: ECONOMY-004 depends on ECONOMY-001 only; ECONOMY-003 gains ECONOMY-004; part B (item costs) waits for ITEM-001 | Dependency errors. | D-01 |
| 19 | ITEM-001 opening prompt for the other chat (when due) | Part B needs it. | D-01 |
| 20 | Village dwellings or rooms paid with Ekwan, as a literal capacity limit beside the rising summon price | Jeff wants population regulated and an Ekwan sink (GDD §19.2 lists rooms as an Ekwan use). Owner: an open Sanctum story or a new story. | D-55, D-64 |
| 21 | Copy: fiction frame for the rising price ("the price of holding one more life in the village" is a proposal), wording of every tooltip, "village" not "house" | Copy is Jeff's. | D-57 |
| 22 | Confirm how the opening affords Echo 2 (52 Ase against an uncalled price of 60) | Possible wall before stage 0; Jeff said keep 52. | D-58 |
| 23 | In-fight retreat is denied when Ase is below the price: check that a poor player is not trapped in a losing fight (GDD §20.10 safety valve); the map-level return home stays free | Jeff chose deny over free retreat. | D-79 |
| 24 | When Called and Chosen open on the summon screen: add an `enabled` flag per grade option in the SUMMON snapshot and delete the UI-side locked-grade constant in SummonScreen.gd | The lock is a UI constant for now (D-85). | summon UI session |
