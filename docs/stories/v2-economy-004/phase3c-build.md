# V2-ECONOMY-004 Part A — Phase 3c build (payout row causes, ledger-seen bool)

Written in STE. Tags: READ = seen in code. MEASURED = I ran it. PREDICTED = not run.
Scope: D-18 to D-20, D-23. No payout number changed. No `ui/` file edited. No Ekwan row changed.

## 1. Row contract

Every Ase row is now `{label, delta, currency, cause, params}`. `label`, `delta` and `currency` are unchanged.
The one builder is `EconomyService._row()` (`EconomyService.gd:306`). The scout row is built inline.
The Ekwan "Sanctum share" row has no `cause` and no `params`. The "Found" row (`VentureResolveSnapshotBuilder`, producer E) has none either; no cause id was requested for it.

| Cause id | Row label (unchanged unless noted) | `params` | Producer (file:line) |
|---|---|---|---|
| `enemies_defeated` | "N enemies defeated" | `count` | `EconomyService.gd:159` |
| `echoes_alive` | "N echoes survived" | `count` | `EconomyService.gd:162` |
| `bonus_earned` | "Pace bonus", delta > 0 | `{}` | `EconomyService.gd:165` |
| `bonus_missed` | "Pace bonus", delta 0, pace mode only | `{}` | `EconomyService.gd:165` |
| `replay` | "Redo penalty" | `factor` (redo multiplier) | `EconomyService.gd:167`, `:178`, `:234` |
| `defeat_consolation` | "Base objectives" and "Defeat penalty" (two rows) | `part` = `base` or `penalty` | `EconomyService.gd:175`, `:176` |
| `repeat_defeat` | "Repeat defeat" (NEW label, PROPOSAL) | `{}` | `EconomyService.gd:184` |
| `objectives_overcome` | "Base objectives" (stage payout) | `overcome`, `total` | `EconomyService.gd:229` |
| `realm_virtue` | "Realm virtue" | `{}` | `EconomyService.gd:236` |
| `partial_return_home` | "Scout return" | `overcome`, `total` | `VentureResolveSnapshotBuilder.gd:68-69` (default cause) |
| `partial_retreat` | "Scout return" | `overcome`, `total` | same line; `FlowRuntime.gd:1225` passes the cause |
| `nothing_overcome_yet` | "Nothing overcome yet" (NEW label, PROPOSAL), delta 0 | `partial`, `overcome` (0), `total` | `VentureResolveSnapshotBuilder.gd:71-72` |

Rules, all READ in the code above:
- `replay` row exists only when the redo penalty is below 0. At `run_count` 0 the row is absent. No zero row.
- `repeat_defeat`: a repeat defeat returns this one delta-0 row (was an empty list).
- `nothing_overcome_yet`: appears on a retreat or return home when the partial is 0 and no objective is overcome. A forced retreat gets no row (it pays 0 by design).
- `total` excludes types in `data.rewards.objective_count_excluded_types` (`balance.json`, value `["boss"]`). `overcome` also skips them. Remove `"boss"` from the list when the boss is a real objective. The counter is `RewardCalc.objective_counts` (`RewardCalc.gd:50`); the stage reader is `ActiveStageService.get_objective_counts` (`ActiveStageService.gd:315`). The list changes no payout.
- `defeat_consolation` is two rows with one cause. The UI can show one consolation row by merging them, or by using `part`. This is an ASSUMED choice (see OPEN).

## 2. Saved bool

| Item | Name |
|---|---|
| Save field | `save_data["ui_flags"]["result_ledger_seen"]` (bool, default false) |
| New save | `SaveSchema.make_new_save` (`SaveSchema.gd:146`) |
| Old save repair | `SaveService._apply_additive_defaults_and_repairs`, block "ui_flags" (`SaveService.gd:1179`). A missing or wrong-type value becomes false. |
| Reader | `SaveSchema.ledger_seen(save)`; a save without `ui_flags` reads false |
| Action | `resolve.ledger.mark_seen` (no fields). Arm in `FlowRuntime.gd:263`. Owner: `VentureController.handle_ledger_mark_seen`. |
| Save path | `FlowActionOutcome.with_save_reason("ui.ledger.seen")`; FlowRuntime flushes once per dispatch |
| Snapshot key | `data.ledger_seen` (bool) on the combat Resolve card (`FlowEncounterState.gd:416`), the scout-return card (`VentureResolveSnapshotBuilder.gd:126`) and the replayed card (`PendingResultService.gd:466`, live value, not the stored copy) |
| Block | `ResolveSnapshotBuilder.add_ledger_seen` |

