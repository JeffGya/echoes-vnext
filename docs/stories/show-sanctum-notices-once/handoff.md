# Show Sanctum notices once

## Result

The first Sanctum response carries the Awakening overlay and offline welcome-back notice. Dispatch copies that response before clearing the notices from the cached snapshot. Later bank settlement reuses the cache without replaying either notice. Pending notices wait through the Keeper intro until Sanctum carries them.

## Verification

- The dispatch regression uses a real `economy.settle_time` action with a fixed timestamp and `source: "bank.interval"`. It checks settlement, the reused build tick, and both responses after settlement.
- Before the fix, `snapshot_purity` reported 12 total, 11 passed, 1 failed. The regression identified both replayed notices.
- After the fix, the compile check completed without errors. Five targeted suites reported 62 total, 62 passed, 0 failed.
- The full sharded runner reported 2907 total, 2907 passed, 0 failed. All 13 shard ledgers reached the merge step.
- Existing runner caveats include one known movement failure counted as passed and 57 pre-wipe fallbacks excluded under the serial-equivalence rule. Logs also contain a null-logger error in EarningsService and a missing PrebattlePanel error in a seam test. Their source files are unchanged by this story.
- Independent review checked the source, diff, regression failure, targeted result, and full-suite logs. It found no remaining defects in this change.
- Jeff approved the playtest handoff and authorized the PR on 17 November 2026. Approval was supplied for the change as a whole.

## Files

`FlowRuntime.gd` owns the notice consumption fix. `FlowSnapshotFingerprintTests.gd` covers cached settlement replay. `OnboardingTests.gd` reads the actual dispatch response for its existing first-Sanctum assertion.

Branch `codex/show-sanctum-notices-once` starts from main revision `85224667` in a separate worktree.
