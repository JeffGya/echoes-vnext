# V2-ECONOMY-004 step 6.4 build: fixes from the final QA (backend)

Rules: D-106, D-109, D-110. Nothing is committed. `ui/`, Notion and the Working GDD are untouched.

## F2: a retreat-passed fight is the only target left

Cause: `StageExploreTurnService.advance_turn` returned "no_target" before `turn_count` rose. `_retreat_passed_due` (`turn_count > retreat_pass_turn`) could never become true.

Fix (smallest change):
- New `ActiveStageService.has_retreat_pass_waiting(explore_map)`: true when an unresolved, revealed situation has `retreat_pass_turn` and is not yet due.
- In `advance_turn`, in the `no_target` branch: when that is true, `turn_count` rises by 1, the stage is written back and a save is requested (`stage.advance_turn.parked`). The status is still "no_target".
- Result: the retreat turn parks one turn; the next Advance finds the fight (Tier 4) and the party goes for it.

Unchanged: Tier 1/2 and the frontier still come first; an ignored fight (no marker) is never re-offered; the retreat turn itself never offers it. Once the fight is due, the counter no longer moves in the parked branch (no endless increments).

Test: `retreat/retreat_passed_fight_only_target` (real dispatch, `_setup_explore_env`, map fully explored, one passed normal fight with `retreat_pass_turn = turn_count = 0`). Asserts: dispatch 1 gives turn 1 and no target; dispatch 2 heads for the fight.
Proof it fails without the fix: `StageExploreTurnService.gd` restored to HEAD gives "expected turn 1 and no target, got turn 0; later turn: expected the party to go for the fight 'sit.0', got ''". File restored, `cmp` clean.

## F6: the settle roll is logged; bad config fails visibly

- `settle_leave` logs `economy.settle.leave` (info) with `stage_id`, `settle_count`, `roll`, `outcome`, `share_pct`, `ase`, `ekwan`, `marked_indexes`. The roll number is in the log only. No snapshot changed.
- New `_invalid_carry_key`: `carry_odds` and `carry_shares` must each be a Dictionary with a number for `none`, `some` and `all`. If not, `settle_leave` logs `economy.settle.config_error` with `parent_key` = `data.rewards.<key>` and returns `nothing_new`. No objective is marked, nothing is paid, no counter moves. (Finding: before the fix, a missing `carry_shares` still built a table of zero shares and marked every objective settled with nothing paid. A missing `carry_odds` already returned an empty table, but without an error log.)
- The logger has no `error` level. The project pattern for a missing config key is `logger.warn` (as `RewardCalc.cfg_num` does); `warn` writes at info level. I used `warn`.
- Tests (`econ_char`): `settle_leave_logs_roll_outcome_and_marks`; `settle_leave_fails_visibly_on_bad_carry_config` (4 cases: carry_shares erased, carry_odds erased, carry_shares missing one outcome, carry_odds a string; each checks nothing_new, objective unmarked, totals 0, balance 0, error log names the key).
- Probe: `StageSettlementService.gd` restored to HEAD fails both tests. File restored, `cmp` clean.

## F3: stale comments (behaviour unchanged)

| File | Change |
|---|---|
| `ActiveStageService.gd` | `apply_retreat_return` doc ("never offered again") fixed; find_explore_target header and Tier 4 text; the Tier 1/2 loop comment; the Tier 4 loop comment |
| `tests/RetreatTests.gd` | comment above `failed_retreat_spend_survives_reload` (a re-roll after a reload no longer happens) |
| `tests/CombatBaselineTests.gd` | section D header (null-seed fallback uses `hash(<same key>)` instead of `campaign_seed.get_rng(<key>)`); the `FlowRuntime.gd:1017` reference removed; `_retreat_probe` now says "retreat-return resolve card" |
| `VentureResolveSnapshotBuilder.gd` | "THREE callers" is now "TWO callers"; the "two pre-existing callers" phrase removed |
| `FlowRuntime.gd` | "The two SETTERS" is now one setter (`stage.return_home`); a combat retreat sets none |
| `FlowContext.gd` | comments on `pending_scout_return_ase` and `_intel_count` no longer say "retreat" |

