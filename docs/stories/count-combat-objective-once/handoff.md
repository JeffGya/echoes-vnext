# Count each combat objective once

## Result

A combat win records the objective before Resolve opens. Stage completion uses the same rule and skips a situation that has already been resolved. The final choice pays the stage reward, settles the item records, and advances the Realm in one save.

Repeating a final Resolve choice cannot advance the Realm again before another stage is selected. Repeating **Return to Exploration** cannot apply the Vow entry effect again.

## Verification

- The three new regressions failed before the fix. They reproduced the extra count, extra stage advance, and extra Vow save.
- The compile check passed. All 169 focused tests passed. They cover both final choices, reload on Resolve, and completion without a fight.
- All 34 tests passed in the separate checkout with pickup PR #132 at `9962b75`. After a reload during pickup, the Resolve item report matched the items added to the pack.
- The full sharded runner reported 2,910 passed and zero failed. It counted one known movement failure as passed. The objective suite logged an error when a reward test used a missing logger. The same error occurred on `main`.
- An independent review checked the code changes, the baseline failures, and the focused and combined test logs.
- Jeff played the fix on 18 November 2026 and reported that it worked as expected. He reported no issues.
