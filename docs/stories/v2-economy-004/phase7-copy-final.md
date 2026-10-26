# Phase 7 final copy (standoff, warning, packs, situations)

> AGENT-WRITTEN in Jeff's tone. Jeff may edit after his play test. None of this is approved copy.
> Player-facing text only. This file is not STE. Constants are proposed names; `mechanics-developer` / `ui-ux-designer` may rename them.
> Sources read: ANSWERS #86, #87; decisions D-104..D-116; phase6-ux-copy-proposals; phase7-encounter-pay-design 5; phase7-forced-retreat-design 6; phase7-forced-retreat-feel-review; PayoutCausePresentation.gd; CarriedHomePresentation.gd.

Placeholders: `%s` is a display name (no id). `%d` is an amount or count from the snapshot.

## 1. Standoff card (D-116)

| Slot id | Constant | FINAL line | Alternative |
|---|---|---|---|
| standoff.title | `StandoffPresentation.TITLE` | Nobody moved | Standoff |
| standoff.body.generic | `BODY_GENERIC` | Neither side would strike. The party stepped back. | Nobody wanted to go first. The party backed off. |
| standoff.body.froze_one | `BODY_FROZE_ONE` (%s) | %s could not move. The party stepped back. | %s froze, and the others waited. The party stepped back. |
| standoff.body.blocked | `BODY_BLOCKED` | No one could get through. The party stepped back. | The way was shut on both sides. The party stepped back. |
| standoff.body.froze_two | `BODY_FROZE_TWO` (%s, %s) | %s and %s could not move. The party stepped back. | %s and %s froze. The party stepped back. |
| standoff.packs | `PACKS_LINE` | Their packs are as they were. | Nothing in the packs changed. |
| standoff.open_fight | `OPEN_FIGHT_LINE` | The task is still there. | We are not done here. |
| standoff.calm | `CALM_LINE` (%s) | %s breathed out. | %s is calmer now. |
| standoff.repeat_1 | `REPEAT_HINT_1` | It went the same way last time. | This is not working. |
| standoff.repeat_2 | `REPEAT_HINT_2` | Maybe they need rest. | Maybe try it another way. |
| standoff.button.path | `BTN_PATH` | Back to the path | Step back |
| standoff.button.sanctum | `BTN_SANCTUM` | To the Sanctum | Back to the Sanctum |

Rules for use: `calm` shows only when fear really fell, and only with the names of the Echoes it fell for. `froze_*` and `blocked` show only when a recorded event backs them (D-116 b). Otherwise `generic`. The button `To the Sanctum` reuses `CarriedHomePresentation.CONFIRM_LABEL` (same words, one source).

## 2. Warning on the board (D-116 a)

| Slot id | Constant | FINAL line | Alternative |
|---|---|---|---|
| warning.level_1 | `WARN_LEVEL_1` | Nobody is moving. | It has gone quiet. |
| warning.level_2 | `WARN_LEVEL_2` | Nobody wants to go first. | This is going nowhere. |
| warning.bark | `WARN_BARK` (%s optional) | Not yet. I can't. | %s: Wait. Not yet. |

The bark is one short line in the voice of the Echo that froze. The language story may replace it with per-Echo barks.

## 3. Prebattle

| Slot id | Constant | FINAL line | Alternative |
|---|---|---|---|
| prebattle.stalled_before | `PREBATTLE_STALLED` | They stalled here before. | It went quiet here last time. |

## 4. Packs and ledger causes

Row names follow the existing `ROW_NAMES` / `TEXT` pattern in `PayoutCausePresentation.gd`. A tooltip never uses "banked", "settled" or "roll" (design 5.4).

| Slot id | Constant | Part | FINAL line | Alternative |
|---|---|---|---|---|
| cause.encounter_gathered | `ROW_NAMES` | label | Fight won | Fight overcome |
| cause.encounter_gathered | `TEXT` | tooltip | It goes in their packs. It is safe only when the party gets out. | It goes in their packs. It is not safe yet. |
| cause.found_gathered | `ROW_NAMES` | label | Found | Found on the path |
| cause.found_gathered | `TEXT` | tooltip | Found along the way. It goes in their packs. | The party found this on the path. It goes in their packs. |
| cause.encounters_overcome | `ROW_NAMES` | label | Fights won | Fights overcome |
| cause.encounters_overcome | `ENCOUNTERS_COUNT` (%d) | count line (tooltip) | Fights won on this path: %d. | The party overcame %d fights here. |
| cause.found_banked | `ROW_NAMES` | label | Found on the path | Found along the way |
| cause.found_banked | `TEXT` | tooltip | Gathered along the way and carried to the Sanctum. | The party found this on the path and carried it out. |
| cause.empty_row | `TEXT["nothing_overcome_yet"]` replacement | row line | Nothing was gathered. | The packs were empty. |