Not changed (report only): `ui/screens/venture/ResolveScreen.gd:229` has the comment `# V2-STAGE-003: contact_result path` above the `retreat_return` branch. It belongs above the `contact_result` branch. The UI agent moves it.

`TIER_PASSED_OBJECTIVE` rename: NOT done. The name is in 10 places (`StagePartyMovementAdapter` constants and its state key string `state.tier_passed_objective`, `ActiveStageService`, `StagePartyMovementTests`, `TraversalModelTests`). The state key string may be used by bark data. This is not a trivial rename. Left as it is.

## F4: removed fields

| Removed | Where | Audit result |
|---|---|---|
| `retreat_tier_label` | `EncounterSnapshotBuilder.build_round_snapshot`, and the keeper-intro stub in `FlowKeeperIntroState.gd` | `ui/` reads it nowhere. Remaining: `scripts/screenshot.gd:417` (UI agent), `tests/ResolvePayoutUITests.gd:938,1159,1193` (fixtures that pin "UI ignores this"; left as they are; UI agent decides) |
| `carry_retreat_preview` | `EncounterSnapshotBuilder.build_round_snapshot` (and its `settle_plan` call) | `ui/` reads it nowhere. Remaining: `tests/ResolvePayoutUITests.gd:938,1193` (same), story docs (history) |
| `partial_cause` parameter and `params.partial` on the `nothing_overcome_yet` row | `VentureResolveSnapshotBuilder.build_scout_return_snapshot` | No caller passed it in `core/` (return home and forced retreat). `ui/` never reads `params.partial`. The row keeps `overcome` and `total`. |

Kept on purpose: `retreat_success_pct` (data) and `cta.retreat.success_pct`. The `encounter.retreat` handler still reads `success_pct` from the action dict (F5, not fixed). `retreat_success_pct` in `data` has no reader in `ui/`; it is a percent in a snapshot. It is not in the brief. I left it; remove it with F5.

Docs: `CONVENTIONS.md:1006` no longer lists `carry_retreat_preview`. `docs/integration-map.md` row for V2-ECONOMY-004 now names `settle_plan`, `carry_table`, `settle_leave`, `next_retreat_roll_key`, `apply_retreat_return`, describes the settle model, and says guard count 78 plus the new save fields.

Test rewrites (each with a reason):

| Test | Change | Reason |
|---|---|---|
| `snapshot/pre_combat_has_retreat_fields` | `retreat_tier_label` no longer required; absence of `retreat_tier_label` and `carry_retreat_preview` asserted | The fields are removed on purpose. Absence is now the contract. |
| `snapshot/field_count_is_nonzero` | The check "round has at least as many fields as final" removed | It compared two unrelated key counts (25 and 25 until two fields left the round snapshot). It guarded no contract. The `> 0` checks stay. This is a weaker assertion, on purpose; flagged for QA. |
| `econ_char/settle_retreat_pays_nothing` | Read of `carry_retreat_preview` replaced by absence checks for the two removed keys | The field is removed. The pays-nothing and marks-nothing checks are unchanged. |
| `econ_char/cause_scout_rows` | Dropped the 4th argument `"partial_retreat"`. The zero row now asserts no `partial` key and `total` 1 | The parameter is removed. |
| `Stage004SeamTests` (fixture at ~:1550) | Removed `"retreat_tier_label": "Risky"` from a prebattle payload | The key is gone from the snapshot. The fixture asserted nothing on it. |

## Filtered runs (own `ECHOES_TEST_SAVE_DIR`, deleted before each run). Compile check: 0 errors.

| Filter | Result |
|---|---|
| `=econ_char,seam` | 125 of 125 (2 new tests) |
| `=objective,objective_combat` | 91 of 91 |
| `=stage,stage_stop_ui,stage_camera` | 84 of 84 |
| `=pending_result,save_integrity` | 30 of 30 |
| `=unified_resolve,foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity` | 52 of 52 |
| `=venture_char,flow_transaction,retreat,payout_ui,summon_price_ui,sanctum.summon` | 137 of 137 (`retreat` now 29) |
| `=onboarding,bridge,snapshot,snapshot_fingerprint,retreat,combat_ui` | 137 of 137 |

