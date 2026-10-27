# V2-ECONOMY-004 Part A — handoff

Written in STE. Source for every line: `decisions.md` (D-01 to D-118), the `phase*-build.md` files, `follow-ups.md` and `plan.md` in this folder.
State on 2026-10-27: built through Phase 7 (steps 7.A to 7.D) on branch `claude/v2-economy-004-material-split-24c3be` (HEAD `95d54bd`). Combined-tree QA of Part A is done (D-102, D-103). QA of steps 6.1 to 6.3 is done (D-110). No QA record exists yet for steps 6.4, 6.5 and Phase 7 (7.A to 7.D). The sharded or full suite is not recorded for Phase 7: the build notes list filtered runs only and a RUN REQUEST for the heavy suites (`fingerprint_*`, `reward`, `combat_baseline`, `combat_roundtrip`, `maturity_baseline`). The work is not merged. Jeff plays the result before the PR (D-96). Nothing is pushed (D-87).

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
| 6-final | Word rules made global: ANSWERS #86, follow-up 47 (32ed7ae). Phase 6 documents pass: MEMORY, integration map, CONVENTIONS, handoff, follow-ups 33 to 46 (d84111a). No code changed | D-112 | `decisions.md` |
| 7 decisions | Every encounter pays and joins the leave roll (9d4cdfd); the packs rule as ANSWERS #87, D-114, follow-up 48 (57700a9); encounter pay answers (eeddaff). Design files `phase7-encounter-pay-design.md`, `phase7-forced-retreat-design.md`, `phase7-forced-retreat-feel-review.md` | D-113 to D-115 | the design files |
| 7.A | The packs model: stage field `earnings`, `EarningsService`, objectives moved onto rows with no total moved; config `encounter_weights.fight` = 6 added (f347850) | D-115 | `phase7-a-build.md` |
| 7.copy | Standoff, warning, packs, defeat and situation copy, AGENT-WRITTEN in Jeff's tone (357154f). D-116 addendum (warning, cause, fear drop, deaths before a standoff count) in 7ea06b7 | D-116, D-117 | `phase7-copy-final.md` |
| 7.B | Encounters pay through the packs: 6 Ase per normal and hostile-Claimant fight; defeat loses the unsettled packs; found Ase joins the packs (b84ac00) | D-113 to D-115 | `phase7-b-build.md` |
| 7.C | Packs in the snapshots (`carry_home_preview.gathered`, `ase_gathered`, new ledger causes); every defeat loses the packs (15a35c7). `snapshot_fingerprint/stage_explore` re-recorded once (cause: key `gathered`) | D-115 | `phase7-c-build.md` |
| 7.S | The forced retreat is a standoff: card, action `stage.standoff_return` (guard count 79), `StandoffService`, warning data, deaths before it count, `packs_lost` row (9d5fa35). D-118 fear write-back (3f40aa6) | D-116, D-118 | `phase7-s-build.md` |
| 7.D | UI: standoff card, board warning, prebattle line, packs lines, found-Ase cards, return confirmation reads `gathered`; the mid-stage `step.parallel()` error fixed; the won-fight button reads `Back to the path` (95d54bd) | D-117 | `phase7-d-build.md` |

The UI session (`payout-explain-ui`, `docs/stories/v2-payout-explanation/`) built Direction E on the same branch, including the return-home confirmation before the action (D-102 D2). Its record is in that folder.

Docs updated in the Phase 7 pass: `docs/MEMORY.md`, `docs/integration-map.md`, `CONVENTIONS.md`, this file and `follow-ups.md` (items 49 to 56).

