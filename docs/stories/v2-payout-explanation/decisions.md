# Payout explanation — decisions (Jeff, 2026-10-20)

| ID | Decision |
|---|---|
| D-01 | The result screen uses the compact layout, Option 1 (`mockups/resolve-compact.html`): one earnings line, the ledger one tap away, Echo list and vow visible at once. |
| D-02 | Row causes show in a floating tooltip with an arrow (hover, focus or tap), not an inline panel. Each (i) target is 48x48. |
| D-03 | The ledger starts open the first time the player sees a result, then closed. Needs a saved "seen" flag (backend request). |
| D-04 | Word rule: Ase and Ekwan are "earned", not "paid". Objectives are "found and overcome", not "won". |
| D-05 | Stat chips: "Enemies defeated", "Echoes alive", "Rounds" (plus Rank). |
| D-06 | Tooltip voice: option A, told about "the party". The player is the Keeper who observes, so no "you". |
| D-07 | Row names: "Bonus" (not "Pace bonus"), "Replay" (not "Redo penalty" or "Repeat run"). "Replay" shows only when it applies. |
| D-08 | Objectives row tooltip stays as written. No note about earning twice (objective fight and stage). |
| D-09 | A repeat defeat shows a zero row in the same style as the other rows. |
| D-10 | Realm has no payout of its own in the code. Realm only shapes "Replay" and "Realm virtue". Skip a realm-end payout for now (Jeff). |
| D-11 | No "Sanctum share" row or tooltip. Ekwan shows only as "Ekwan earned" with its amount, no (i). |
| D-12 | The stage payout shows on the Resolve card (Jeff, via the backend session). The ledger has two groups, "This fight" and "Stage". One total adds both. Decided: mid-stage cards show fight rows only. The Stage group shows only on the stage-ending card (Jeff). |
| D-13 | No mid-stage stage preview. The UI shows the Stage group only when `stage_payout_rows` exists in the snapshot. No `stage_payout_final` flag. |

## Final tooltip text (PROPOSAL until Jeff reads it in game)

| Row | Text |
|---|---|
| Enemies defeated | Each enemy the party defeats earns Ase. |
| Echoes alive | Each Echo still standing when the fight ends earns Ase. |
| Bonus (zero) | The party was not quick enough to earn a bonus. |
| Bonus (earned) | The party was quick enough to earn a bonus. |
| Replay | The party has been here before. It earns less. |
| Objectives overcome | Only objectives the party found and overcame earn Ase. 2 of 3 so far. |
| Realm virtue | The realm rewards the virtue the party showed here. |
| Consolation | The party lost, but the fight still earns a small part. |
| Carried home | The party left early. It keeps a small part of what it overcame. |
| Carried home (zero) | The party has not overcome anything yet. Nothing is earned. |
| Repeat defeat (zero) | The party already earned the consolation for this. Another loss earns nothing. |

Backend cause ids: `objectives_overcome` (params `overcome`, `total`), `bonus_earned`, `bonus_missed`, `replay`, `realm_virtue`, `defeat_consolation`, `partial_retreat`, `partial_return_home`, `nothing_overcome_yet`, `repeat_defeat`; plus a saved flag for "ledger seen".


Stage-level Replay tooltip (PROPOSAL): The party has been here before. The whole stage earns less.
Proposed keys: `stage_payout_rows`, `stage_payout_ase` (present only on the stage-ending card; names for the backend to confirm).

## Backend contract received (2026-10-20, from the ECONOMY-004 session; uncommitted there)

- Row shape: `{label, delta, currency, cause, params}`.
- Causes: `enemies_defeated`, `echoes_alive`, `bonus_earned`, `bonus_missed`, `replay` (absent when not applicable), `defeat_consolation` (two rows: `params.part` = base or penalty), `repeat_defeat`, `objectives_overcome`, `realm_virtue`, `partial_retreat`, `partial_return_home`, `nothing_overcome_yet`.
- "Found" row and Ekwan row have no cause. The UI shows every Ekwan row as "Ekwan earned", no (i).
- Stage rows: `data.stage_payout_rows`, `data.stage_payout_ase`, only on the stage-ending victory card.
- Ledger flag: save `ui_flags.result_ledger_seen`; action `resolve.ledger.mark_seen`; snapshot `data.ledger_seen`.
- Amounts still move (Phase 4, Phase 5). The UI hard-codes no amounts.

### UI points to settle before the build

1. DECIDED (Jeff): the UI nets the two `defeat_consolation` rows (`params.part` base and penalty) into one "Consolation" row. The (i) tooltip uses the `defeat_consolation` text.
2. Total: the UI sums `delta` of Ase rows, or reads `ase_awarded` plus `stage_payout_ase`. Prefer the data total, not a UI sum.
3. Build waits for Jeff's go and his commit and branch order for the backend work.
| D-14 | Consolation: the UI nets the base and penalty rows into one "Consolation" row (Jeff). Build still held until Jeff says go. |
| D-15 | Ekwan (backend D-28 to D-32, Jeff): fights earn none. Fight cards show Ase only, no Ekwan row or chip. The stage-ending card shows "Ekwan earned" with its amount (`stage_payout_ekwan`, name unconfirmed), no (i), outside the Ase total. No "Sanctum share" row exists. |