The ERROR lines in the output (missing `data.rewards.*`, `retreat_ase_cost`) come from tests that use an empty config. They appeared before this step.
`payout_ui` and `realm_ui`: no failure from the removed fields. `realm_ui` was not run (not in the list).

## PREDICTED moved values (not re-recorded)

The removed keys `retreat_tier_label` and `carry_retreat_preview` are in the `flow.encounter` round snapshot (pre_combat and all phases), and `retreat_tier_label` in the keeper-trial stub.

| Suite / constant | Prediction |
|---|---|
| `snapshot_fingerprint` | Ran: passes. It does not hash the encounter round payload. |
| `fingerprint_*`, `fingerprint_determinism_*` (`FlowFingerprintTests`, `FlowFingerprintSeekTests`) | They pin combat results and `flow.resolve` shape, not the round snapshot key set. Not expected to move. A hash over the whole `last_snapshot` of a `flow.encounter` would move; I found none by grep, and I could not run them. |
| `combat_baseline`, `combat_roundtrip`, `maturity_baseline` | Not expected to move from the key removal. `combat_baseline` still has the two retreat constants from step 6.2b. |
| `reward` | Not expected to move. |
| New `economy.settle.leave` log | A log line only; a suite that counts log events by type during a return home would see one more info line. `venture_char` and `econ_char` pass. |
| New parked turn in `advance_turn` | Changes behaviour only when a retreat-passed fight is waiting and no other target exists. No baseline has that state. |

## RUN REQUEST (main chat runs; a subagent must not)

1. For each, run: `rm -rf /tmp/echoes-vnext-tests && /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =<suite>` with tool `timeout: 3700000`. Use a separate own `ECHOES_TEST_SAVE_DIR` if another run is active.
2. Suites: `fingerprint_seek`, `reward`, `combat_baseline`, `combat_roundtrip`, `maturity_baseline`, and the `fingerprint` filter (all `fingerprint_*` and `fingerprint_determinism_*`).
3. Files edited by the runs: none.
4. Verify: `git status --short` shows only the 15 files edited in this step plus `phase6-4-build.md`.
5. Expected failures: only the two `combat_baseline` retreat constants from 6.2b. Any other failure is new: read its raw line.

## Findings not changed

- `retreat_success_pct` stays in the round snapshot (see F4 note).
- `ResolvePayoutUITests.gd` lines 938, 1159, 1193 still use the removed key names as inputs.
- Comment at `ResolveScreen.gd:229` is misplaced (UI).

## UI agent list

1. `scripts/screenshot.gd:417`: remove `snap["data"]["retreat_tier_label"] = "Risky"`.
2. `ui/screens/venture/ResolveScreen.gd:229`: move the `contact_result` comment to its branch.
3. `tests/ResolvePayoutUITests.gd:938,939,1159,1193`: decide whether the fixtures keep the removed key names (they prove the UI ignores them).
4. No other `ui/` reference to `retreat_tier_label`, `carry_retreat_preview` or `params.partial`.

## OPEN — questions and assumptions
ASSUMED: The parked turn spends one turn on the retreat turn plus one parked turn, and the fight is offered on the Advance after that | WHY: D-109 says "not at once"; 6.2b doc says the party parks for that turn | WRONG IF: Jeff wants the fight offered on the first Advance after the retreat card.
ASSUMED: `logger.warn` (info level, `economy.settle.config_error`) satisfies "log an error" | WHY: StructuredLogger has no error method; `RewardCalc.cfg_num` uses warn for the same case | WRONG IF: an error level should be added to the logger.
ASSUMED: The round-versus-final field count comparison in `snapshot/field_count_is_nonzero` guarded nothing and may be dropped | WHY: it compared two unrelated counts that were equal by accident | WRONG IF: the parity rule is a wanted contract; then add a field instead.
ASSUMED: `retreat_success_pct` in the snapshot data stays until F5 | WHY: F5 is not in this story | WRONG IF: Jeff wants it removed now.
BLOCKED: none.
