# V2-ECONOMY-004 Phase 5.11: stage death record, `thread_whole`, `objective_overcome`

## Fields for the UI session

All fields are on `snapshot.data` of the combat Resolve card (producer A, `FlowEncounterState.build_final_snapshot`).

| Key | Type | When present |
|---|---|---|
| `thread_whole` | bool | Always on a combat VICTORY card. Absent on defeat and on every other Resolve producer. |
| `objective_overcome` | `{ index: int, type: String, label: String }` | Only on a combat victory card where THIS fight completed an objective. Absent otherwise. |
| `stage_payout_rows[].params.lost` (cause `echoes_alive`) | Array of String (display names) | Now holds ALL party Echoes that died in the stage so far, in order of death. |
| `stage_payout_rows[].params.alive` | int | Echoes of the last fight's party that are not in `lost`. |

- `thread_whole` is true when no party Echo has died in this stage so far (D-50). It can only change from true to false inside one stage.
- `label` comes from `data.stages.objective_types[type].label` in `balance.json` (for example "Clear"). It is `""` if config has no label.
- The replayed card (`PendingResultService.build_snapshot`) keeps both keys with the stored values.
- Read both keys with `data.get(...)`: `thread_whole` defaults to absent on old stored results.

## Design

**Death record.** New additive field on the STAGE record: `lost_echo_names` (Array of display names; unique; order of death; no ids).
An old save has no field and reads as empty (`.get` with a default). No save migration. A re-run of a realm builds a fresh stage record, so the list starts empty again.

**Where it is written.** `ActiveStageService.record_fight_deaths(t)`. `FlowRuntime._end_round` calls it once, in the `combat_over` branch, before the victory resolve and before `build_final_snapshot`. It runs on a victory and on a defeat. It writes only when the list grows, then calls `request_save("stage.echo_lost")` and logs `stage.echo_lost`.
`build_final_snapshot` writes nothing to the record (checked by test).

**One place for the rule.** `ActiveStageService.lost_echo_names_with(flow_ctx, actors)` = stored names + the dead party Echoes of `actors` (faction echo, not ally, not spirit), unique, in order. It is pure. Two readers use it:
- `thread_whole` = `lost_echo_names_with(...).is_empty()` (in `build_final_snapshot`).
- `StageSettlementService._echo_home` (stipend row, so preview and payer share it).
The permadeath story (D-66) changes only this function.

**Stipend row.** `lost` = the union. `started` = the last fight's party (unchanged). `alive` = party Echoes that are not dead and whose name is not in the union (`RewardCalc.echo_tally(actors, prior_lost)`). The cap rules, rate and replay cap are unchanged. Preview and payer both call `_echo_home`, so preview == paid (test).

**`objective_overcome`.** `FlowEncounterState._objective_overcome`: reads `flow_ctx.active_encounter_objective_index` (the same index the reward uses). It is present when the index is valid and that stage objective has `completed == true` after the pre-snapshot resolve (`FlowRuntime`, victory). Victory only.

**Replay.** `PendingResultService.build_snapshot` rebuilds the card from a key list. I added both keys there. `resolve_data` already stores the whole `data`.

## Findings

1. A fight that ends by retreat does not reach the `combat_over` hook. Deaths in a retreated fight are not recorded. Retreat ends the stage run, so the Thread and the stipend do not matter after it, but a retreat then a return to the same stage would lose those names. I did not change this.
2. The record keys on display NAMES. Two Echoes with the same name count as one. Names are unique per summon in normal play.
3. The harness `_setup_encounter` sets `active_encounter_objective_index = 0`. The econ_char fixture `_final_card` links objective 0 to a situation, so `objective_overcome` IS present on those cards (the brief expected absent). The seven fingerprint fixtures do not link a situation, so there it is absent.
4. The `FlowRuntime` call to `record_fight_deaths` runs inside `_end_round`. No test drives `_end_round` with a death. The tests call the service the same way. Probe that would show it: play a stage, lose one Echo in fight 1, win fight 2, read `lost_echo_names` in the save file and the card.

## Tests (in `tests/EconomyCharacterizationTests.gd`, suite `econ_char`)

- `death_record_carries_to_later_fight`: builder is pure; fight 1 death is recorded once; fight 2 (no deaths) card has `thread_whole` false, row `lost` has the name, `alive` 4 of 5; `flow.complete_stage` pays the previewed 58; same Echo twice stays one name; second Echo appends in order.
- `thread_whole_and_objective_overcome_keys`: clean win true; death in this fight false; `objective_overcome` {0, combat, Clear}; absent with no linked objective; both keys absent on defeat.
- `death_record_old_save_and_replay`: stage without the field reads empty; replayed card keeps both keys.
- No existing test asserted `lost` from the last fight in a way that broke; none needed an update.

## Moved values

Predicted (one cause each):
- `thread_whole` is a new always-present key on the combat victory card. The final-snapshot `data_keys` list gains one key. The 14 `*_FINAL_HASH` constants in `tests/FlowFingerprintTests.gd` (seven modes, plus the seven determinism checks) move, for every mode that ends in victory. A mode that ends in defeat would hold.
- SAVE hashes hold: `_save_fingerprint` hashes only ase, ekwan and the party. The stage record is not in it.
- ROUNDS hashes hold: no round data changed.
- `objective_overcome` is absent in the fingerprint fixtures (no linked situation), so it adds no key.
- Other recorded key lists (`snapshot_fingerprint`, `snapshot_contract`, `venture_char`) passed unchanged in my filtered runs.

I did not edit any fingerprint or baseline constant.

## RUN REQUEST (for the main conversation)

Run two batches. Delete the save directory before each run. Run the groups one after the other.

Batch 1:
```bash
for g in fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue,fingerprint_guide_spirit fingerprint_determinism_combat,fingerprint_determinism_purify_shrine,fingerprint_determinism_recover,fingerprint_determinism_protect,fingerprint_determinism_endure,fingerprint_determinism_pursue,fingerprint_determinism_guide_spirit fingerprint_seek combat_baseline,combat_roundtrip; do
  rm -rf /tmp/echoes-econ004-phase511
  ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase511 /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path "$(git rev-parse --show-toplevel)" -- tests =$g 2>&1 | grep "Tests:\|  ❌\|expected\|got"
done
```
Batch 2:
```bash
for g in maturity_baseline reward; do
  rm -rf /tmp/echoes-econ004-phase511
  ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase511 /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path "$(git rev-parse --show-toplevel)" -- tests =$g 2>&1 | grep "Tests:\|  ❌\|expected\|got"
done
```
- Tool `timeout`: 3700000 per Bash call. Expected duration: minutes per group (the `reward` group is its own run).
- Files edited by the run: none. No `trap` needed.
- Restore check: `git status --short` must show only the files of this phase (see the list in the report); no change under `data/` or in `tests/` from the run.
- Read back: the raw `Tests:` lines and every failing line. Expected failures: the FINAL hash assertions of the 14 fingerprint suites (seven plus seven determinism) and nothing else. Report each new hash with its suite. A failing ROUNDS or SAVE hash is NOT predicted: stop and diagnose.
