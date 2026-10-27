# V2-ECONOMY-004 step 6.5 build: UI only (F1, F4 leftovers, F7 strings)

Rules: D-107, D-110, D-111. Nothing is committed. `core/`, `data/` and Notion are untouched.

## F1: no outcome line when nothing was completed
- Field used: the ledger row with `cause == "nothing_overcome_yet"` in `data.reward_breakdown`. The core adds it only when `overcome == 0` (VentureResolveSnapshotBuilder). `settle_outcome` alone cannot tell the two `nothing_new` cases apart, so the UI reads the row.
- `ResolveScreen._render_scout_return`: the outcome line is empty when that row is present. The row stays visible.
- The line `Nothing was gathered since the last time.` shows when `settle_outcome == "nothing_new"` and no such row exists (the core then sends a `settle_nothing_new` row).
- Tests: `payout_ui/return_card_empty_leave_has_no_outcome_line` (both cases). Proof: with the fix removed, it fails ("empty leave shows the line ..."). File restored.

## F4 leftovers
| Item | Change | Reason |
|---|---|---|
| `scripts/screenshot.gd` `retreat_tier_label` | removed | the core no longer sends it |
| `ResolveScreen.gd` comment `V2-STAGE-003: contact_result path` | moved above the `contact_result` branch (it sat above `retreat_return`) | wrong branch |
| `ResolvePayoutUITests` `_prebattle_payload` fixture | `retreat_tier_label` removed | not an input any more |
| `ResolvePayoutUITests` `_t_retreat_button` | the `{retreat_tier_label, carry_retreat_preview}` input replaced by `{}` | the core sends neither. The assertions stay (button text is only `Retreat (13 Ase)`, no second line). |
| `ResolvePayoutUITests` `_t_removed_gone` needle list (~938) | kept | it scans `res://ui` for the names. It proves `ui/` has no reader. It is not a fixture. |

## F7 / D-111 strings (exact)
| String | File |
|---|---|
| `Echoes safe` (row name), `Each Echo that stays alive earns Ase.` | PayoutCausePresentation.gd |
| tag `alive` (constant renamed `HOME_TAG` to `ALIVE_TAG`; 2 uses, both updated) | PayoutCausePresentation.gd, ResolveScreen.gd |
| `%s did not make it back.` | PayoutCausePresentation.gd |
| `The party has been here before. All of it earns less.` | PayoutCausePresentation.gd |
| `The party learned something new about the path.` | PayoutCausePresentation.gd |
| `This one was lost, but we still earn a small part.` | PayoutCausePresentation.gd |
| `%d path%s finished` | ResolveScreen.gd |
| `This path` (StageGroupHeader) | ResolveScreen.tscn |
| `Continue` (next button, default and scene text) | ResolveScreen.gd, ResolveScreen.tscn |
| `HomeCountLabel` placeholder: empty text `""` (code always overwrites it, and it is hidden) | ResolveScreen.tscn |
| `HomeTagLabel` placeholder in EmotionEntryItem.tscn: `alive` (Jeff's tag; same reason, was `home`) | EmotionEntryItem.tscn |

Not renamed: `home_count()` and the nodes `HomeCountLabel`, `HomeTagLabel` (internal names, no player text). The count line now reads `alive 2 of 3`.

Tests that pinned old strings (each updated because the string changed, nothing else): `payout_ui/wording` (tooltips, replay stage tooltip, `Echoes safe`, lost note), the three `did not come home` checks, the `home 3 of 4`, `home 4 of 4`, `home 0 of 4` counts and the `"home"` tag filter (now `alive`), the row-name assertion `Echoes home` (now `Echoes safe`). `FoundationUITests` ~862: the fixture `cta.next_stage` label `Next Stage` is now `Continue` (the core label is `Continue`; the test asserts layout only).
Fixture labels `Echoes home` in `_row(...)` calls stay: they model the core label (`EconomyService.gd:242` still sends it). `row_name` replaces it on the card.

New scan test: `payout_ui/older_strings_no_home_stage_or_percent`. It scans, case-insensitive for `home`, `stage` and `%`:
- all string constants, dictionary values and change lines of PayoutCausePresentation (with `%s`/`%d` removed), plus `home_count`, `lost_line`, the stage replay tooltip;
- the visible text of ResolveScreen for: stage end with a dead Echo, defeat, mid-stage win with intel, a replay stage card with a vow count of 3 and of 1 (`path(s) finished`), the empty-leave return card;
- tooltips for `echoes_alive`, `defeat_consolation`, `nothing_overcome_yet`, `replay`;
- every `text = "..."` line of ResolveScreen.tscn and EmotionEntryItem.tscn, unfiltered.
Still excluded: constant and node names, cause ids, the `SCOPE_*` ids, other scenes, the Sanctum and Vow screens (see finding 1), core labels (replaced by `row_name`), `Rank`, `Rounds` and other texts the core sends, and the action label from the core.

## Screenshots (macOS window, 1920x1080, profiles compact and standard; files in the scratchpad `/tmp/ecc-ui65/shots`)
Fixtures added to `scripts/screenshot.gd`: `resolve_tooltip_replay`, `resolve_defeat_tooltip`, `return_card_empty_leave`. The fixture label `Complete Stage` is now `Continue`. Viewed: `resolve_stage_home_lost` (compact), `resolve_tooltip_replay` (standard), `return_card_empty_leave` (compact), `resolve_defeat_tooltip` (standard): all correct. The empty-leave card shows `+0 Ase`, no outcome line, no stray label. `Continue` and `To Sanctum` buttons are 56 high; the `(i)` buttons keep the 48x48 target (existing test `cause_rows_have_48_button_others_none` passes). Not viewed one by one: the other 8 images (same layout).

## Verification (own `ECHOES_TEST_SAVE_DIR`, deleted before each run)
- Compile check: 0 errors.
- `=realm_ui,payout_ui,foundation_ui,stage,unified_resolve,summon_price_ui`: 113 of 113.
- `=stage_stop_ui,stage_camera,combat_ui`: 128 of 128.
- `scripts/check-shard-map.sh`: OK (137 suites).
- `--import`: see report (run last).

## Findings, not changed
1. `VowScreen.gd:207,224` and `SanctumScreen.gd:372,375` still use `%d stage%s honored` (and a comment). D-111 item 7 names only the Resolve ledger. Same player word issue: needs Jeff's decision.
2. The Echoes header count reads `alive 2 of 3` and each row tag reads `alive`. It is repetitive; copy is Jeff's.
3. Core still sends row label `Echoes home` (`EconomyService.gd:242`). UI hides it through `row_name`; the label would show only if the cause were missing.
4. `ResolveScreen.gd` still has `"Return to Sanctum"`/`"To Sanctum"` defaults and the banner `Scout Return`: not in this brief.

## OPEN — questions and assumptions
ASSUMED: The UI reads the `nothing_overcome_yet` row to detect "nothing completed" | WHY: it is the only reliable field; `settle_outcome` is `nothing_new` in both cases and the core sends `overcome:0` only inside the row | WRONG IF: the core should send an explicit boolean; then it is a core change.
ASSUMED: `HomeCountLabel` placeholder empty and `HomeTagLabel` placeholder `alive` | WHY: both are overwritten, and neither may read "home" | WRONG IF: Jeff wants other neutral text.
BLOCKED: none.
