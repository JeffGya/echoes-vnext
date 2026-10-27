# V2-ECONOMY-004 step 6.3 build: early-leave and retreat copy and screens (UI only)

Rules: D-103 to D-109. Copy: D-107 (Jeff's words, used exactly). Nothing is committed. `core/`, `data/` and Notion are untouched.

## What changed

| Surface | Change |
|---|---|
| Confirmation (`ReturnHomeModal`) | Title, question, gathered line, risk line, escape line, keeps line, `To the Sanctum` and `Stay`. The party list, the cost line and the advance note are gone. Three new labels in the `.tscn`: `GatheredLabel`, `RiskLabel`, `KeepsLabel`. |
| Gathered line | `gathered_line(ase, ekwan)`. A clause with 0 is dropped with its "and". Both 0: no gathered line and no risk line. `carry_home_preview.nothing_new` true: no gathered line and no risk line. |
| Failed escape (result mode) | Subtitle `No way out.`. Body from core. Title is the same as the confirmation. |
| Return card (`ResolveScreen`, scout return) | New label `OutcomeLine` in the header. Text by `data.settle_outcome`. Rows with cause `settle_*` are not drawn (no row label). The amount line shows even at +0, as a line with nothing to open. |
| Retreat card (`ResolveScreen`) | New branch for `run_type == "retreat_return"`: title, body, extra line by `can_reenter`, one button with the label from the action. The body area is hidden and the card is 600 by 320. |
| Stage-end ledger | `carried_advance`, `partial_return_home`, `partial_retreat` removed from `PayoutCausePresentation`. New memo cause `settled_on_leave`: row name `Settled when you left`, tooltip `These were already taken when the party left earlier.`. |
| Combat board retreat button | `Retreat (10 Ase)` only. `retreat_tier_label` and `carry_retreat_preview` are no longer read. The unaffordable state keeps its second line `Not enough Ase` (see ASSUMED). The denied line is unchanged. |
| `PrebattleModal` | `CarriedPanel` removed. Payload has no `carry` and no `party`. |
| `StageExploreScreen` | Return button text is `To the Sanctum`. `_cached_party_preview` and `_array_or_empty` removed (no reader left). |
| Deleted | `ui/components/CarriedHomePanel.gd`, `.gd.uid`, `.tscn`. The strings file keeps its name `CarriedHomePresentation.gd` (a rename touches many files; not needed). |

Removed strings: `Going home costs nothing.`, `The rest is earned when the stage is finished.`, `The stage waits.`, `Carried home` (all uses), `Return Home`, `Go home`, `Escape guaranteed`, `Chance of failure`, `With the party`.

## Full-repo audit of removed names

| Name | Result |
|---|---|
| `carry_retreat_preview` | Gone from `ui/`. Remains in `CONVENTIONS.md:1006` (doc says `{ase, ekwan, overcome, total}`; backend now always sends 0) and in core and its tests. I did not edit CONVENTIONS.md. |
| `carried_advance`, `partial_*` | Gone from `ui/`, `scripts/` and `tests/ResolvePayoutUITests.gd`. Remain only in core, core tests and story docs (history). |
| `integration-map.md` row for ECONOMY-004 | Still mentions the old model in prose. Not edited. |
| `docs/stories/v2-payout-explanation/mockups/*.html` | Still show "Carried home". Mockups are history. Not edited. |

## Test changes (each with its reason)

File: `tests/ResolvePayoutUITests.gd`. Suite `payout_ui`: 41 of 41 pass (was 38).

| Test | Change | Reason |
|---|---|---|
| `fight_card_rows_and_total`, `buttons`, `tooltip_rules`, `other_cards`, `rail_chips`, `ledger_*`, 6 more | Fixture cause `partial_return_home` replaced by `settled_on_leave`, label `Settled when you left`. | `partial_return_home` has no entry any more. The tests need some cause that has a tooltip. |
| `stage_end_card...` | The negative `carried_advance` row became the zero-delta `settled_on_leave` memo row. Asserts `+0 Ase`, the label and a tooltip button. | Backend: no `carried_advance` row; memo row has delta 0. |
| `tooltip_text_matches_approved_wording` | Removed the three old causes. Added `settled_on_leave`. Row names updated. Old causes must have no entry. | D-107 items 3, W3, W4. |
| `carried_line_absent_at_zero...` | Deleted with the panel. Replaced by `strings_match_jeffs_words_exactly`. | The panel no longer exists. |
| `return_home_confirmation_opens_before_dispatch`, `..._confirm_once...`, `..._through_real_shell_and_host` | Payload has no `party`. Asserts it is absent. | Party list removed from the confirmation. |
| `return_home_confirmation_zero_carry_and_failed_escape` | Rewritten for the new labels: 0/0, no preview and `nothing_new` hide gathered and risk lines; failed escape shows subtitle and the core body. | New panel rules. |
| `retreat_button_price_affordable_and_denied` | Exact text `Retreat (13 Ase)`, no newline. Carry-preview checks replaced by: payload has no `carry`/`party` even when the snapshot sends them. | D-107 addendum 2. |
| `carried_scenes_hold_no_amount_text` | Panel scene removed from the path list. | Panel deleted. |

New tests: `strings_match_jeffs_words_exactly`, `no_percent_home_or_stage_in_these_surfaces` (no `%`, `home`, `stage`, `odds`, `chance`, `percent` or `n/m` in the string tables, the confirmation in 5 states, the 4 return cards, both retreat cards, the pre-battle modal in 3 states; also the Return button text), `removed_strings_and_fields_are_gone_from_ui` (scans every `.gd` and `.tscn` under `ui/`), `return_card_outcome_line_and_amounts` (4 outcomes), `retreat_card_renders_and_button_sends_retreat_return`, `retreat_card_through_real_shell_and_host`.

Probe that the tests can fail: I changed two strings and disabled the retreat branch. 4 tests failed. Files restored (`cmp` clean).

## Runs (own `ECHOES_TEST_SAVE_DIR`, deleted before each run)

| Command | Result |
|---|---|
| compile check, `--import` | 0 errors |
| `=realm_ui,payout_ui,foundation_ui,stage,unified_resolve,summon_price_ui` | 111 of 111 |
| `=stage_stop_ui,stage_camera,combat_ui` | 128 of 128 |
| `scripts/check-shard-map.sh` | OK (137 suites) |

Not run: the full suite, `reward`, fingerprint suites (not asked). `payout_ui` joins no shard change.

## Screenshots (`scripts/screenshot.gd`)

New or changed fixtures: `carry_return_home`, `carry_return_home_ase_only`, `carry_return_home_nothing_new`, `carry_return_home_failed`, `return_card_none|some|all|nothing_new`, `retreat_card_no_reenter`, `retreat_card_reenter`, `retreat_button`; `resolve_stage_end` and `resolve_retreat_zero` updated. Removed: `carry_retreat`. 14 fixtures at compact, standard and wide were rendered without error. I read compact and standard images for the confirmation, return card, retreat card and retreat button.
Finding fixed from the images: the confirm button `To the Sanctum` was cramped at 150 wide. It is 200 wide now.
Touch targets (from the scenes): confirm 200x56, cancel 150x56, retreat button 150x56, card button min height 56, Return button min 140x56. All at or above 48x48 and 8 apart.

## Findings not changed (report only)

1. Android back: `AppRoot._handle_go_back_request` returns at once while a modal is open (`ui/AppRoot.gd:421`). On the confirmation, the hardware back does nothing; the player must press `Stay`. Esc works (it is Cancel). On the retreat card the same applies: only `Leave` closes it.
2. Words "home" and "stage" remain elsewhere on the same cards, outside this step's strings: `echoes_alive` row name `Echoes home` and its tooltip, the "did not come home" line, the `home` count tag, the replay tooltip (`The whole stage earns less...`), `Something new is known about the stage.`, and the defeat tooltip `The party lost, but...`. They are older placeholders. The new test does not cover them.
3. The scout-return card header still says `Scout Return` and `N situations revealed` (existing, not in the brief).
4. A return card with `ekwan > 0` and no other rows opens a ledger that holds only the total and the Ekwan line.
5. `retreat_tier_label` and `cta.retreat.success_pct` are still sent by core; `ui/` reads neither now.

## Docs

`CONVENTIONS.md` line 1006 still lists `carry_retreat_preview`. It needs one edit by whoever owns the snapshot table.

## OPEN — questions and assumptions
ASSUMED: The action-bar Return button on the explore screen reads `To the Sanctum` (Jeff's confirm label) | WHY: `Return Home` had to go and Jeff gave no string for that button; a long text breaks the 140-wide button on compact | WRONG IF: Jeff wants `Return to the Sanctum` or other words there.
ASSUMED: When both gathered amounts are 0 (and `nothing_new` is false), the gathered and risk lines are hidden | WHY: nothing is in the packs, so there is nothing to lose; same as the `nothing_new` rule | WRONG IF: Jeff wants the risk line shown anyway.
ASSUMED: `nothing_new` true hides the gathered and risk lines (as the brief says), even when ase or ekwan is above 0 in the same preview | WHY: the brief states it | WRONG IF: the backend can send `nothing_new` true with a non-zero amount that should show.
ASSUMED: The disabled retreat button keeps its second line `Not enough Ase` | WHY: the brief removes only the two odds lines; the line carries the disabled state without colour | WRONG IF: Jeff wants `Retreat (10 Ase)` alone in every state.
ASSUMED: The `none` and other return cards show amounts through the existing earnings line (`+N Ase`, `+N Ekwan` only above 0), disabled with nothing to open when there are no rows | WHY: "existing format"; the brief says `none` still shows +0 | WRONG IF: Jeff wants `+0 Ekwan` shown on `none` too.
ASSUMED: The retreat card is a small 600 by 320 card with no body area | WHY: it has no rows or emotion list | WRONG IF: Jeff wants the full card size.
ASSUMED: Confirmation title is the same in failed-escape (result) mode | WHY: no separate title given | WRONG IF: the failed escape needs its own title.
BLOCKED: none.
