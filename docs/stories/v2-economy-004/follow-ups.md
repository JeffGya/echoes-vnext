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
| 9 | ~~Repeat return-home partial payout has no stamp~~ CLOSED by D-72 (advance with a carried record) | | D-72 |
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
| 24 | When Called and Chosen open: the backend `enabled` flag EXISTS (step 5.5b) and the UI constant is gone. Still to build: a `sanctum.grade_select` slot or per-row action in the summon snapshot so an enabled Called or Chosen card can be selected (the UI card is tappable but sends nothing) | The story that opens a grade does this. | summon UI session, D-85 |
| 25 | `flow.complete_stage` is not re-validated server-side: a hand-sent action skips the stage gate (`stage_completable`) | Today the handler trusts the offered action. A guard is a new rule. | D-94 |
| 26 | Display of skipped optional objectives on the stage-ending card (derive from objective entries: required false, completed false, type not boss); never show the boss stub as skipped | Jeff: later, after play (D-97). | D-82, D-97 |
| 27 | Fight events on the Resolve card (rescue, refusal, other 'what the fight changed' stories): define the events first, then add a field | Jeff had no preference; not added in Part A. | D-98 |
| 28 | Intel from fights: design how a won fight reveals situations or intel; the dormant `intel_gained` seam (step 5.10) then reports it and the mid-stage card's intel line lights up | No fight reveals a situation today. Jeff: a later story (D-99). | D-99 |
| 29 | Remove the unread legacy snapshot key `ase_cost_per_summon` (`FlowSummonState.gd`) and its pin in `SanctumSummonTests.gd`; review the unread summon keys `summon_denied`, `ase_short_by`, `village_ceiling`, `batch_prices` | QA N4: no UI reads them. | D-102 |
| 30 | A repeat return home with nothing new shows no explanation row | QA N3: needs a zero-by-rule reason or a sentence (copy is Jeff's). | D-102 |
| 31 | Config defaults repeat design numbers in code (0.25, 0.35, 1.1, 1.6, 0.4/0.4/0.2, rank thresholds, 0.12, village_ceiling 14, retreat 10); read `data.rewards.defeat_factor` | QA N5: each value exists in two places. | D-102, follow-up 15 |
| 32 | After the last required objective is won, the card offers only `flow.complete_stage`, so an optional objective can no longer be done; skipping is a real choice only before that fight | QA N7: old behavior; design question. | D-102 |
| 33 | F5: the `encounter.retreat` handler reads the success chance from the action dict (`FlowRuntime.gd:1173`). Remove that read; also remove `retreat_success_pct` from the encounter snapshot and `cta.retreat.success_pct` from the action (a percent in a snapshot; no `ui/` reader) | Pre-existing. The chance should come from core state, not from a hand-sent action. | D-110 F5, `phase6-4-build.md` |
| 34 | The tag `TIER_PASSED_OBJECTIVE` also names the re-offer of a retreat-passed NORMAL fight. Only the name misleads. The rename touches 10 places and the state key string `state.tier_passed_objective` (bark data may use it) | Rename needs a bark-data audit first. | `phase6-2b-build.md`, `phase6-4-build.md` F3 |
| 35 | The vow stage-entry check (`apply_vow_stage_entry_condition`) re-runs after every `situation_result` card, so vow compliance may be over-counted. The tick guard blocks only a repeat on the same tick | Pre-existing, not Phase 6. A retreat avoids it through `stage.retreat_return`. | D-109 (noted), `phase6-2-build.md` finding 5 |
| 36 | A re-entered objective fight reuses the same `encounter_id` (`realm.stage.sit.N`), so terrain and spawn cell are the same | Not decided. Probably wanted (no new-fight exploit); Jeff to confirm. | D-109 (noted), `phase6-2-build.md` finding 2 |
| 37 | The hardware back button does nothing while a modal is open (`AppRoot._handle_go_back_request`, `ui/AppRoot.gd:421`). On the return confirmation and the retreat card only the on-screen buttons close it | UI decision. Esc works. | `phase6-3-build.md` finding 1 |
| 38 | `StructuredLogger` has no error level. Missing-config cases use `warn`, which writes at info level (`economy.settle.config_error`, `RewardCalc.cfg_num`) | A real error level would make bad config easier to see. | `phase6-4-build.md` F6 |
| 39 | `EconomyService.gd:242` still sends the core row label `Echoes home`. The UI hides it through `row_name` (`Echoes safe`); it would show only if the cause were missing | Core label and player word disagree. | `phase6-5-build.md` finding 3, D-111 |
| 40 | GDD section 20.10: the combat retreat is now a step back to the path, not an exit. Jeff may add one line to 20.10. No agent edits the GDD | The design file asked for this line. | `phase6-early-leave-design.md` section 9 (GDD check), D-104 |
| 41 | Probe the "bank before a gamble" loop: a return home now loses 65% of the gathered amount on average (Scout 58%). Measure whether players still bank to afford an Echo, and whether the loss feels fair | Design file says it is a paid gamble, not an exploit. This is arithmetic, not a measurement. | `phase6-early-leave-design.md` sections 6, 7, D-105 |
| 42 | `ContactController` uses a literal 20 (summon grade surcharge default) | Left as a follow-up by Jeff in the final QA of Part A. | D-103 F3 |
| 43 | Strings still in the old words on the return card: banner `Scout Return`, `N situations revealed`, defaults `Return to Sanctum` and `To Sanctum` | Not in the D-107 or D-111 lists. Copy is Jeff's. | `phase6-5-build.md` finding 4, `phase6-3-build.md` finding 3 |
| 44 | The Echoes header count reads `alive 2 of 3` and each row tag reads `alive`; repetitive | Copy is Jeff's. | `phase6-5-build.md` finding 2 |
| 45 | A return card with Ekwan above 0 and no other rows opens a ledger that holds only the total and the Ekwan line | Layout check. | `phase6-3-build.md` finding 4 |
| 46 | The forced retreat (`no_progress_forced_retreat`) still ends at the Sanctum with no pass mark. Jeff may decide it shares the retreat-to-the-path route; today it would put the party in front of the same stalemate | Test `retreat/forced_retreat_still_ends_at_sanctum` pins the current rule. | `phase6-2-build.md` finding 3 |
| 47 | Reword the other player strings that still say "home" or "stage" (about 16 rows: path map, Sanctum and explore buttons, resolve action, vow hints, Keeper intro line). Jeff: "We do not have to fix it all now" | Proposals with three options per row are in `phase6-ux-copy-rest-of-game.md`. Core labels need a small core edit with the UI default and scene text; pinned tests move with them. The global rule is ANSWERS #86. | D-112, final QA of 6.4 and 6.5 |
| 48 | Other encounter kinds (contact, shrine, recovery segment, claimant and others) must pay Ase or Ekwan into the packs and join the leave roll, and items found in encounters or on the path must join the packs too. Jeff will work on these after this story | This story builds the packs for normal fights only (D-113, D-114). The global rule is ANSWERS #87. Each new source adds a row to the earnings list; none pays straight into the balance. | D-114 |

