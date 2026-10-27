# V2-ECONOMY-004 step 7.D build: packs, standoff and warning in the UI

Rules: D-107, D-111, D-113 to D-118, ANSWERS #86 and #87. Copy: `phase7-copy-final.md`, used exactly. Nothing is committed. `core/`, `data/` and Notion are untouched.
Written in STE. Skills used: `game-ui-ux-echoes` (rules), `ponytail` (smallest change).

## 1. What the UI shows now

| Surface | Result |
|---|---|
| Standoff card (`run_type == "standoff"`) | New branch `ResolveScreen._render_standoff`. Compact card: title, body by `cause`, packs line, open-fight line, calm line (only with names), repeat hint by `standoff_count`. First standoff: one button `Back to the path`. From the second (`can_go_sanctum`): `To the Sanctum` joins on the left. Each button emits its slot's action dict whole (the Sanctum one carries `to_sanctum`). No `Leave` anywhere. Focus starts on the path button. |
| Dead code | `forced_retreat` branches removed from `_render` and `_render_scout_return`. Audit of the repo: no `forced_retreat` or `Forced Retreat` is left in `ui/`, `scripts/` or the docs that describe screens. The rest are core names (`_resolve_forced_retreat`, reason `no_progress_forced_retreat`), core tests and old story files. |
| Stage explore | `return_confirm_requested` opens the existing return confirmation once. A refresh that still carries the flag does not open it again. The flag falling resets it. The focus grab for Advance is skipped while the flag is set. |
| Confirmation | Reads `carry_home_preview.gathered`. Line `In their packs: <Ase> Ase and <Ekwan> Ekwan.`. With nothing gathered: `Nothing is in their packs.` and no risk line. The escape line, the risk line and the keeps line (D-107) are unchanged. |
| Board warning | `stall_level` 1: `Nobody is moving.` Level 2: the line becomes `Nobody wants to go first.` and one bark `Not yet. I can't.` from `stall_froze_name` through the existing `BarkPopupLayer`. Info blue `#7AB5C8` text on a dark pill with a blue border. 0.4 s `TRANS_SINE` / `EASE_IN_OUT` fade in. Level 0 hides it at once. A repeat snapshot at the same level does not restart the fade. |
| Prebattle modal | `They stalled here before.` when `stalled_before` (payload key added by `CombatBoardScreen`). |
| Won fight card | Keys on the cause `encounter_gathered`, not on "no rows". It keeps the mid-stage layout (party rows, story lines, no chips) and shows the row `Fight won +6 Ase` with its tooltip. Any other row makes it a ledger card as before. |
| Money card | The total reads `ase_gathered` (`+12 Ase`, was `+0`). Row `Found`. Line `They found 12 Ase. It goes in the packs.` The card now builds a ledger (it had none before). |
| Good-Claimant card | Line `The party was given 20 Ase for the way. It goes in the packs.` from `ase_gathered`. |
| Defeat card | Line `The party fell, and the packs were lost.` when the `packs_lost` row is present. The row itself is not drawn in the ledger (its `delta` is 0 and the line says it). |
| Ledger causes | Labels and tooltips for `encounter_gathered`, `found_gathered`, `encounters_overcome` (count line from `params.count`), `found_banked`. The empty row reads `Nothing was gathered.` (label and tooltip). Event cards show the base amount. |

## 2. Files changed

| File | Change |
|---|---|
| `ui/components/StandoffPresentation.gd` (+ `.uid`) | New. Standoff, warning, bark and prebattle strings. Pure helpers `body`, `calm_line`, `repeat_hint`. |
| `ui/components/PayoutCausePresentation.gd` | New row names and tooltips, `ENCOUNTERS_COUNT`, `PACKS_LOST_LINE`, `SITUATION_*`, `NOTHING_GATHERED`. |
| `ui/components/CarriedHomePresentation.gd` | `GATHERED_EMPTY`. |
| `ui/overlays/realm/ReturnHomeModal.gd` | Reads `gathered`. Empty variant. |
| `ui/overlays/realm/PrebattleModal.gd` / `.tscn` | `StalledLabel` and the `stalled_before` payload key. |
| `ui/screens/combat/CombatBoardScreen.gd` / `.tscn` | `StallPanel` + `StallLabel` (in the scene), `_apply_stall_warning`, `_stall_bark`, payload key. |
| `ui/screens/venture/ResolveScreen.gd` / `.tscn` | Standoff branch and nodes (`StandoffLines` with four labels), ledger total, mid-stage rule, found, claimant and packs-lost lines. |
| `ui/screens/venture/StageExploreScreen.gd` | `_sync_return_confirm`. |
| `scripts/screenshot.gd` | 12 new fixtures (below). |
| `tests/ResolvePayoutUITests.gd` | 13 new tests, 5 changed fixtures. `tests/Stage004SeamTests.gd`: one fixture line. |