The action also patches `ledger_seen` to true in the live `last_snapshot` when the key exists, so a re-render does not reopen the ledger. A second dispatch does nothing. The action is not a slot in `snapshot.actions`; the UI dispatches it.

## 3. Saved copy and old saves (MEASURED, `econ_char`)

- `PendingResultService` copies rows with `duplicate(true)`. `cause` and `params` survive the durable copy and the replay: test `cause_rows_survive_pending_copy`.
- An old row `{label, delta, currency}` replays unchanged and without error: test `cause_old_saved_row_replays`. The replayed card reads `ledger_seen` false.

## 4. Tests added (all in `tests/EconomyCharacterizationTests.gd`, suite `econ_char`)

`cause_encounter_rows`, `cause_zero_by_rule_rows`, `cause_stage_rows`, `cause_scout_return_rows`, `cause_boss_stub_excluded_from_total`, `cause_rows_survive_pending_copy`, `cause_old_saved_row_replays`, `ledger_seen_default_false_and_action_sets_it`.
They cover: each cause id; replay absent at run_count 0 and present at 1; zero-by-rule rows; the boss stub out of `total` and back in when the list is emptied; the old-row replay; the bool false on an old save and true after the action.
Limits: the retreat and return-home handlers are not dispatched. The builder is called with the cause. The real retreat dispatch is covered by `retreat` and `venture_char` (they pass except the key list below).

Dispatch-action-count guard: `flow_transaction/dispatch_action_count_is_77` counted the match arms in `FlowRuntime.dispatch()`. The new arm makes 78. I set `EXPECTED_ACTION_COUNT := 78` and renamed the test `..._is_78` in `tests/FlowTransactionTests.gd`. This file is outside your edit list. It is a guard count, not a recorded hash. MEASURED: `flow_transaction` passes with 78.

## 5. MEASURED results (`ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase3c`, deleted before each run)

| Filter | `Tests:` line |
|---|---|
| `=econ_char,realm_reward,economy,objective` | 64 total, 64 passed, 0 failed |
| `=venture_char,pending_result,save_integrity,unified_resolve,foundation_ui,snapshot_contract,retreat,flow_transaction` | 101 total, 100 passed, 1 failed |
| `=snapshot_fingerprint,snapshot_purity` | 14 total, 14 passed, 0 failed |

Compile check: no error.
The one failure: `venture_char/retreat_success_snapshot_is_scout_return`. It pins the data key list of the scout-return card. The list now has `ledger_seen`. I did NOT edit it (it is a pinned baseline; your rule). Fix is one word added to `expected_data_keys` at `tests/VentureCharacterizationTests.gd:694`: `"ledger_seen"` between `"intel_count"` and `"rank"`.

## 6. PREDICTED moved values (no constant edited)

Harness read: `FlowFingerprintTests._final_fingerprint` hashes `data.keys()` (KEY NAMES, sorted) of `flow_ctx.last_snapshot`, plus scalar values. It does not hash `reward_breakdown` rows. `_save_fingerprint` hashes only `economy.ase`, `economy.ekwan` and the party (xp, level, rank). It does NOT carry `ui_flags`.

| Recorded value | Moves? | One cause |
|---|---|---|
| `*_FINAL_HASH` for combat, purify_shrine, recover, protect, endure, pursue, guide_spirit (`FlowFingerprintTests`) and the seek `FINAL` hash (`FlowFingerprintSeekTests`) | PREDICTED yes | Producer A now writes the new key `ledger_seen`, so `data_keys` gains one name. |
| `*_ROUNDS_HASH`, `*_SAVE_HASH` | PREDICTED hold | Rounds are before any reward read. The save fingerprint has no `ui_flags` and no payout number changed. |
| `fingerprint_determinism_*` | PREDICTED hold | Self-checks with no constants. |
| `combat_baseline`, `combat_roundtrip` | PREDICTED hold | They pin ticks, save reasons and outcomes, not the Resolve key list. `combat_roundtrip` line 649 only checks that forced_retreat `reward_breakdown` is empty; it is (no row for a forced retreat). Not run. |
| `venture_char` scout-return key list | MEASURED yes | Same new key (section 5). |
| `snapshot_fingerprint`, `snapshot_purity`, `snapshot_contract` | MEASURED hold | |