Note: `encounters_overcome` gets one count line, not one line per count. It avoids a plural rule for the number 1.

## 5. Defeat

| Slot id | Constant | FINAL line | Alternative |
|---|---|---|---|
| defeat.packs_lost | `PACKS_LOST_LINE` | The party fell, and the packs were lost. | The packs were lost. |

Jeff's line `This one was lost, but we still earn a small part.` stays for the consolation row. This line goes on the card as a plain statement, with no blame.

## 6. Situation cards (found Ase goes in the packs, not the balance)

| Slot id | Constant | FINAL line | Alternative |
|---|---|---|---|
| situation.money | `SITUATION_MONEY` (%d) | They found %d Ase. It goes in the packs. | The party found %d Ase. It is in the packs now. |
| situation.claimant_good | `SITUATION_CLAIMANT_GOOD` (%d) | The party was given %d Ase for the way. It goes in the packs. | %d Ase was given for the way. It goes in the packs. |

## 7. Panel (return confirmation)

| Slot id | Constant | FINAL line | Alternative |
|---|---|---|---|
| panel.packs_empty | `GATHERED_EMPTY` | Nothing is in their packs. | Their packs are empty. |

The filled line `In their packs: 12 Ase and 3 Ekwan.` already exists in `CarriedHomePresentation.gathered_line`. D-110 F1 still holds: on an empty leave the panel may show no outcome line. This empty variant is for the panel only.

## Tone notes

- Short, plain, concrete sentences. One fact per sentence.
- A quiet "they" or "the party" for the group; "we" only where Jeff already used it (`The task is still there` stays neutral on purpose).
- No blame. A standoff is not a failure and a defeat line states what happened, not who erred.
- Nobody explains the simulation. The card names a cause only when an event backs it.
- "Back to the path" and "the Sanctum" are the only places. "Packs" is where unsafe earnings sit. "Lost" is what is not carried. "Earned", "gathered" and "found" are the gain words.
- Amounts come only from supplied `%d`. No percent, odds or fractions anywhere.

## Forbidden words check

| Check | Result |
|---|---|
| "home" in any final or alternative line | None |
| "stage" in any final or alternative line | None |
| "Leave" as a button | None (buttons are `Back to the path`, `To the Sanctum`; alternatives `Step back`, `Back to the Sanctum`) |
| "banked", "settled", "roll" in player text | None |
| The percent character | None. The only `%` uses are the placeholders `%s` and `%d` |
| Numbers other than supplied amounts | None |

## OPEN — questions and assumptions

- ASSUMED: The `calm` line takes a joined name list ("A and B breathed out") and so reads correctly for one or two Echoes, because "breathed out" has no number agreement. | WRONG IF: the code passes a list of three or more names, or the line needs a plural form.
- ASSUMED: The claimant's gender is not set in the snapshot, so the claimant line uses the passive "was given". Design 5.4 said "She gave them". | WRONG IF: Jeff wants the claimant named or gendered in the line.
- ASSUMED: `froze_one` / `froze_two` cover fear refusal only; `blocked` covers guards and positions. A mixed cause uses `generic`. | WRONG IF: the cause event has more than these three kinds.
- ASSUMED: The warning bark is one fixed line for now. The `%s` is optional and unused in the final. | WRONG IF: the language story wants a per-Echo bark table first.
- ASSUMED: The prebattle line has one text for the second and later visits. Feel review proposed a "twice" variant (`It went the same way twice.`); I did not write it. | WRONG IF: Jeff wants a third-visit variant.
- ASSUMED: `Fight won` does not conflict with the older rule that objectives are "found and overcome", never "won" (PayoutCausePresentation header, D-04). I used "won" for fights only, as design 5.4 did, and "overcome" in alternatives for consistency. | WRONG IF: Jeff wants "won" removed from all rows.
- BLOCKED: none.