## 3. Tests

Own `ECHOES_TEST_SAVE_DIR=/tmp/echoes-d-saves`, deleted before each run. Compile check: zero errors. `--import`: no error. `scripts/check-shard-map.sh`: OK (no new suite).

| Filter | Result |
|---|---|
| `=realm_ui,payout_ui,foundation_ui,stage,unified_resolve,summon_price_ui` | 126 of 126 |
| `=stage_stop_ui,stage_camera,combat_ui` | 128 of 128 |
| `=retreat,pending_result,econ_char` | 151 of 151 |
| `=payout_ui` alone | 56 of 56 (43 before, 13 new) |

New tests (all in `payout_ui`): `standoff_strings_match_the_copy_file_exactly` (each line written out, plus the card lines), `standoff_card_first_has_one_button_second_has_two` (labels, 56 high, 8 gap, whole dict, `to_sanctum`, hints, no `Leave`, no VICTORY/DEFEAT, layout does not leak), `standoff_body_by_cause_and_calm_line_only_with_names`, `standoff_card_through_real_shell_and_host` (real `RealmShell`, `ModalHost`, real producer, both cards), `board_warning_levels_fade_clear_and_bark_once`, `prebattle_shows_the_stalled_line_only_when_flagged`, `return_confirm_requested_opens_the_confirmation_once` (real stage fixture; refresh, cancel, new request, Confirm once), `confirmation_shows_the_gathered_block_or_the_empty_line` (Cancel sends nothing, Confirm sends once), `found_ase_cards_show_the_packs_line_and_total`, `defeat_card_shows_packs_lost_line_only_with_the_row`, `won_fight_with_gathered_row_keeps_the_midstage_layout`, `packs_cause_names_and_tooltips_are_exact`, `phase7_strings_no_home_stage_percent_or_leave`.

Changed tests, each with its reason:

| Test | Change | Reason |
|---|---|---|
| `carried_ekwan_line_on_scout_return` | The second card is a `scout_return` with 0 Ekwan (was `forced_retreat`) | The `forced_retreat` branch is gone. |
| `tooltip_text_matches_approved_wording` | `nothing_overcome_yet` tooltip is `Nothing was gathered.` | Copy file section 4 replaces the old text. |
| `return_card_empty_leave_has_no_outcome_line` | The row label is `Nothing was gathered.` (the core label stays `Nothing overcome yet`) | Same. The UI replaces the label (`ROW_NAMES`). |
| `return_home_confirmation_zero_carry_and_failed_escape` | Empty packs now show `Nothing is in their packs.`; third case has amount 0 with `nothing_new` | New empty variant. In the new model `nothing_new` cannot come with an amount. |
| `_confirm_payload` helper | Wraps `{ase, ekwan}` into `gathered` | The panel reads `gathered`. Other tests keep their numbers. |
| `Stage004SeamTests._t_realm_target_minima_and_spatial_caps` | Wires `_stall_panel` | That test builds the board by hand, and `_apply_responsive_layout` now places one more node. |

Probes (a green suite can be silent): I changed the code and the tests failed as expected, then restored each file (`cmp` equal): (1) total without `_gathered_ase`, mid-stage rule back to "no rows", return-confirm guard removed: three tests failed. (2) Stall-level guard removed: the first test version did NOT fail; I strengthened it (alpha must stay 1.0 on a repeat) and it then failed.

## 4. Screenshots (compact and standard, 1280x720 window)