If you want zero fingerprint movement, the alternative is to drop `ledger_seen` from producer A and read it from the save in the UI. I did not do that: the brief asks for the value in the Resolve snapshot data.

## 7. RUN REQUEST (main chat runs; I do not)

1. Command (the fingerprint group; it shows the PREDICTED FINAL drift, 8 expected failures with new `actual=` hashes):
   `rm -rf /tmp/echoes-econ004-3c-fp; ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-3c-fp /usr/bin/perl -e 'alarm shift; exec @ARGV' 1800 /opt/homebrew/bin/godot --headless --quit --path /Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/echoes-vnext-test-timing-9693e6 -- tests =fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue,fingerprint_guide_spirit,fingerprint_seek,combat_baseline,combat_roundtrip` with tool `timeout` 1900000.
2. Expected duration: about 1500 s serial (shard-map comments: 279 + 344 + 490 + 194 s, plus the small ones).
3. Files the run edits: none. The suites write only under the `ECHOES_TEST_SAVE_DIR` directory.
4. Restore check: `git status --short` shows the same list as before the run; `git diff --stat -- data tests` is unchanged.
5. Read back: each `Tests:` line and each `❌` line with `expected=` and `actual=` (copy raw). Expect the failures only in the FINAL hashes, with ROUNDS and SAVE held.
6. Optional second command, `reward` suite: not needed for this phase. No reward number changed; I did not run it (your rule).

Dispatch-action-count guard: suite `flow_transaction` (short; already run, passes).

## 8. Findings (report only, not fixed)

1. The stage payout breakdown (`objectives_overcome`, `realm_virtue`, stage `replay`) reaches no snapshot. `VentureController.handle_complete_stage` calls `StageSettlementService.settle()` and drops the return value (`VentureController.gd:680`). The UI cannot show these rows until a producer carries them. This needs a decision on where the stage rows show.
2. `EconomyService.gd` header comments (the Phase 8 block above `reward_encounter_complete`) still say the consolation reads "the stage base" and "25% of the stage". Stale since Phase 3b (already reported there).
3. `ResolveSnapshotBuilder.gd` header says "SIXTEEN BLOCKS"; `PendingResultService` says "SEVENTEEN". Both are stale; there are now more.
4. Producers B (`EncounterSnapshotBuilder.gd:626`) and E (situation "Found" card) emit no `ledger_seen`. Producer B is pure and takes no `FlowContext`; E has no payout cause. Add if the UI shows a ledger there.

## OPEN — questions and assumptions

ASSUMED: The two defeat rows ("Base objectives", "Defeat penalty") both carry `defeat_consolation` with `params.part` | WHY: the brief lists one `defeat_consolation` id; the code emits two rows | WRONG IF: the UI wants one merged row (a change in `EconomyService.gd:175-176`).

ASSUMED: The labels "Repeat defeat" and "Nothing overcome yet" for the new delta-0 rows | WHY: a row needs a `label`; the UI is meant to use the cause | WRONG IF: Jeff wants other wording (his call; these are PROPOSALS, not player copy).

ASSUMED: A zero-partial `nothing_overcome_yet` row appears on every non-forced retreat or return home with nothing overcome, also when no situation was revealed | WHY: the brief says "partial payout before any objective is overcome" | WRONG IF: the row should appear only when intel was revealed.

ASSUMED: Field `ui_flags.result_ledger_seen`, action `resolve.ledger.mark_seen`, snapshot key `data.ledger_seen` | WHY: no existing player-seen area exists; the brief asked me to propose names | WRONG IF: the UI session fixed other names.

ASSUMED: Editing `tests/FlowTransactionTests.gd` (guard count 77 to 78) is in scope | WHY: a new dispatch arm makes that guard fail otherwise | WRONG IF: you want that file untouched.

ASSUMED: Leaving `venture_char` red on the key list is right | WHY: your rule bars editing baseline constants | WRONG IF: you accept the one-word key-list fix now.

BLOCKED: Where do the stage payout rows (finding 1) reach the UI? | CHECKED: `VentureController.gd` `handle_complete_stage`, `StageSettlementService.settle` | NEED: Jeff's decision.
