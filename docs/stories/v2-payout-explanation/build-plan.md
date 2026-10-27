# Payout explanation — build plan (PLAN ONLY, no build until "GO: backend verified")

Written in STE. Source decisions: `decisions.md` D-01 to D-15. Mockups: `mockups/resolve-compact.html`.
Build rule (D-33 of the backend story): backend and UI go in the SAME PR. I do not merge, rebase or commit until the backend session says so.

## 1. Backend keys the UI reads or dispatches

| Item | Where | UI use |
|---|---|---|
| `data.reward_breakdown[]` rows `{label, delta, currency, cause, params}` | Resolve snapshot (combat, scout return, replay) | Ledger "This fight" group |
| `data.stage_payout_rows[]`, `data.stage_payout_ase`, `data.stage_payout_ekwan` | only on the stage-ending victory card | Ledger "Stage" group; total = `ase_awarded` + `stage_payout_ase`; "Ekwan earned" line |
| `data.ase_awarded` | all cards | Fight total (never includes the stage payout) |
| `data.ekwan_awarded` | fight cards, always 0 | Not shown |
| `data.ledger_seen` | combat, scout-return, replayed cards | First-time open rule |
| action `resolve.ledger.mark_seen` | dispatch once the player has seen the ledger | Marks `ui_flags.result_ledger_seen` |
| causes | `enemies_defeated`, `echoes_alive`, `bonus_earned`, `bonus_missed`, `replay`, `defeat_consolation` (`params.part` base/penalty), `repeat_defeat`, `objectives_overcome` (`overcome`, `total`), `realm_virtue`, `partial_retreat`, `partial_return_home`, `nothing_overcome_yet` | Tooltip text lookup |

Rows with no `cause` ("Found") get no (i). Rows with `currency` "ekwan" are not expected (D-32); the UI ignores any.
The UI hard-codes no amount.

## 2. Open points that could need a backend change (none known now)

1. ANSWERED by the backend session: `resolve.ledger.mark_seen` is a fixed dict the UI builds, `{ "type": "resolve.ledger.mark_seen" }`, with no slot, payload or label. The screen emits it through `action_requested`; AppRoot dispatches. It is idempotent. It only exists on cards that carry `data.ledger_seen`, so the UI emits it only when that key exists and is false. The backend patches `data.ledger_seen` to true in the live snapshot, so a re-render does not reopen the ledger.
2. Total on a defeat card and on scout return: `ase_awarded` only (no stage rows). No change needed.
3. A forced retreat or a card with `ledger_seen` absent: the UI treats absence as "seen" (ledger closed). No change needed.

## 3. Files I will touch (all `ui/`, `scripts/`, `tests/`, `docs/`)

| File | Change |
|---|---|
| `ui/screens/venture/ResolveScreen.tscn` | Remove `RankRow`, `AseRow`, `EkwanRow`, `StatGrid`. Add `FightStrip` (HFlowContainer: Rank, Enemies defeated, Echoes alive, Rounds chips), `EarningsSummary` (Button, 48 px high: Ase total, optional Ekwan, "How it was earned", chevron) and `Ledger` (VBoxContainer, hidden) holding groups `FightGroup` and `StageGroup`. `BreakdownSection` moves under `Ledger`. Keep `RankCauseLabel`, emotion, vow, footer nodes. |
| `ui/screens/venture/ResolveScreen.gd` | Replace the Ase/Ekwan/stat setters with chip and summary setters. `_build_breakdown` becomes `_build_ledger(fight_rows, stage_rows)`. Net the two `defeat_consolation` rows into one "Consolation" row. Toggle the ledger. Emit `resolve.ledger.mark_seen` once. Remove the Ase, Ekwan and "defeated" chips from `_build_effects_rail` (keep item, intel, continuity). |
| `ui/components/RewardEntryItem.tscn` + `.gd` | Add `%CauseButton` (48x48, icon "i") and a spacer when no cause. Emit `cause_requested(button, cause, params)`. |
| `ui/components/PayoutCausePresentation.gd` (new) | One lookup table: cause id + params to the final tooltip text and the row name. Same style as `PacePresentation`. All text is from `decisions.md`. |
| `ui/components/CauseTooltip.tscn` + `.gd` (new) | The floating tooltip with an arrow: `PanelContainer`, title label, body label. One instance per screen, on the screen's top layer. Opens on hover, focus or tap. Closes on tap outside or Esc. Never moves the rows. |
| `ui/screens/venture/ResolveScreen.tscn` theme | The real card is a warm panel (`RealmResolveCard`), not dark. My mockup used a dark card. Tooltip and chip colors are set from the Living Grove tokens against the warm panel. Needs a quick Jeff check on the first screenshot. |
| `scripts/screenshot.gd` | New fixtures: `resolve_ledger_closed`, `resolve_ledger_open_fight`, `resolve_stage_end`, `resolve_defeat_consolation`, `resolve_retreat_zero`, `resolve_tooltip_open`. |
| `tests/ResolvePayoutUITests.gd` (new) + shard map entry | Filtered UI tests (section 4). |
| `docs/stories/v2-payout-explanation/decisions.md` | Update at the end. |

I touch no file under `core/`. Layout profiles: `compact` 680x476, `standard` 760x600, `wide` 840x700 (`_apply_profile_size`). All three are checked in screenshots.

## 4. Tests (filtered runs only; the full suite runs on CI)

1. Fight card with 4 rows: ledger shows 4 rows; total label equals `ase_awarded`.
2. Stage-ending card: "Stage" group shows `stage_payout_rows`; total equals `ase_awarded` + `stage_payout_ase`; "Ekwan earned" shows `stage_payout_ekwan`; no (i) on it.
3. Mid-stage card (no `stage_payout_rows`): no Stage group; no Ekwan line.
4. Defeat: two `defeat_consolation` rows become one "Consolation" row with the net amount.
5. `replay` absent: no Replay row. `bonus_missed`: muted zero row with (i).
6. Zero rows (`nothing_overcome_yet`, `repeat_defeat`): row shows, muted, with (i) and the right text.
7. Every row with a `cause` has a 48x48 button; a row without has none.
8. Tooltip text for each cause equals the table in `decisions.md` (guards the approved wording).
9. Ledger starts open when `ledger_seen` is false and emits `resolve.ledger.mark_seen` once; starts closed when true.
10. A row with an unknown cause shows no (i) and logs nothing fatal.
11. No amount or ID text is hard-coded in the new scene (grep-style check on `.tscn`).

Run: `godot --headless --quit --path <checkout> -- tests =ResolvePayoutUITests,UnifiedResolveTests,PaceUITests,FoundationUITests` plus the compile check. No full suite (CI runs it).

## 5. Screenshots

`scripts/screenshot.gd` fixtures above, at 1920x1080 (reference size), for `compact`, `standard` and `wide`. I attach them for Jeff. Jeff tests in game.

## 6. Order of work after GO

1. `RewardEntryItem` + `CauseTooltip` + `PayoutCausePresentation` (components first).
2. `ResolveScreen.tscn` restructure, then `ResolveScreen.gd`.
3. Tests, compile check, screenshots.
4. Milestone line to the backend session after each: design done, scene done, tests green, screenshots done.

## 7. Risks

- **Scroll:** with the ledger open and stage rows, the body scrolls (measured in the mockup: about 600 px against 387 px). Echoes then sit lower. Accepted: the ledger is closed by default after the first time.
- **First-time open pushes the Echoes down** once. Accepted by Jeff (D-03).
- **Numbers still move** (Phase 5). The UI reads data only, so this does not break the build.
