# V2-ECONOMY-004 Phase 5.10: `data.intel_gained` on the combat victory card

## Field for the UI session

- Key: `snapshot.data.intel_gained` (int), on the combat Resolve victory card (producer A).
- The key is present only when the count is above 0. Read it with `data.get("intel_gained", 0)`.
- It is absent on a defeat, on a victory that revealed nothing, and on every other Resolve producer.
- The replayed card (`PendingResultService.build_snapshot`) keeps the key. The stored `resolve_data` holds it.

## Finding: no fight reveals a situation today

A search of `core/` for every write to a situation `revealed` flag found these writers:
`SituationEngagementService` (on engage, before the fight starts), `ContactController` (conversation
and hostile-claimant paths, before the fight), `FlowStageExploreState` (explore step),
`ActiveStageService` and `VentureController` (mark the fought situation resolved; it is already revealed).
None of them reveals a new situation while combat runs. So `intel_gained` is absent in every real game
today. The code is a measurement seam: it starts to report as soon as a future change reveals a
situation during a fight. I did not add a reveal mechanic.

## Design

- `FlowContext.encounter_start_revealed_count` (int, -1 = no fight, volatile, not saved).
- `EncounterSetupService.setup` sets it when it creates the encounter context, using
  `ActiveStageService.count_revealed_situations`.
- `FlowEncounterState.build_final_snapshot`: on a victory, `maxi(0, current - start)` goes to the new
  `ResolveSnapshotBuilder.add_intel_gained`, which writes the key only when above 0.
- Reset to -1 in `FlowEncounterState.exit` and in the `VentureController` encounter clean-up.
  `build_final_snapshot` does not reset it, so a second build gives the same answer.
- `PendingResultService.build_snapshot` replays the key through the same builder function.
- No save change. `resolve_data` already stores the whole `data` dictionary; the new key only
  appears there when above 0.

## Tests (in `tests/EconomyCharacterizationTests.gd`)

- `econ_char/intel_gained_absent_zero_present_count_absent_on_defeat`: setup records the start count;
  absent with 0 reveals; present as 1 and as 2; absent on a defeat that also revealed 2.
- `econ_char/intel_gained_replays_from_stored_result`: stored result and replayed card keep 2; a zero card
  replays with no key.
- The fixture `_final_card` takes a new optional argument `revealed_during_fight`. It reveals
  situations by writing the save after setup, because no production path does it. The setup, the card
  build and the capture all use production code.

## Predicted moved values

None. A card with 0 reveals keeps its key list, so fingerprints do not change. No balance, seed or
save value changes. The test shard counts change: `econ_char` gains 2 tests (`scripts/test-shard-map.sh`
counts may need a refresh by the owner of that file; I did not edit it).

## Results

Filtered runs, own save dir: 194 of 194 (econ_char, objective, seam, stage, explore, explore_p5,
pending_result), 70 of 70, 52 of 52, 62 of 62. Compile check: no errors.
