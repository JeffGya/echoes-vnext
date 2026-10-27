# V2-ECONOMY-004 step 7.F build: UI for the 7.E fixes (D-119)

Nothing is committed. `core/`, `data/` and Notion are untouched. No new player text. Written in STE. Skills: `ponytail`, `game-ui-ux-echoes`.

## Result

| Task | Result |
|---|---|
| 1. Open-fight line | `ResolveScreen._render_standoff` sets `_open_fight_line.visible = bool(data.get("fight_returns", true))`. False hides only that line. The packs line and the calm line stay. A card without the key shows the line. |
| 2. Final-win card | No code change. `_build_ledger` totals `ase_awarded + _gathered_ase + stage_payout_ase`; with no `encounter_gathered` row `_gathered_ase` is 0, so the total is the payout. The mid-stage rule still keys on the `encounter_gathered` row (existing test `won_fight_with_gathered_row_keeps_the_midstage_layout` passes). |
| 3. Count tooltip | See finding 1. No change. |
| 4. Screenshots | New fixture `standoff_fight_gone` (`fight_returns` false). `_standoff_card` takes `fight_returns` (default true). Rendered `standoff_calm` (true) and `standoff_fight_gone` (false), compact and standard, and viewed both. The card has the same size in both. With the line hidden the card is one line shorter and the lines stay centred. Compact and standard look the same at 1280x720, as in 7.D. |

## Tests (`payout_ui`, 56 before, 58 now)

- `standoff_open_fight_line_only_when_the_fight_returns`: true shows the exact line; false hides it and keeps the packs and calm lines; a card with the key erased shows it.
- `final_win_card_total_is_the_stage_payout_without_double_count`: the F1 shape (`stage_payout_ase` 26, no `encounter_gathered` row, `ase_awarded` 0) gives `+26 Ase`, two stage rows, no fight rows.
- Probe: I removed the `visible` line. The first test failed (57 of 58). I restored the file.

Own `ECHOES_TEST_SAVE_DIR=/tmp/echoes-7f-saves`, deleted before each run and at the end. Compile check: 0 errors.

| Filter | Result |
|---|---|
| `=payout_ui` | 58 of 58 |
| `=realm_ui,payout_ui,foundation_ui,stage,unified_resolve,summon_price_ui` | 128 of 128 |
| `=retreat,pending_result,econ_char` | 155 of 155 |
| `check-shard-map` | OK (137 suites) |
| `--import` | no error |

Files: `ui/screens/venture/ResolveScreen.gd` (one line), `tests/ResolvePayoutUITests.gd`, `scripts/screenshot.gd`.

## Findings

1. **Count tooltip: wording is true, the row label can mislead.** `Fights won on this path: %d.` counts fights, and `params.count` now counts all fight rows. It stays true. The row label is `Fights won`, and the amount beside it covers only the open (unsettled) fights. After a retreat that settled some packs, the row can read `Fights won +6 Ase` with the tooltip `...: 4.` The count and the amount then differ, and a player may think each fight paid 1.5 Ase. The label does not say the amount is only for fights still in the packs. No new text written; Jeff decides on wording or a second line.
2. The wide profile was not rendered (the brief asked for compact and standard).
3. Not mine, still open from 7.D: `_build_midstage` calls `step.parallel()` on a `PropertyTweener` (finding 1 of the 7.D build). Not touched.

## Ponytail: skipped

- No change to `_build_ledger` or `_gathered_ase` (the logic already holds).
- No new copy and no new tooltip for the count mismatch.
- No second screenshot fixture for the final-win card (the existing `resolve_stage_end` covers it).

## OPEN — questions and assumptions

ASSUMED: The F1 test uses `ase_awarded` 0 on the final card. | WHY: the brief says the total equals the stage payout, and the core fix writes no fight row. | WRONG IF: core sends a non-zero `ase_awarded` on that card for a reason other than the fight (then the total adds it, as before).
BLOCKED: Should the `Fights won` row label or tooltip say that the amount covers only fights still in the packs? | CHECKED: `PayoutCausePresentation.gd`, `phase7-copy-final.md` strings, 7.E build. | NEED: Jeff's wording decision (player text).
