# V2-ECONOMY-004 Part A — handoff

Written in STE. Source for every line: `decisions.md` (D-01 to D-102), the `phase*-build.md` files, `follow-ups.md` and `plan.md` in this folder.
State on 2026-10-25: built through step 5.13 on branch `claude/v2-economy-004-material-split-24c3be` (HEAD `9cfd2e4`). Combined-tree QA is done (D-102). The work is not merged. Jeff plays the result before the PR (D-96). Nothing is pushed (D-87).

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

The UI session (`payout-explain-ui`, `docs/stories/v2-payout-explanation/`) built Direction E on the same branch, including the return-home confirmation before the action (D-102 D2). Its record is in that folder.

Docs updated in this pass: `docs/MEMORY.md`, `docs/integration-map.md`, `CONVENTIONS.md` (snapshot rows and the Economy and Summoning sections), the defect register (`docs/stories/v2-infra-003/defect-register.md`, rows D66, D83, D94, D95, D96), `ANSWERS.md` (#84, #85).

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
| Follow-ups 1 to 32 | Noted, not built. Jeff decides owner and order. Open ones include: more Directives (1), rank and Thread redesign (2), pre-entry reward estimate (4), summon-screen leftovers (29 part, the four unread summon keys), empty repeat-return explanation (30), optional objective after the last required win (32). Closed in Part A: 9, 10, 11, 15, 16, 17, 29 (legacy key), 31. | `follow-ups.md` |
| Notion changes | Notion dependency fix for ECONOMY-004 and ECONOMY-003 is not made. Notes exist only on V2-INFRA-005, V2-PROG-012 and V2-PROG-016. | D-01, D-67, D-77 |

## What the player-facing copy still needs (Jeff's)

All player-facing strings are placeholder. Copy is Jeff's. Agents propose, marked PROPOSAL, and stop (D-84).

1. One ux-copy pass after the row set is final (D-84). It covers: tooltips, "home N of M", the carried-home line, the stage-waits line, the summon-price reason, the mid-stage card lines, the rank marks, and the retreat-denied reason.
2. Placeholder strings in use: "Echoes home", "Redo penalty", "Repeat defeat", "Nothing overcome yet", "Found and overcome.", the intel line, "Take the party home?", "Go home", "Stay", and the summon picks A1, B1, C1, P1, D1 (D-85).
3. Gaps with no wording yet: a broken Thread (the Thread line is hidden when `thread_whole` is false); a repeat return home with nothing new to carry (follow-up 30); the skipped-objective display (follow-up 26, D-97); the fiction frame for the rising summon price (follow-up 21).
4. Vocabulary Jeff uses: "earns", "found and overcome", "village", "home".

## Failed-escape copy: decided (D-103, steps 5.15 and 5.16)

- Fact from the code: `VentureController.handle_return_home` rolls the escape with the seed path `stage.escape.<stage_id>.<turn_count>`. `turn_count` rises only on an Advance. A second try on the same turn gives the same result.
- Jeff chose the wording. The confirmation panel shows: "Escaping might be more difficult than expected. It might not be possible." It has no subtitle. A failed escape shows the subtitle "No way out." and the body "It was not possible to escape at the moment. Move on, we can try again later."
- The roll is unchanged. The panel shows no chance of success.

## Where to look

| Need | File |
|---|---|
| All decisions | `decisions.md` |
| Follow-ups | `follow-ups.md` |
| Last two builds | `phase5-12-build.md` to `phase5-16-build.md` (5.12 to 5.15 have a RUN REQUEST) |
| UI side | `docs/stories/v2-payout-explanation/decisions.md` |
| Defects | `docs/stories/v2-infra-003/defect-register.md` (D66, D83, D93 to D96) |