Stage Replay tooltip (DECIDED, Jeff): "The party has been here before. The whole stage earns less Ase and Ekwan."

## Build status (UI, 2026-10-21)

- Built: PayoutCausePresentation, CauseTooltip, RewardEntryItem (i) button, Resolve card Option 1 (FightStrip, EarningsSummary, Ledger).
- Tests: `payout_ui` suite (16 tests). Screenshots: `screenshots/<fixture>_<profile>.png`.
- Rows come from snapshot data only. A cause with no row is an unused tooltip entry. An unknown cause shows no (i).
- Row name for `repeat_defeat` is "Consolation" (assumption, Jeff to confirm).
- The theme got additive Payout* variations (`assets/theme/LivingTreeSystem.tres`).
| D-16 | Direction E chosen (Jeff, 2026-10-21): no running Ase figure on the mid-stage card. It shows the party and their state, one line on what the fight changed, the objective as a story mark, intel gained, the Thread line, then go on / go home. "Carried home" shows only at the return or retreat confirmation, with a comparator, and only above 0. The flame glow is NOT used. Mockup: `mockups/stage-flow-motion.html`. Build waits for "ROW SET FINAL" and Jeff's go. Open rule questions are with the backend session. |

## Rule answers from the backend session (Jeff, backend D-72, 2026-10-21)

1. An overcome objective stays overcome after a return home (GDD 20.8). The "stage waits" line is true.
2. The carried amount (12%) is an ADVANCE. At stage end the stage pays in full MINUS what was already carried. No double pay.
3. Repeat return-home with no new objective carries 0 more (backend step 5.8).
4. The realm scale and the replay factor apply to the carried amount.
5. Rank rule (backend D-69): any death caps the rank at A; S needs everyone home. The mockup shows "rank B with one Echo lost" as an example only. It is invented. Do not build it as fact.

Open for the UI: the return and retreat confirmation can say what is banked now and that the rest is paid when the stage is finished (PROPOSAL wording needed from Jeff; use "earned", not "paid", in player text).

## Ledger update to the final backend row set (UI, 2026-10-24)

- Removed from the UI table: `enemies_defeated`, `realm_virtue`, `bonus_earned`, `bonus_missed`, and the fight-level `echoes_alive`. A stray row with one of these shows its backend label and no (i).
- A fight win has no rows: the card shows no earnings line, no ledger and sends no `resolve.ledger.mark_seen`.
- Stage rows added: `echoes_alive` (row name "Echoes home", lost names in a second line) and `carried_advance` (row name "Carried home", negative amount).
- PROPOSAL placeholders, not approved copy (Jeff owns the wording; a later ux-copy pass):
  - `echoes_alive` tooltip: "Each Echo that comes home earns Ase."
  - `carried_advance` tooltip: "Ase and Ekwan the party carried home earlier are taken off the stage payout, so nothing is earned twice."
  - lost-names note: "Kofi did not come home." / "Ama and Kofi did not come home." / "Ama, Kofi and Esi did not come home."
- All copy stays in `ui/components/PayoutCausePresentation.gd`.

## Direction E cards, Part A (UI, 2026-10-24)

- Mid-stage win card (a win with no fight rows and no stage rows): party and state, then up to three lines, each only when the snapshot has data. No Ase, no ledger, no chips. The rows rise in turn (alpha fade, 100 ms apart).
- Stage-ending card: the home sequence (party first, each Echo "home" in turn at 130 ms, a lost Echo holds 550 ms and is named once, then the count "home N of M" completes, then the quiet Ase figure fades in at 16 px, muted). The "Echoes alive" chip gives way to the count.
- Motion: reduced motion shows the final state at once. The one flag is `StopMarkMotion.reduced` (nothing sets it yet). A tap or key press skips to the final state and never consumes the input. Footer buttons stay usable.
- PROPOSAL placeholders (not approved copy), all in `PayoutCausePresentation`: `THREAD_WHOLE`, `INTEL_LEARNED`, `CHANGE_LINES` ("<name> fell." / "held back." / "was shaken."), `HOME_TAG`.
- PLACEHOLDER derivation: the Thread line shows when `echoes_survived` equals the number of roster Echoes in `actors` (not ally, not spirit) and the stage `echoes_alive` row has an empty `lost` list. No Thread field exists.
- Data gaps (BLOCKED, nothing invented):
  - Objective story mark ("found and overcome"): the combat resolve snapshot has no flag that this fight overcame an objective and no objective description. Not built.
  - Intel: no `intel_gained` field on the combat victory card (`intel_count` is scout-return only). The line is built behind `intel_gained` > 0 and stays hidden today. The key is requested from the backend.
  - Thread: no field (see the derivation above).
  - "What the fight changed": no event field. The line comes from `emotion_summary` tag and direction only, and shows only for a real event.
