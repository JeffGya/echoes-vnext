# Phase 5.5b — the summon grade lock moves into the core

## Design

- New config key `data.summoning.grade_enabled` = `{"uncalled": true, "called": false, "chosen": false}`.
- One reader: `SummonService.grade_enabled(summoning_cfg, grade) -> bool`.
- Missing-key rule: a missing table or key means enabled for `uncalled` and disabled for `called` and `chosen`. An unknown grade is disabled. A broken config never opens a locked grade.
- `summon_grade_options[]` in the SUMMON snapshot gains `enabled` (bool).
- `sanctum.grade_select` for a disabled grade: refused. The selected grade does not change.
- `sanctum.summon` when the selected grade is disabled: refused before the settle step. No settle, no spend, no Echo, no reveal.
- Both refusals log `sanctum.summon.grade_locked` (info) and return the SUMMON snapshot with `data.summon_denied = {reason: "grade_locked", grade: <grade>}`. The outcome has no save reason, so no save is written.
- Prices, batch rules, the opening and rewards are not changed.

## Field names for the UI session

| Where | Field | Type | Meaning |
|---|---|---|---|
| `snapshot.data.summon_grade_options[i]` | `enabled` | bool | false = show the card locked |
| `snapshot.data.summon_denied` | `reason` | String | `"grade_locked"` |
| `snapshot.data.summon_denied` | `grade` | String | the refused grade key |

The UI list that locks Called and Chosen can read `enabled` instead. To open a grade later, change `grade_enabled` in `data/balance.json`.

## Tests (`tests/SanctumSummonTests.gd`)

New:
- `grade_options_carry_enabled`
- `grade_select_locked_refused`
- `summon_locked_grade_refused` (no spend, no Echo, no reveal)
- `unlocked_called_summons_at_called_price` (config flipped in the test; cost 160 at 3 living)
- `grade_enabled_missing_key_rule`

Changed: five existing tests that select Called or Chosen now call `_unlock_all(env)` first (`called_grade_spends_150`, `denied_when_balance_insufficient_for_grade`, `summon_disabled_true_when_insufficient`, `summon_disabled_false_when_sufficient`, `grade_options_carry_next_and_after`). Without it the core refuses the grade. `_make_runtime_env` now also returns `config`; the helper `_set_grade_enabled` writes the private `ConfigService._balance` because `get_balance()` returns a copy.

## Predicted moved values

None moved. A search of `tests/`, `tools/` and `docs/*.md` found no fingerprint, baseline or key list that covers `data.summoning` or the option keys. The only file that names `chosen_extra` or `summon_grade_options` is `tests/SanctumSummonTests.gd`. No `EchoFactory` draw changed.

## Files changed by this phase

- `core/sanctum/SummonService.gd`
- `core/runtime/controllers/SanctumController.gd`
- `core/state/flow/states/sanctum/FlowSummonState.gd`
- `data/balance.json` (one line added)
- `tests/SanctumSummonTests.gd`
- `docs/stories/v2-economy-004/phase5-5b-build.md`

Other modified files in the tree belong to Phase 5.8.

## Verification

Compile check: no errors. The `tests =sanctum.summon,...` command used `ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase55b`.
Not run: `reward`, the full suite. In-game probe left to qa-verifier: the summon screen shows the Called and Chosen cards with `enabled=false`.

## OPEN — questions and assumptions

ASSUMED: the lock check runs before the settle step in `sanctum.summon` | WHY: Jeff asked for "no state change" on refusal, and settle credits Ase | WRONG IF: a refused summon should still settle offline time.
ASSUMED: a locked refusal writes no save | WHY: nothing changed | WRONG IF: the UI needs a save flush after a denial.
ASSUMED: tests write `ConfigService._balance` directly | WHY: `get_balance()` returns a deep copy and there is no setter | WRONG IF: the project forbids private access in tests.
BLOCKED: none

Tests: 108 total, 108 passed, 0 failed (sanctum.summon 31, sanctum.party 5, sanctum.layout 35, onboarding 26, echofactory 3, snapshot_contract 8)
