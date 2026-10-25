# Step 5.16 (UI): F1 layout, F6 dead read, return-home copy

Decisions: D-103 (F1, F6, F5 wording from Jeff). No `core/` or `data/` file changed.

## F1: EarningsSummary width
- Cause (READ-FROM-CODE): the node is a real `Button` (focus_mode 2, SummaryRow inside). In a VBoxContainer it fills the full width at run time. The test reads authored width: `custom_minimum_size.x`, then offsets, then `SIZE_EXPAND`. The node had none of them, so it read 0.
- Choice: fix the scene, not the test. The test rule is correct for a real target, and the other buttons already set the flag. `ResolveScreen.tscn`: `size_flags_horizontal = 3` on EarningsSummary. No visible change (fill was already the default in a VBox).
- `realm_ui` now reaches every scene including ReturnHomeModal: 20 of 20 pass.

## F6: dead `return_failed`
- Removed the read in `StageExploreScreen.gd` (label now always shows `party_state`).
- Removed `tests/StageExploreTests.gd` test 10 and its registration and header line. Reason: it set the flag by hand and checked it back. No code ever wrote it. Numbers 11 to 13 keep their labels.
- `CONVENTIONS.md` lines 1078 and 1245 fixed: a failed escape writes `data.return_home_result`; success goes to `flow.resolve` (scout return).
- REPORT, not edited (core): `core/state/flow/states/venture/FlowStageExploreState.gd:24` says "(or return_failed flag)". It should say `return_home_result`.
- Audit of ui/, tests/, docs/, scripts/: remaining hits are history in `phase5-14-build.md` only.

## Copy (Jeff's strings, exact)
- `CarriedHomePresentation.gd`: `CONFIRM_WARNING` = "Escaping might be more difficult than expected. It might not be possible."; `FAILED_SUBTITLE` = "No way out."
- `ReturnHomeModal.tscn`: new `WarningLabel` (RealmModalBody, wrapped, hidden by default) between the question and the carried panel. Confirm mode shows it; subtitle stays hidden (invisible in a VBox, so no gap). Result mode: subtitle "No way out.", warning hidden. Body still comes from the core.
- Tests: `payout_ui` `return_confirm_zero_and_failure` now checks warning text, subtitle hidden, and the failed subtitle. No test or fixture pinned "Blocked". `scripts/screenshot.gd` fixtures needed no change.

## Verified (filtered, own save dir)
realm_ui 20, payout_ui 36, foundation_ui 17, stage 84 (incl. stage_stop_ui 38, stage_camera 36), unified_resolve 13: all pass. Compile check: zero errors. `--import` clean. `check-shard-map`: OK. Screenshots `carry_return_home` (compact, standard) and `carry_return_home_failed` read by eye: fits, no gap, buttons 150x56. Wide not rendered (the card has a fixed 460 width).
Not run: full suite, fingerprint, reward. Jeff must look at it in-game.
