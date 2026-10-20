# V2-ECONOMY-004 Part A — Phase 3d build (stage payout preview on the Resolve card)

Written in STE. Tags: READ = seen in code. MEASURED = I ran it. PREDICTED = not run.
Scope: D-24. Payment, receipt stamp and exactly-once behaviour are unchanged. Ekwan is unchanged (Phase 4).

## 1. Design

| Item | Where |
|---|---|
| One row producer for the stage payout (Ase rows and Ase total) | `EconomyService.stage_payout_rows()` (`EconomyService.gd`, static, pure) |
| Payer uses it | `EconomyService.settle_stage_complete()` (adds the Ekwan row after it, as before) |
| Shared inputs (base, redo, virtue, counts, Ekwan factor) | `StageSettlementService._plan()` |
| Settle uses `_plan()` | `StageSettlementService.settle()` (same order of logs as before) |
| Preview | `StageSettlementService.preview()` returns `{rows, ase}`, or `{}` if the stage cannot be found or is already settled. It makes no RNG call, no save write, no log, no receipt. |
| Snapshot block | `ResolveSnapshotBuilder.add_stage_payout(data, rows, ase)` |
| Producer | `FlowEncounterState.gd` (after `add_ledger_seen`), only when `victory and objectives_remaining == 0` (the same condition that offers `flow.complete_stage` in `_build_resolve_actions`) |
| Replay | `PendingResultService.build_snapshot` copies the stored keys when present (stage is unsettled, so the stored preview stays valid) |

New snapshot data keys (PROPOSED names):
- `stage_payout_rows`: Array of Ase rows `{label, delta, currency, cause, params}` with causes `objectives_overcome`, `replay` (absent when it does not apply), `realm_virtue`.
- `stage_payout_ase`: int, the previewed stage Ase total.

Ekwan: the preview has NO Ekwan figure and no Ekwan row. It was not needed. Today's formula stays in `settle()` only.

The no-encounter clear (stage-explore card, `StageExploreSnapshotBuilder.gd:388`) is NOT a Resolve card and carries no preview. It is not covered. Say if the UI needs it.

Also done: the stale Phase 8 header comment in `EconomyService.gd` (consolation base) and the `base_reward` parameter doc now say the consolation reads the fought objective's weight.
Not touched (report only): "SIXTEEN BLOCKS" in `ResolveSnapshotBuilder.gd:29` and "SEVENTEEN-BLOCK LIBRARY" in `PendingResultService.gd:398` are still stale.

## 2. Tests (MEASURED)

New in `econ_char`: `stage_preview_equals_paid`. For stage 0 and stage 2, run_count 0 and 1, on the same state it checks:
preview rows == paid Ase rows; preview Ase == paid Ase and the balance; two previews equal; `save_data` byte-identical after the previews; the base row is the completed-only 10; a settled stage previews `{}`.
Key lists: `tests/VentureCharacterizationTests.gd` scout-return list gained `"ledger_seen"` with one comment line. The contact-resolve list needed no change (producer D does not emit the ledger).

| Filter | `Tests:` line |
|---|---|
| `=econ_char` | 33 total, 33 passed, 0 failed |
| `=realm_reward,economy,objective,venture_char,pending_result,save_integrity,unified_resolve,foundation_ui,snapshot_contract,retreat,flow_transaction,snapshot_fingerprint,snapshot_purity` | 147 total, 147 passed, 0 failed |

Compile check: no error. I did not run `reward` or the full suite.

## 3. What no test observes

No short test builds a real victory card through `FlowEncounterState`. So the new keys on producer A are NOT observed by a passing test. The fingerprint run below shows them: `FP_DEBUG ... final=` prints `data_keys`. Probe: run `=fingerprint_combat` alone and read `data_keys` in that line. Expect `ledger_seen`, `stage_payout_ase`, `stage_payout_rows`.

## 4. PREDICTED moved values (no constant edited)

The harness hashes the KEY NAMES of `flow_ctx.last_snapshot.data` (`FlowFingerprintTests._final_fingerprint`), and not the rows. `_save_fingerprint` hashes ase, ekwan and party only.

| Recorded value | Moves? | One cause |
|---|---|---|
| `*_FINAL_HASH`: combat, purify_shrine, recover, protect, endure, pursue, guide_spirit, seek | PREDICTED yes | Producer A adds `ledger_seen` (3c), and `stage_payout_rows` and `stage_payout_ase` (3d) when the fight is a won last objective. |
| `*_ROUNDS_HASH`, `*_SAVE_HASH` | PREDICTED hold | Rounds run before any reward read. The save fingerprint has no `ui_flags`, and no payout number changed. |
| `fingerprint_determinism_*` | PREDICTED hold | Self-checks, no constants. |
| `combat_baseline`, `combat_roundtrip` | PREDICTED hold | They pin ticks, save reasons and outcomes, not the key list. |
| A FINAL hash that holds although the fight is a win | would show the preview is `{}` there | Then the harness stage has no active realm model, and the keys are absent. |

## 5. Combined RUN REQUEST for 3c and 3d (main chat runs)

1. Command (fingerprints and baselines; expect FINAL-only failures):
   `rm -rf /tmp/echoes-econ004-3cd-fp; ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-3cd-fp /usr/bin/perl -e 'alarm shift; exec @ARGV' 1800 /opt/homebrew/bin/godot --headless --quit --path /Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/echoes-vnext-test-timing-9693e6 -- tests =fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue,fingerprint_guide_spirit,fingerprint_seek,combat_baseline,combat_roundtrip` with tool `timeout` 1900000.
2. Command (the suites that hold key lists and the new tests; short, about 80 s):
   `rm -rf /tmp/echoes-econ004-3cd-short; ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-3cd-short /usr/bin/perl -e 'alarm shift; exec @ARGV' 600 /opt/homebrew/bin/godot --headless --quit --path <same checkout> -- tests =econ_char,realm_reward,economy,objective,venture_char,pending_result,save_integrity,unified_resolve,foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity,retreat,flow_transaction` with tool `timeout` 700000.
3. Expected duration: command 1 about 1500 s (shard-map: 279 + 344 + 490 + 194 s plus small ones); command 2 about 80 s.
4. Files the run edits: none (suites write under `ECHOES_TEST_SAVE_DIR` only).
5. Restore check: `git status --short` and `git diff --stat` show the same list and counts as before the run.
6. Read back: every `Tests:` line; every `❌` line with `expected=` and `actual=` copied raw; the `FP_DEBUG ... final=` line of `fingerprint_combat` (to see `data_keys`).
   Dispatch-action-count guard: suite `flow_transaction`, test `dispatch_action_count_is_78` (in command 2).

## OPEN — questions and assumptions

ASSUMED: The preview rides on producer A only, when `victory and objectives_remaining == 0` | WHY: that card is the one that offers `flow.complete_stage`; the stage-explore card is not a Resolve card | WRONG IF: the UI needs the preview on the no-encounter clear.
ASSUMED: Key names `stage_payout_rows` and `stage_payout_ase` | WHY: brief proposed them | WRONG IF: the UI session fixed other names.
ASSUMED: The stored preview in a durable result is replayed as is | WHY: the stage is unsettled until `flow.complete_stage`, which consumes the result | WRONG IF: a realm re-roll can change `run_count` between capture and replay.
ASSUMED: No Ekwan figure in the preview | WHY: Phase 4 changes Ekwan; the brief said to avoid it | WRONG IF: the card should show "Ekwan earned" from the preview.
BLOCKED: none.
