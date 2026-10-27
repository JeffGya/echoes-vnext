# V2-ECONOMY-004 step 8.B: UI side of the technical debt round

Files changed: `ui/AppRoot.gd`, `ui/components/ModalHost.gd`, `ui/overlays/realm/ReturnHomeModal.gd`, `ui/screens/venture/ResolveScreen.gd` (one comment), `scripts/screenshot.gd`, `tests/ResolvePayoutUITests.gd`. No `core/`, `data/` or Notion change. No new player text.

## Follow-up 37: hardware Back with a modal open (D-121)

- `AppRoot._handle_go_back_request` still returns at once when a modal is open. Before it returns, it calls `ModalHost.handle_go_back()`. AppRoot dispatches nothing here.
- `ModalHost.handle_go_back()` calls `handle_go_back` on the open modal only if the modal has that method.
- `ReturnHomeModal.handle_go_back()`: in confirm mode it runs the Cancel path (the same as Stay and Esc). It closes the modal and sends no action. In result mode (failed escape) it does nothing.
- The retreat card, the standoff card and every other modal have no `handle_go_back`. They stay unchanged: Back does nothing.

## Follow-up 45: Ekwan-only ledger

- Fixture added: `return_card_ekwan_only` (`scripts/screenshot.gd`). Rendered at compact and standard, ledger open.
- Result: the layout is correct. The ledger shows `Total earned = 0 Ase` and `Ekwan earned +5 Ekwan`. No row is missing or cut. The earnings button is full width with min height 48 (scene value). No fix made.
- Test: ledger opens, no breakdown or stage rows, total and Ekwan line right, button min height at least 48.

## 8.A leftovers

- `_gathered_ase` already read `ase_gathered` first and falls back to the `encounter_gathered` row. I kept the fallback, so one row gives the same total. Only the doc comment changed.
- Banner `surface`: the combat card never shows it. The fight card banner is `VICTORY` or `DEFEAT` (`ResolveScreen.gd:253`). Only `_render_situation_result` reads `surface`, and it gets the situation type from `VentureResolveSnapshotBuilder`, not the fight value. So "combat" and the objective type are not visible, and no "home" or "stage" word can come from them. A test now proves the fight banner ignores `surface`.
- `retreat_tier_label` in `scripts/screenshot.gd`: the line is already gone. Grep finds it only in tests that assert it is absent. No edit.

## Tests added (`payout_ui`, 5 tests; the suite is 63)

| Test | Proves |
|---|---|
| `back_closes_the_confirmation_and_ignores_the_result_and_cards` | Back closes the confirmation with no action. Back changes nothing on the failed-escape display, the retreat card and the standoff card. |
| `back_with_no_modal_still_reads_the_snapshot_back_slot` | With no modal and no or a disabled back slot, nothing happens. |
| `ekwan_only_return_card_opens_a_ledger_with_total_and_ekwan_line` | Follow-up 45 layout facts. |
| `gathered_total_reads_the_core_key_over_two_rows` | Two `encounter_gathered` rows (6 and 4) with `ase_gathered` 10 give +10. One row, no key, gives +6. |
| `fight_card_banner_ignores_the_surface_word` | Banner stays VICTORY or DEFEAT for `combat`, `recover`, `purify_shrine`. |

Mutation check: with `handle_go_back` disabled, the first test fails (`confirmation: open=true`).

Limit: the no-modal test cannot drive an enabled `nav.back`, because that needs a live `FlowRuntime`. That path is unchanged code.

## Verification

| Command | Result |
|---|---|
| `--check-only` | clean |
| `=realm_ui,payout_ui,foundation_ui,stage,unified_resolve,summon_price_ui` | 133 of 133 |
| `=retreat,pending_result,econ_char` | 160 of 160 |
| `=stage_stop_ui,stage_camera,combat_ui` | 128 of 128 |
| `scripts/check-shard-map.sh` | OK (137 suites) |
| `--import` | no errors |

Not run: full suite, `reward`, fingerprint suites. Skills used: `game-ui-ux-echoes` (aesthetic and target sizes), `ponytail`.

## OPEN — questions and assumptions
ASSUMED: The failed-escape display (result mode of the return modal) ignores Back | WHY: D-121 names only the confirmation, the retreat card and the standoff card; that display has one Continue button and no Stay | WRONG IF: Jeff wants Back to act as Continue there.
BLOCKED: none.
