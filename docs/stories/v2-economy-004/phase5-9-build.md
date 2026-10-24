# Phase 5.9 build — optional objectives are skippable; guide_spirit is required

Decisions: D-82, D-83. Status: built, compiled, short suites green. Not committed.

## The gate rule

A stage can complete when:
1. every REQUIRED objective is completed, AND
2. at least one non-boss objective is completed (overcome).

Term 2 keeps the D94 guard. A stage with no required objective (for example `pursue` plus the
boss stub) cannot complete on entry or on dismissing a popup. In that stage `pursue` must be
overcome. The boss stub never counts. A skipped optional objective pays nothing (D-11, already
built). The rule no longer reads `objectives_found`.

Where it lives: `ObjectiveModel.stage_completable(objectives)` in `core/realms/ObjectiveModel.gd`.
One function, one comment.

## Callers checked

| Caller | Result |
|---|---|
| `StageExploreSnapshotBuilder.build` (slot `cta.proceed_to_stage_map`, action `flow.complete_stage`) | Now calls `ObjectiveModel.stage_completable(objectives)`. The old `objectives_reached` term and the long D94 comment are removed. |
| `EncounterSnapshotBuilder._count_remaining_required_objectives` (feeds `_build_resolve_actions`, the stage payout block in `FlowEncounterState`, and `PendingResultService.classify`) | Returns 1 when no required objective is open but the stage is not completable. So the resolve card does not offer `cta.next_stage` on a stage with nothing overcome. Only the edge case changes: a non-objective fight won in a zero-required stage. The stage-explore snapshot field `objectives_remaining` is unchanged (still required-and-open count). |
| `VentureController.handle_complete_stage` | Does NOT re-validate. It trusts the offered action. No change. A hand-sent `flow.complete_stage` action is still accepted (as before). See OPEN. |
| `VentureController` line 631 (`party_state = STATE_COMPLETE` when `objectives_found >= objectives_total`) | Not a gate for the button. Not changed. It sets a state flag only after a combat victory. |
| `FlowStageExploreState._all_required_objectives_complete` | Only fires an Anansi snippet. Not a gate. Not changed. |

## Config

`data/balance.json` `data.stages.objective_types.guide_spirit.required`: false to true.
`combat`, `shrine`, `recover`, `protect`, `endure` are already true. `pursue` stays false.
Nothing in `core/` reads this flag. `_build_objective_entries` reads only `label` and
`reveal_hint`. The `required` flag on an objective comes from `RealmGenerator`, which is not
changed. So the config flag is documentation that now matches the generator. D95 is closed.

## Generation does not change

`RealmGenerator.gd` is untouched. No RNG draw changed. The new test
`objective/generated_required_flags_unchanged` generates 6 stages for each of 40 seeds with the
full 7-type pool and checks: every pre-boss objective is required except `pursue`, the boss is not
required, and each type's config flag equals the generated flag.

## Tests (suite `objective`, 26 tests, all pass)

Changed:
- `objective/zero_required_blocked_until_reached`: second half now checks that reaching
  (`objectives_found`) does NOT open the gate, and that completing `pursue` opens it. This test
  asserted the old "reached" rule.

Added:
- `optional_skipped_completable`: required done, optional skipped: open.
- `required_open_blocks_despite_optional_done`: required open, optional done: closed.
- `zero_required_optional_overcome_completable`: zero required: closed, then open after `pursue`.
- `boss_never_counts`: a completed boss, a boss only, and an empty list are not completable.
- `skipped_pays_completed_only_once`: payout with a skipped optional equals payout without it (Ase,
  Ekwan, row delta); `settle` pays once, the second call returns {} and the balance is unchanged.
- `resolve_gate_agrees`: resolve count is non-zero with nothing overcome, zero after.
- `guide_spirit_required_in_config`, `generated_required_flags_unchanged`.

Unchanged and still green: `required_stage_gate_unchanged`, `stage_advance_unlocked` (their
fixtures complete a required combat objective, which satisfies both terms).

## Short-suite results (`ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase59`, deleted before each run)

All `Tests:` lines show 0 failed: objective 26/26, seam 44/44, stage 10/10, explore 16/16,
explore_p5 28/28, econ_char 60/60, realm_reward 3/3, economy 9/9, venture_char 16/16,
pending_result 8/8, save_integrity 22/22, unified_resolve 13/13, foundation_ui 17/17,
snapshot_contract 8/8, snapshot_fingerprint 2/2, snapshot_purity 12/12, retreat 15/15,
flow_transaction 9/9, realm 8/8, realm_prog 8/8, realm_ui 20/20.