Fixtures added: `standoff_first`, `standoff_second`, `standoff_froze_two`, `standoff_calm` (second Echo pair, 3rd standoff, heaviest card), `warning_level_1`, `warning_level_2`, `prebattle_stalled`, `fight_won_packs`, `found_money_card`, `defeat_packs_lost`, `carry_packs_gathered`, `carry_packs_empty`. All 12 rendered in both profiles and I viewed the key ones. The standoff card fits its heaviest case (4 lines, 2 buttons). The first view of the warning showed blue text on a terracotta board with too little contrast and a clash with the tokens. I added a dark pill panel; the second view reads well. Both buttons are 56 high with 12 gap. The `compact` and `standard` outputs came out the same at 1280x720 (the profile switch changes the Resolve card size only above 600 wide for non-compact cards; the standoff card is one fixed size by design). Jeff should still look at the real window sizes in play.

## 5. FINDINGS (not fixed; not mine)

1. **Pre-existing runtime error in the mid-stage card.** `ResolveScreen._build_midstage` calls `step.parallel()` on a `PropertyTweener` (since commit 3914d2d). `PropertyTweener` has no `parallel`. With motion on and two or more nodes it raises "Nonexistent function 'parallel'" and the loop stops. The tests never see it (they run with reduced motion). The won-fight card with the new row uses this path. Fix: `_motion.parallel().tween_property(...)` for `i > 0`. I did not change it (scope). Please decide.
2. **Core labels with banned words.** `VentureResolveSnapshotBuilder.gd:208` sends the action label `Return to Stage` on the situation card. That breaks ANSWERS #86 (follow-up 47). The new scan skips this one label by name.
3. **No `ase_gathered` on the combat victory card.** The UI reads the delta of the single `encounter_gathered` row for the total. This works while a card has at most one such row (7.C contract). A second gathered row on one card needs a key from `mechanics-developer`.
4. **Core stall data names an Echo by display name.** `stall_froze_name` is a name, so the bark finds the actor by name. Two Echoes with the same name would bark for the first one.

## 6. Ponytail: skipped

- No hold-then-cross-fade when the standoff fires (feel review 2.6). It needs shell-level work (two screens at once). The card appears as every Resolve card does.
- No vignette, no token-breathing change, no fast-forward of quiet rounds (feel review 2.3, 2.5). Jeff has not asked for them.
- No fade-out on clear. Level 0 hides at once, as the brief said.
- The warning bark plays once per fight. The line itself may fade in again after a streak that recovers and falls (feel review 2.4 wanted it once per fight).
- No second packs row type on the Resolve card for `packs_lost` (the line says it).
- No per-Echo bark table (the copy file says the language story owns it).
- No new theme variation. The pill panel and its style live in the board scene (one use).
- Did not run: the sharded or full suite, `combat_roundtrip`, fingerprint suites (not my files).

## OPEN — questions and assumptions

ASSUMED: The empty-leave row label is replaced by `Nothing was gathered.` in `ROW_NAMES` as well as in the tooltip. | WHY: copy file section 4 gives one line for the slot; design 5.3 names it as the row text. | WRONG IF: Jeff wants the core label `Nothing overcome yet` on the row and the new line only in the tooltip.
ASSUMED: Level 2 replaces the level 1 line (one line on screen), not a second line below it. | WHY: feel review 2.3: "Same line changes." | WRONG IF: Jeff wants both lines at once.
ASSUMED: Repeat hints: standoff 2 shows `It went the same way last time.`, standoff 3 and later show `Maybe they need rest.`, standoff 1 shows none. | WHY: the copy file lists two hints and says "by `standoff_count`" with no mapping. | WRONG IF: Jeff wants a different mapping, or a hint on the first.
ASSUMED: The won-fight card shows its `Fight won +6 Ase` row inside the normal earnings summary (`+6 Ase`, "How it was earned"), so the mid-stage card now has an earnings line when it carries that row. | WHY: the brief says keep the layout and show the row; the copy file has a row label and tooltip, and no other line for it. | WRONG IF: Jeff wants no Ase figure on a mid-path win and a story line instead (needs new copy).
ASSUMED: The standoff packs line and open-fight line always show (also with empty packs, also for a normal fight). | WHY: the card has no pack or fight-kind field; the copy says packs are unchanged and the task still there. | WRONG IF: the open-fight line should differ for an objective fight and a normal fight.
ASSUMED: The "calm" line may show two names joined with `and`. | WHY: the core caps `calmed_names` at two; the copy file assumes the same. | WRONG IF: the core sends three or more names.
BLOCKED: Should the `step.parallel()` error in `_build_midstage` be fixed in this story? | CHECKED: `ResolveScreen.gd:703`, git history (3914d2d), the probe above. | NEED: Jeff or the orchestrator to say yes (one line).