- Carried Ekwan: on a scout return or forced retreat, `ekwan_awarded` above 0 shows "Ekwan earned" with its amount in the ledger, no row, no (i).

## Carried home and the retreat button, Part B (UI, 2026-10-24)

- Surfaces extended (no new flow, no action changed): `ReturnHomeModal` (the return-home confirmation, after `stage.return_home`; Leave still dispatches `stage.confirm_return_home`) and `PrebattleModal` (the retreat decision). A new `CarriedHomePanel` sits in both.
- "Carried home" shows only when Ase or Ekwan is above 0, each line only above 0, and then always with the comparator: the party and its state, "The stage waits." and the advance note. A return that carries 0 shows only "The stage waits." (when something is overcome). No zero rows, no totals, no "of N". Only a successful return shows the panel.
- Retreat button: reads `retreat_affordable` (a missing key reads as affordable) and `retreat_ase_cost`. Not affordable: disabled, price and "Not enough Ase" in the text. After a refused dispatch `retreat_denied` shows one plain line with both numbers from data.
- PROPOSAL placeholders (not approved copy), all in `ui/components/CarriedHomePresentation.gd`: carried title, advance note, "The stage waits.", "With the party", "Going home costs nothing.", "Not enough Ase", the denied line.
- BLOCKED: no intel-gained field on either snapshot, so the comparator has no intel line.

## QA fixes D1 and D3 (UI, 2026-10-24)

- D1: on a stage-ending card with the home sequence, the first-time ledger stays closed while the sequence runs. It opens when the sequence ends, when the player skips it by tap or key, or at once under reduced motion. `resolve.ledger.mark_seen` is sent when the ledger opens, once. A new snapshot mid-sequence drops the old wish with no emit. Cards with no home sequence open the ledger at once. After it opens, the screen scrolls only as far as needed to keep the "home N of M" line visible.
- D-17 (PROPOSAL, pending Jeff's read): the pace rank-cause note ("The party's effort earned this rank") is not shown on a mid-stage win, because that card shows no rank letter and the note would have no anchor. It stays on the stage-ending card next to the Rank chip.
- D3: the Pace UI tests now use the stage-ending card and assert `is_visible_in_tree()`, not the `visible` property.

## D-18: placeholders replaced by real fields (UI, 2026-10-25)

- Thread line: reads `data.thread_whole` (bool, combat victory card). It shows "The Thread is whole so far." only when true. False or missing hides it. The derivation from `actors` is deleted.
- Story mark: reads `data.objective_overcome` ({ index, type, label }, present only when this fight overcame an objective). It shows "Found and overcome." plus the label from data. The index and the type are never shown.
- Intel line: reads `data.intel_gained` (an int; the key exists only above 0). Hidden when missing or 0. No fight reveals a situation today, so it does not show in real play; fixtures prove it.
- `echoes_alive` params: `lost` holds every death of the stage so far, and `alive` excludes them. The home sequence reads the params only. A lost name with no row in this fight (a death in an earlier fight) shows once in a note under the rows, and the ledger row drops its own note.
- Still PROPOSAL placeholder copy (Jeff owns it): "Found and overcome." and the intel line text.
- GAP for Jeff's copy: no wording exists for a broken Thread, so the Thread line is simply hidden when `thread_whole` is false.

## Return-home confirmation before the action (UI, 2026-10-25)

- Defect: `ReturnHomeModal` showed the carried panel only for `result.success`, but the core writes `return_home_result` only on a FAILED escape (`VentureController.gd`, "Escape failed" branch). A success goes straight to the scout-return card. The panel never showed in production.
- Fix (Jeff's choice): the Return button on `StageExploreScreen` opens the confirmation first and dispatches nothing. The panel shows `carry_home_preview` (each carried line only above 0) and the comparator (the party and its state, "The stage waits.", "Going home costs nothing."). With 0/0 or no preview it still opens, with the comparator only.
- Only Confirm sends `stage.return_home`, once (a second press does nothing). Cancel and Esc dispatch nothing and close the panel. Both buttons are 56 px high. Focus starts on Cancel.
- The failed-escape display is unchanged: "Blocked", no carried figure, Continue sends `stage.dismiss_overlay`.
- PROPOSAL placeholder copy in `CarriedHomePresentation.gd`: "Take the party home?", "Go home", "Stay".

## Real-host test and dead branch removed (UI, 2026-10-25)

- New test `payout_ui/return_home_through_real_shell_and_host`: a real stage, a real `RealmShell` and `StageExploreScreen`, a real `ModalHost`, the real Return button. It proves the payload carries `carry_home_preview` and `party_preview` from the snapshot (no private field set), Confirm sends one `stage.return_home`, Cancel and Esc send nothing and return focus to the Return button, and the failed-escape result modal shows with Continue. Not testable headless: the real mouse click (the test emits `pressed`).
- Removed `StageExploreScreen._show_return_home_overlay`, including its dead `stage.confirm_return_home` success branch. Grep found no caller in `ui/`, `core/` or `tests/`. The core still handles `stage.confirm_return_home` (`VentureController`), and `venture_char` tests cover it; nothing there changed.
