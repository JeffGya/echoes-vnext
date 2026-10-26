# V2-ECONOMY-004 Part A — handoff

Written in STE. Source for every line: `decisions.md` (D-01 to D-111), the `phase*-build.md` files, `follow-ups.md` and `plan.md` in this folder.
State on 2026-10-26: built through Phase 6 (steps 6.1 to 6.5) on branch `claude/v2-economy-004-material-split-24c3be` (HEAD `8a6a008`). Combined-tree QA of Part A is done (D-102, D-103). QA of steps 6.1 to 6.3 is done (D-110). No QA record exists yet for steps 6.4 and 6.5. The work is not merged. Jeff plays the result before the PR (D-96). Nothing is pushed (D-87).

## What was built

| Phase | Content | Decisions | Build note |
|---|---|---|---|
| 1 | Characterization of real payouts and Ase/Ekwan sinks (no behavior change) | D-04 | `phase1-characterization.md` |
| 2 | D66 and D83 repaired: both reward sites read `type`, not `obj_type` | D-05 | `phase2-repair.md`, `phase2-attribution.md` |
| 3a | Weights for the five unweighted types; boss weight 0 (key kept); unknown type logs an error and pays 0 | D-02, D-07, D-09, D-10 | `phase3a-build.md` |
| 3b | Base counts COMPLETED objectives only, in every reader (stage, partials, consolation, pace, rank); harness fix | D-11 to D-16, D-21 to D-23 | `phase3b-build.md` |
| 3c | `cause` and `params` on every payout row; boss stub out of the objectives total (`objective_count_excluded_types`); saved bool `ui_flags.result_ledger_seen` and action `resolve.ledger.mark_seen` | D-17 to D-20, D-23 | `phase3c-build.md` |
| 3d | Read-only stage payout preview on the stage-ending victory card (same producer as the payer) | D-24, D-25 | `phase3d-build.md` |
| 4 | Separate Ekwan source `data.rewards.objective_ekwan`; fights pay no Ekwan; `stage_payout_ekwan`; "Sanctum share" row removed | D-05, D-06, D-16, D-27 to D-32 | `phase4-build.md` |
| 5.0 | Read-only confirmations (death field, opening, skill cost, retreat) | D-45, D-58, D-61 | `phase5-0-confirmations.md` |
| 5.1 | Enemy, virtue and pace Ase bonuses removed; rank re-based (win 0.40, home 0.40, pace 0.20); `pace_state` follows the pace fraction | D-40, D-49, D-70 | `phase5-1-build.md` |
| 5.1b | Any death caps the rank at A; the replay factor does not touch the rank; S allowed on a replay | D-69, D-74, D-75 | `phase5-1b-build.md` |
| 5.2 | Echoes-home stipend: 2 Ase per Echo, cap 10 (5 on a replay), once per stage, in the stage payout | D-41 to D-46, D-53, D-81 | `phase5-2-build.md` |
| 5.3 | Weights doubled (16/20/24/24/28/30/32); realm scale 1.00/1.25/+0.25; flat replay factor 0.35; redo ladder removed | D-54, D-62, D-63 | `phase5-3-build.md` |
| 5.4 | In-fight retreat costs 10 Ase; denied when the balance is lower; `stage.return_home` stays free | D-46, D-79 | `phase5-4-build.md` |
| 5.5 | Summon price by village size (60 to 430, flat from Echo 14); called +90, chosen +340; all 14 skills cost 60 | D-55, D-57, D-59 to D-61, D-76, D-85 | `phase5-5-build.md` |
| 5.5b | Summon grade lock in the core (`data.summoning.grade_enabled`; only `uncalled` is on) | D-85, D-93 | `phase5-5b-build.md` |
| 5.8 | Carried home is an advance on the stage payout (`carry_plan`, `carry_home`; `carried_ase`, `carried_ekwan`) | D-14, D-71, D-72 | `phase5-8-build.md` |
| 5.9 | Optional objectives are skippable (`ObjectiveModel.stage_completable`); `guide_spirit` required (D95 closed) | D-82, D-83, D-94 | `phase5-9-build.md` |
| 5.10 | `data.intel_gained` seam on the combat victory card (dormant: no fight reveals intel) | D-98, D-99, D-100 | `phase5-10-build.md` |
| 5.11 | Stage death record `lost_echo_names`; `data.thread_whole`; `data.objective_overcome` | D-98, D-101 | `phase5-11-build.md` |
| 5.12 | Fix D1: the stipend reads the stage death record after a quit and reload | D-102 | `phase5-12-build.md` |
| 5.13 | Config is the only source of economy numbers (`RewardCalc.cfg_num`; `defeat_factor` read from config; stale comments fixed; follow-ups 15, 16, 17, 29, 31 closed) | D-102 | `phase5-13-build.md` |
| 6.1 | Early leave settles by one roll (`carry_odds` 50/30/20, `carry_shares` 0/0.5/1.0, Scout shifts the odds); the unrolled share is lost; per-objective `settled`; stage `settled_ase`, `settled_ekwan`, `settle_count`; `carry_plan`/`carry_home` became `settle_plan`/`settle_leave`; `carried_ase`, `carried_ekwan`, `partial_intel_reward_factor` and the `carried_advance` row removed; `carry_home_preview` gets `nothing_new`; `settle_outcome` on the return card (b70c69e) | D-104 to D-106 | `phase6-1-build.md`, `phase6-early-leave-design.md` |
| 6.2 | A successful combat retreat settles nothing, costs 10 Ase and one turn, and returns the party to the path on the `retreat_return` card; new action `stage.retreat_return` (guard count 78); a normal fight is marked passed, an objective fight is offered again at once (aa3325e) | D-106 | `phase6-2-build.md` |
| 6.2b | Retreat roll key uses saved numbers (`run_count`, `turn_count`, saved `retreat_attempts`); a retreated normal fight returns on a later turn (`retreat_pass_turn`); `combat_baseline` retreat table re-recorded (dbc3407) | D-109 | `phase6-2b-build.md` |
| 6.3 | UI for early leave and the retreat card with Jeff's copy: confirmation panel, return-card outcome line, retreat card, ledger memo cause `settled_on_leave`, `Retreat (10 Ase)` button; `CarriedHomePanel` deleted (1495b30) | D-107 | `phase6-3-build.md` |
| 6.4 | Fixes from QA: a retreat-passed fight returns when it is the only target (`has_retreat_pass_waiting`); settle roll logged (`economy.settle.leave`); bad `carry_odds` or `carry_shares` fails visibly (`economy.settle.config_error`); removed `retreat_tier_label`, `carry_retreat_preview`, `partial_cause`; stale comments fixed (3c50074) | D-110 | `phase6-4-build.md` |
| 6.5 | UI: no outcome line on an empty leave; older strings reworded; UI leftovers cleaned (893de79, 4732054). The vow and sanctum screens read `path(s) finished` (8a6a008) | D-110, D-111 | `phase6-5-build.md` |