Docs updated in the Part A pass: `docs/MEMORY.md`, `docs/integration-map.md`, `CONVENTIONS.md` (snapshot rows and the Economy and Summoning sections), the defect register (`docs/stories/v2-infra-003/defect-register.md`, rows D66, D83, D94, D95, D96), `ANSWERS.md` (#84, #85). The Phase 6 documents pass updated `docs/MEMORY.md`, `docs/integration-map.md`, `CONVENTIONS.md` and `follow-ups.md` (items 33 to 46).

## What is NOT built

| Item | State | Source |
|---|---|---|
| Permadeath | Not built. The reward code connects to it at named places: `ActiveStageService.lost_echo_names_with`, `SummonService.living_count`, and `echo_id = roster.size() + 1` (three places). A note is on Notion story V2-INFRA-005. | D-66, D-67, ANSWERS #85 |
| Deaths in a CHOSEN retreat | Not recorded. A chosen retreat does not reach the `combat_over` hook. A retreat then a return to the same stage loses those names. A standoff DOES record deaths (7.S). | D-101, `phase5-11-build.md` finding 1, D-116 addendum d |
| Death record key | Matches by display name. Two Echoes with the same name count as one. | `phase5-11-build.md` finding 2 |
| Server-side check of `flow.complete_stage` | A hand-sent action skips the stage gate. `VentureController.handle_complete_stage` trusts the offered action. | D-94, follow-up 25 |
| `FlowRuntime` call to `record_fight_deaths` | Covered by direct-call tests only. No test drives `_end_round` with a death. | D-101, `phase5-11-build.md` finding 4 |
| Boss encounter | The boss is a stub. It pays 0 and stays out of the objectives total. A future boss story must restore the weights on purpose. | D-02, D-10, D-23 |
| Called and Chosen summon grades | Locked by config. The summon snapshot has no selection slot for an enabled Called or Chosen card. | D-85, follow-up 24 |
| Part B (item-cost shape) | Waits for V2-ITEM-001 (separate story, separate chat). | D-01, follow-ups 18, 19 |
| Follow-ups 1 to 56 | Noted, not built. Jeff decides owner and order. Open ones include: more Directives (1), rank and Thread redesign (2), pre-entry reward estimate (4), summon-screen leftovers (29 part, the four unread summon keys), empty repeat-return explanation (30), optional objective after the last required win (32). Closed in Part A: 9, 10, 11, 15, 16, 17, 29 (legacy key), 31. Phase 6 adds 33 to 46 (retreat success chance from the action dict, vow stage-entry re-run, back button with a modal, bank-before-gamble probe, and others). Follow-up 46 is closed by the standoff (D-116). Follow-ups 47 and 48 are recorded after Phase 6. Phase 7 adds 49 to 56. | `follow-ups.md` |
| Phase 6 and 7 QA | Steps 6.4 and 6.5 have no final QA record. Steps 7.A to 7.D have none. | `decisions.md` D-110 covers 6.1 to 6.3 only |
| Phase 6 retreat limits | A chosen retreat does not record deaths. A re-entered objective fight reuses the same `encounter_id` (follow-up 36). (The forced retreat no longer ends at the Sanctum: it is a standoff, 7.S.) | `phase6-2-build.md` findings 1 to 3, D-116 |
| Other encounter kinds and items | Not in the packs. Contact, shrine, recovery segment and other kinds, and items found on the path, are for Jeff's later work (follow-up 48). This story builds the packs for objectives, normal fights and found Ase. | D-114, ANSWERS #87 |
| Standoff feel extras | Not built: hold-then-cross-fade when the standoff fires, vignette, token-breathing change, fast-forward of quiet rounds, fade-out of the warning on clear, per-Echo barks. | `phase7-d-build.md` section 6, follow-ups 51 to 53 |
| Phase 7 turn limit and income | A path has no turn limit and passive income pays by clock time. A standoff therefore costs the player time, not value. Not changed. | `phase7-s-build.md` section 3 |
| Heavy suites for Phase 7 | The build notes list a RUN REQUEST for `fingerprint_*`, `reward`, `combat_baseline`, `combat_roundtrip`, `maturity_baseline`. No result is recorded in these docs. UNSOURCED: whether they ran. | `phase7-*-build.md` RUN REQUEST |
| Notion changes | Notion dependency fix for ECONOMY-004 and ECONOMY-003 is not made. Notes exist only on V2-INFRA-005, V2-PROG-012 and V2-PROG-016. | D-01, D-67, D-77 |

## Player-facing copy (Jeff's)

Copy is Jeff's. Agents propose, marked PROPOSAL, and stop (D-84).

**Chosen by Jeff and built:**

| Surface | Source | Strings |
|---|---|---|
| Return confirmation, return card, retreat card, ledger memo cause | D-107 and its two addenda | `Return to the Sanctum`, `Take the party back to the Sanctum?`, `To the Sanctum`, `Stay`, `In their packs: <Ase> Ase and <Ekwan> Ekwan.`, `Not all of it will survive the escape. What cannot be carried will be lost.`, `The path still waits.`, `Everything got out`, `Some of it got out`, `Nothing got out.`, `Nothing was gathered since the last time.`, `These were already taken when the party left earlier.`, `Pulled back`, `Withdrawing. Back to the path.`, `Leave`, `It's not smart to re-enter this quickly.`, `Our task is not done. This story is not over yet.`. The retreat button shows `Retreat (10 Ase)` only. The memo row label `Settled when you left` stays. The escape lines of D-103 stay. |
| Older strings with "home" or "stage" | D-111 | `Echoes safe`, `Each Echo that stays alive earns Ase.`, `alive`, `%s did not make it back.`, `The party has been here before. All of it earns less.`, `The party learned something new about the path.`, `%d path(s) finished`, `This path`, `Continue`, `This one was lost, but we still earn a small part.` |
| Vow and Sanctum screens | Commit 8a6a008 (marked as Jeff's change) | `%d path(s) finished` in `VowScreen.gd` and `SanctumScreen.gd`. UNSOURCED: no decision number records this pick. |

**Phase 7 copy: AGENT-WRITTEN (D-117), not chosen by Jeff.** Jeff said: "For any text let an agent write the copy in the tone I have chosen." File: `phase7-copy-final.md`. The build uses its final lines exactly. Jeff may edit any line after the play test. Slots:

| Surface | Lines (final) |
|---|---|
| Standoff card | `Nobody moved` · `Neither side would strike. The party stepped back.` · `%s could not move. The party stepped back.` · `%s and %s could not move. The party stepped back.` · `No one could get through. The party stepped back.` · `Their packs are as they were.` · `The task is still there.` · `%s breathed out.` · `It went the same way last time.` · `Maybe they need rest.` · buttons `Back to the path`, `To the Sanctum` |
| Board warning | `Nobody is moving.` · `Nobody wants to go first.` · bark `Not yet. I can't.` |
| Prebattle | `They stalled here before.` |
| Packs and ledger causes | `Fight won` (tooltip `It goes in their packs. It is safe only when the party gets out.`) · `Found` (`Found along the way. It goes in their packs.`) · `Fights won` (`Fights won on this path: %d.`) · `Found on the path` (`Gathered along the way and carried to the Sanctum.`) · `Nothing was gathered.` |
| Defeat | `The party fell, and the packs were lost.` |
| Situation cards | `They found %d Ase. It goes in the packs.` · `The party was given %d Ase for the way. It goes in the packs.` |
| Return confirmation | `Nothing is in their packs.` (the filled line `In their packs: <Ase> Ase and <Ekwan> Ekwan.` is Jeff's, D-107) |

The agent-written build choices that the copy file did not fix (ASSUMED in `phase7-d-build.md`): repeat hint 1 on the second standoff, hint 2 on the third and later, none on the first; level 2 replaces the level 1 line; the standoff packs line and open-fight line always show. The label `Back to the path` replaced `Return to Stage` on two core cards in commit 95d54bd.

**Still placeholders (agent wording, not chosen by Jeff):**

1. The summon picks A1, B1, C1, P1, D1 (D-85) and the summon-price reason line.
2. Older Part A strings that the Phase 6 scan did not cover: `Redo penalty`, `Repeat defeat`, `Nothing overcome yet` (the UI shows `Nothing was gathered.` in its place since 7.D; the core label stays), `Found and overcome.` (UNSOURCED: whether each still exists; the 6.5 scan checked only "home", "stage" and "%").
3. The retreat button disabled second line `Not enough Ase` (assumption in `phase6-3-build.md`).
4. Return-card banner `Scout Return`, `N situations revealed`, and the button defaults `Return to Sanctum` and `To Sanctum` (follow-up 43).
5. The Echoes header count `alive 2 of 3` (follow-up 44).
6. Remaining placeholders after Phase 7: the core label `Echoes home` (follow-up 39) and the strings of follow-ups 43, 44 and 47. Gaps with no wording yet: a broken Thread (the Thread line is hidden when `thread_whole` is false); a repeat return home with nothing new and nothing earlier (D-110 F1 shows only the row `Nothing overcome yet`); the skipped-objective display (follow-up 26, D-97); the fiction frame for the rising summon price (follow-up 21).
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
| Last builds | `phase5-12-build.md` to `phase5-16-build.md`, `phase6-1-build.md` to `phase6-5-build.md`, `phase7-a-build.md`, `phase7-b-build.md`, `phase7-c-build.md`, `phase7-s-build.md`, `phase7-d-build.md` |
| Phase 7 design and copy | `phase7-encounter-pay-design.md`, `phase7-forced-retreat-design.md`, `phase7-forced-retreat-feel-review.md`, `phase7-copy-final.md` |
| UI side | `docs/stories/v2-payout-explanation/decisions.md` |
| Defects | `docs/stories/v2-infra-003/defect-register.md` (D66, D83, D93 to D96) |

## Open play test items (Phase 7)

Jeff plays these before the PR (D-96). Each item names its source.

1. **Fear write-back (D-118).** The standoff writes the fight's final fear and morale to the roster, and the first-standoff drop (10) acts on it. An Echo that froze starts the rerun with high fear. Jeff can reverse this. Source: D-118, `phase7-s-build.md` section 4.
2. **Fear drop size and warning fractions.** `standoff_fear_drop` 10, `warn_level1_fraction` 0.5, `warn_level2_fraction` 0.8 are PROPOSED DEFAULTS. `mid-game-designer` tunes them. Source: `phase7-s-build.md` section 2.
3. **Warning wording and look.** D-116 addendum (a): the wording stays a proposal until Jeff confirms. The warning bark is one fixed line. Check the blue pill on the board in the real window sizes (the compact and standard screenshots came out equal at 1280x720). Source: D-116, `phase7-d-build.md` section 4.
4. **Standoff card.** The cause line only shows with a recorded event. A position block reads as `generic` (`unknown`). Check that the card reads right for a froze case, a guard case and a quiet case. Source: `phase7-s-build.md` cause rule.
5. **Quiet-round wait.** A standoff costs the player the time of about 15 quiet rounds and no value (no turn limit, income by clock time). Fast-forward of quiet rounds is not built. Jeff decides whether the wait is acceptable. Source: `phase7-s-build.md` section 3, `phase7-forced-retreat-feel-review.md` section 2.5.
6. **Rerun loop.** A rerun with unchanged inputs stalls again. Check that the player can find a lever (party, Directive, rest). Source: `phase7-s-build.md` section 3 consequence 2, feel review 3.4.
7. **Packs feel.** A fight now shows `Fight won +6 Ase` while the balance does not rise until a leave or the path end. Event cards show BASE amounts (a replay run still shows 6 for a fight). Check that this reads right. Source: `phase7-c-build.md` OPEN, `phase7-d-build.md` OPEN.
8. **Defeat loses all packs.** Check that losing every unsettled row on every defeat feels fair, and that the `packs_lost` line reads right. Source: D-115 item 1.
9. **Standoff, then Sanctum.** From the second standoff the `To the Sanctum` button opens the return confirmation once; the escape check and the settle roll run there. Check that the flow is clear. Source: `phase7-s-build.md` action section.
10. **Copy edits.** Jeff may edit any line of `phase7-copy-final.md`. Source: D-117.
