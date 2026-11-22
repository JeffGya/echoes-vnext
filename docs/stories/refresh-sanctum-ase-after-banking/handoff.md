# Keep the Sanctum Ase balance current

## Player result

When the four-minute bank timer credits Ase, the Sanctum balance changes in place and uses its usual pulse. The banking action returns the credited amount in the existing screen data. Awakening and welcome-back notices still appear once.

## Verification

- Before the fix, the timer left 100 Ase on screen after the account and save had reached 101.
- The focused tests passed for positive gain, zero gain, the one-hour earning cap, screen changes, both notices, failed startup, and valid save recovery.
- The bank check passed with the ITEM-001b backend in PR #132 at `9962b75` and the local pickup UI at `78f6f32`. A bank tick during the intro or a swap kept the event, the choice, and the held result. Continue opened Resolve once. The wider pickup UI run reached its time limit.
- The full sharded run reported 2,914 passed and zero failed. The runner counted the existing movement test failure as passed.
- On 22 November 2026, Jeff confirmed that Sanctum showed 102 Ase after the first live tick credited and saved the change from 101 to 102. He used a separate playtest save.