## PREDICTED moved values

| Value | Prediction | Cause |
|---|---|---|
| `STAGE_EXPLORE_FINGERPRINT_HASH` and `snapshot_fingerprint` | No move (2/2 pass now) | Snapshot shape and fixture values are unchanged. Only the offer of one action changed. |
| `fingerprint_*` stage-explore fixtures (group in RUN REQUEST) | No move expected | Same cause. Moves only if a fixture has an objective reached but not completed. |
| Seed-based generation hashes (`fingerprint_seek`, `maturity_baseline`, baselines) | No move | Generator and RNG draws untouched. |
| `Stage004SeamTests` fixtures | No move (44/44 pass) | None. |

If any value moves, the cause is the gate change in one fixture. Do not re-record without the cause.

## Snapshot facts for the UI sessions (no UI edited)

Stage-explore snapshot `data` has: `objectives` (entries with `type`, `label`, `reveal_hint`,
`completed`, `required`), `objectives_total`, `objectives_found`, `objectives_remaining`
(required and open only). Slot `cta.proceed_to_stage_map` appears when the gate is open.

Gaps:
1. `objectives_remaining` counts only required objectives. When the button is open, an optional
   objective can still exist undone. The UI can show it from `objectives` entries
   (`required == false` and `completed == false`, type not `boss`). No new field is needed.
2. The button label is "Stage Complete". It does not say that a skipped objective pays nothing.
   Copy is Jeff's (D-84).
3. The payout card row `objectives_overcome` shows overcome of total, so a skipped objective shows
   as not overcome. No other row changed.
4. The boss stub appears in `objectives` as an optional, never-completed entry. The UI should not
   present it as a skipped objective.

## RUN REQUEST (main chat runs these; run each group SEPARATELY)

Files edited by the run: none. Restore check: `git status --short` must show only the Phase 5.9
files listed below. Delete the save dir before each group. Read the raw `Tests:` and any
`❌` lines back.

Group A (fingerprints; about 2 to 5 minutes; timeout 900000, alarm 800):
```bash
cd /Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/echoes-vnext-test-timing-9693e6
rm -rf /tmp/echoes-econ004-phase59
ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase59 /usr/bin/perl -e 'alarm shift; exec @ARGV' 800 /opt/homebrew/bin/godot --headless --quit --path "$PWD" -- tests fingerprint
```
Group B (snapshot_fingerprint; short; timeout 300000, alarm 200):
```bash
rm -rf /tmp/echoes-econ004-phase59
ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase59 /usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --quit --path "$PWD" -- tests =snapshot_fingerprint
```
Group C (reward, its own group; timeout 900000, alarm 800):
```bash
rm -rf /tmp/echoes-econ004-phase59
ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase59 /usr/bin/perl -e 'alarm shift; exec @ARGV' 800 /opt/homebrew/bin/godot --headless --quit --path "$PWD" -- tests =reward
```
Group D (seek + baseline + roundtrip + maturity; needs a quiet machine; timeout 3400000, alarm 3300):
```bash
rm -rf /tmp/echoes-econ004-phase59
ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase59 /usr/bin/perl -e 'alarm shift; exec @ARGV' 3300 /opt/homebrew/bin/godot --headless --quit --path "$PWD" -- tests =fingerprint_seek,combat_baseline,combat_roundtrip,maturity_baseline
```
Note for group A: the filter `fingerprint` also matches `fingerprint_seek`. Run Group D after A, or
change A to the exact list of the 14 `fingerprint_*` combat/determinism names if A is too slow.

## Files changed

- `core/realms/ObjectiveModel.gd` (new `stage_completable`)
- `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd` (gate)
- `core/state/flow/states/venture/EncounterSnapshotBuilder.gd` (resolve count)
- `data/balance.json` (guide_spirit required)
- `tests/StageObjectiveTests.gd`
- `docs/stories/v2-economy-004/phase5-9-build.md` (this file)

Not mine: `docs/stories/v2-economy-004/follow-ups.md` shows a modified row 24 in `git status`. The
tree was clean at the start of this task, so another session edited it.