The UI session (`payout-explain-ui`, `docs/stories/v2-payout-explanation/`) built Direction E on the same branch, including the return-home confirmation before the action (D-102 D2). Its record is in that folder.

Docs updated in the Part A pass: `docs/MEMORY.md`, `docs/integration-map.md`, `CONVENTIONS.md` (snapshot rows and the Economy and Summoning sections), the defect register (`docs/stories/v2-infra-003/defect-register.md`, rows D66, D83, D94, D95, D96), `ANSWERS.md` (#84, #85). The Phase 6 documents pass updated `docs/MEMORY.md`, `docs/integration-map.md`, `CONVENTIONS.md` and `follow-ups.md` (items 33 to 46).

## What is NOT built

| Item | State | Source |
|---|---|---|
| Permadeath | Not built. The reward code connects to it at named places: `ActiveStageService.lost_echo_names_with`, `SummonService.living_count`, and `echo_id = roster.size() + 1` (three places). A note is on Notion story V2-INFRA-005. | D-66, D-67, ANSWERS #85 |
| Deaths in a retreated fight | Not recorded. A retreat does not reach the `combat_over` hook. A retreat then a return to the same stage loses those names. | D-101, `phase5-11-build.md` finding 1 |
| Death record key | Matches by display name. Two Echoes with the same name count as one. | `phase5-11-build.md` finding 2 |
| Server-side check of `flow.complete_stage` | A hand-sent action skips the stage gate. `VentureController.handle_complete_stage` trusts the offered action. | D-94, follow-up 25 |
| `FlowRuntime` call to `record_fight_deaths` | Covered by direct-call tests only. No test drives `_end_round` with a death. | D-101, `phase5-11-build.md` finding 4 |
| Boss encounter | The boss is a stub. It pays 0 and stays out of the objectives total. A future boss story must restore the weights on purpose. | D-02, D-10, D-23 |
| Called and Chosen summon grades | Locked by config. The summon snapshot has no selection slot for an enabled Called or Chosen card. | D-85, follow-up 24 |
| Part B (item-cost shape) | Waits for V2-ITEM-001 (separate story, separate chat). | D-01, follow-ups 18, 19 |
| Follow-ups 1 to 46 | Noted, not built. Jeff decides owner and order. Open ones include: more Directives (1), rank and Thread redesign (2), pre-entry reward estimate (4), summon-screen leftovers (29 part, the four unread summon keys), empty repeat-return explanation (30), optional objective after the last required win (32). Closed in Part A: 9, 10, 11, 15, 16, 17, 29 (legacy key), 31. Phase 6 adds 33 to 46 (retreat success chance from the action dict, vow stage-entry re-run, back button with a modal, bank-before-gamble probe, and others). | `follow-ups.md` |
| Phase 6 QA | Steps 6.4 and 6.5 have no final QA record. | `decisions.md` D-110 covers 6.1 to 6.3 only |
| Phase 6 retreat limits | The forced retreat still ends at the Sanctum (follow-up 46). A retreat does not record deaths. A re-entered objective fight reuses the same `encounter_id` (follow-up 36). | `phase6-2-build.md` findings 1 to 3 |
| Notion changes | Notion dependency fix for ECONOMY-004 and ECONOMY-003 is not made. Notes exist only on V2-INFRA-005, V2-PROG-012 and V2-PROG-016. | D-01, D-67, D-77 |

## Player-facing copy (Jeff's)

Copy is Jeff's. Agents propose, marked PROPOSAL, and stop (D-84).

**Chosen by Jeff and built:**

| Surface | Source | Strings |
|---|---|---|
| Return confirmation, return card, retreat card, ledger memo cause | D-107 and its two addenda | `Return to the Sanctum`, `Take the party back to the Sanctum?`, `To the Sanctum`, `Stay`, `In their packs: <Ase> Ase and <Ekwan> Ekwan.`, `Not all of it will survive the escape. What cannot be carried will be lost.`, `The path still waits.`, `Everything got out`, `Some of it got out`, `Nothing got out.`, `Nothing was gathered since the last time.`, `These were already taken when the party left earlier.`, `Pulled back`, `Withdrawing. Back to the path.`, `Leave`, `It's not smart to re-enter this quickly.`, `Our task is not done. This story is not over yet.`. The retreat button shows `Retreat (10 Ase)` only. The memo row label `Settled when you left` stays. The escape lines of D-103 stay. |
| Older strings with "home" or "stage" | D-111 | `Echoes safe`, `Each Echo that stays alive earns Ase.`, `alive`, `%s did not make it back.`, `The party has been here before. All of it earns less.`, `The party learned something new about the path.`, `%d path(s) finished`, `This path`, `Continue`, `This one was lost, but we still earn a small part.` |
| Vow and Sanctum screens | Commit 8a6a008 (marked as Jeff's change) | `%d path(s) finished` in `VowScreen.gd` and `SanctumScreen.gd`. UNSOURCED: no decision number records this pick. |

**Still placeholders (agent wording, not chosen by Jeff):**

1. The summon picks A1, B1, C1, P1, D1 (D-85) and the summon-price reason line.
2. Older Part A strings that the Phase 6 scan did not cover: `Redo penalty`, `Repeat defeat`, `Nothing overcome yet`, `Found and overcome.` (UNSOURCED: whether each still exists; the 6.5 scan checked only "home", "stage" and "%").
3. The retreat button disabled second line `Not enough Ase` (assumption in `phase6-3-build.md`).
4. Return-card banner `Scout Return`, `N situations revealed`, and the button defaults `Return to Sanctum` and `To Sanctum` (follow-up 43).
5. The Echoes header count `alive 2 of 3` (follow-up 44).
6. Gaps with no wording yet: a broken Thread (the Thread line is hidden when `thread_whole` is false); a repeat return home with nothing new and nothing earlier (D-110 F1 shows only the row `Nothing overcome yet`); the skipped-objective display (follow-up 26, D-97); the fiction frame for the rising summon price (follow-up 21).
7. Vocabulary Jeff uses: "earns", "found and overcome", "village", "Sanctum", "path", "lost". Jeff's word rules: no "home" and no "stage" in player text (D-107).

## Failed-escape copy: decided (D-103, steps 5.15 and 5.16)

- Fact from the code: `VentureController.handle_return_home` rolls the escape with the seed path `stage.escape.<stage_id>.<turn_count>`. `turn_count` rises only on an Advance. A second try on the same turn gives the same result.
- Jeff chose the wording. The confirmation panel shows: "Escaping might be more difficult than expected. It might not be possible." It has no subtitle. A failed escape shows the subtitle "No way out." and the body "It was not possible to escape at the moment. Move on, we can try again later."
- The roll is unchanged. The panel shows no chance of success.

## Where to look

| Need | File |
|---|---|
| All decisions | `decisions.md` |
| Follow-ups | `follow-ups.md` |
| Last builds | `phase5-12-build.md` to `phase5-16-build.md`, `phase6-1-build.md` to `phase6-5-build.md` |
| UI side | `docs/stories/v2-payout-explanation/decisions.md` |
| Defects | `docs/stories/v2-infra-003/defect-register.md` (D66, D83, D93 to D96) |
