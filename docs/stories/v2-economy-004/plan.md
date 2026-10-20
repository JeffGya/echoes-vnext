# V2-ECONOMY-004 Part A — plan (APPROVED by Jeff, 2026-10-19)


Written in STE. Decisions D-01 to D-07 are in `docs/stories/v2-economy-004/decisions.md`.
Branch: `claude/v2-economy-004-material-split-24c3be` (clean, contains `main`).

## Context

Early playtests show that Ase and Ekwan rewards are too high. Jeff says Ase overflows and has few sinks, so
rewards must feel hard to earn (D-04). The code also has defects that hide the real payout:

- D66 and D83: two sites read `obj_type`, but `ObjectiveModel.make()` writes `type`. The shrine Ekwan
  multiplier never applies. Sites: `core/economy/StageSettlementService.gd:145-150` and
  `core/state/flow/states/venture/FlowEncounterState.gd:209-215`. `FlowEncounterState.gd:346` also uses
  `_obj_type` (`_combat_surface`). The effect of the repair there is unknown.
- `RewardCalc.base_reward` (`RewardCalc.gd:26`) sums `objective_weights` over all objectives. Weights exist for
  `combat` 30, `shrine` 40 and `boss` 60 only. The boss stub is on every stage, so it pays 60 per stage.
  Five types (`recover`, `protect`, `endure`, `pursue`, `guide_spirit`) pay 0 silently.
- Ekwan is only a percentage of the Ase paid (`ekwan_base_factor` 0.12), in two payers:
  `EconomyService.settle_stage_complete` (`:211`) and `reward_encounter_complete` (`:131`).

Part A fixes these, gives Ekwan its own source, and lowers the numbers. Item-cost shapes (Part B) and
ITEM-001 are other stories (D-01).

## Scope rules

- Not in scope: D95, D96, UI, Notion edits, GDD edits, item or recipe model, Ase sinks.
- Save changes additive only. No RNG draw reorder. Exactly-once payout stays in `StageSettlementService`
  with `settlement_receipt`.
- No hard-coded tunables: new numbers go to `data/balance.json` under `data.rewards` (ANSWERS #83).
- One commit per phase. Each moved recorded value gets one named cause. Commit and push only when Jeff asks.
- Player-facing text ("Sanctum share") is not changed. Proposals only, later.

## Phases

### Phase 1 — Characterize (no behavior change)
Goal: record what the code pays today, defects included, and the Ase prices.
- New probe/test (agent picks the file name under `tests/`, registered as a suite; shard map updated).
  Records, per objective type, stage index and realm run: base reward, virtue bonus, redo multiplier, Ase,
  Ekwan, for the stage payer and the encounter payer.
- Lists every Ase and Ekwan sink with its price (`spend_ase` sites: `FlowRuntime.gd:1173`,
  `SanctumController.gd:188`, `EconomySettlementController.gd:112`, `ProgressionController.gd:444`,
  `VowService.gd:342`; `spend_ekwan`: `VowService.gd:344`, `InstitutionService.gd:103`; costs in `balance.json`).
- Measures the real objective draw pool of `realm.01` and `realm.02`. The generator can use a per-realm
  `objective_pool` (`RealmGenerator.gd:204-213`), so "5 of 7 types pay 0" is not yet verified.
- Labels each defect `# KNOWN DEFECT (<phase> will change this):`.
- Output for Jeff: a table of Ase and Ekwan per stage and per full `realm.01` run against sink prices.
- Agent: `mechanics-developer`, sonnet. Long runs: RUN REQUEST, main chat runs them.

### Phase 2 — Field repair (D66, D83)
- Both sites read `type`. Both change in one commit so per-encounter and per-stage Ekwan agree.
- Check `FlowEncounterState.gd:346` and report what changes there.
- Invert the Phase 1 assertions for the shrine path.
- Re-record the moved values once (`FlowFingerprintTests`, `CombatBaselineTests`, any shrine payout test),
  each with a written cause. Use the commit `091bcfd` format as the example.
- Agent: `mechanics-developer`, sonnet. Attribution of moved values: opus.

### Phase 3 — Vocabulary and validation (D-02, D-03, D-07)
- `mid-game-designer` proposes one Ase weight per unweighted type, marked PROPOSAL. Jeff approves each one first.
- Boss weight leaves live payout: `RewardCalc.base_reward` skips the boss stub through config, not a hard-coded type
  (agent proposes the config shape; Jeff approves).
- An objective type with no weight logs an error through `StructuredLogger` and pays 0. It never defaults to
  `combat`. A test asserts the log line.
- Tests: combat, shrine, partial run, multi-objective stage, unknown type (Notion addendum list).
- Agent: `mid-game-designer` (sonnet) for numbers; `mechanics-developer` (sonnet) for code.

### Phase 4 — Ekwan source (D-05, D-06)
- New additive config: an Ekwan amount per objective type under `data.rewards`. Ekwan for a stage is the sum
  over all objectives, as the Ase base is.
- `settle_stage_complete` and `reward_encounter_complete` take Ekwan from the new source. Resolve-card fields
  (`ekwan_awarded`, `PendingResultService.gd:314,464`) keep their shape.
- Keys `ekwan_base_factor` and `ekwan_shrine_multiplier` lose their job. Removing them needs the AGENTS.md
  rename exception (full-repo audit of `core/`, `ui/`, `tests/`, `docs/`). Jeff decides: remove or keep inactive.
- Per-encounter Ekwan: Jeff decides whether it keeps a share of the encounter Ase or pays none.
- Agent: `mechanics-developer`, sonnet; opus for attribution of moved values.

### Phase 5 — Tuning (D-04)
- Jeff reads the Phase 1 table and sets targets (for example: stages needed for a first summon).
- `mid-game-designer` works the Ase weights, Ekwan amounts, `virtue_bonuses`, `stage_index_bonus_per` and
  realm-order step back from the targets. Jeff approves every number.
- Lower Ase. Account for the redo multiplier keying on realm `run_count`, and for the first-realm `run_index`
  fix (`61ffcf8`): older tuning used inflated numbers.
- Re-record once. Own commit.

### Phase 6 — Verify and close
- `qa-verifier` checks the combined tree: diff, source, and real `Tests:` lines. Claim to attack: "each moved
  value has one cause, and no payout is double-paid or lost".
- CI runs the full sharded suite on the pull request. No local full run.
- Jeff tests in game. Docs update: `docs/MEMORY.md`, `docs/integration-map.md`, defect register note for D66/D83,
  `ANSWERS.md` only for project-wide answers. Commit when Jeff asks.

## Files expected to change

`core/economy/RewardCalc.gd`, `StageSettlementService.gd`, `EconomyService.gd`;
`core/state/flow/states/venture/FlowEncounterState.gd`; `data/balance.json` (`data.rewards`);
tests: `EconomyRewardTests.gd`, `StageObjectiveTests.gd`, `VentureCharacterizationTests.gd`,
`FlowFingerprintTests.gd`, `CombatBaselineTests.gd`, one new characterization suite;
`scripts/test-shard-map.sh` and the suite counts in `AGENTS.md` if a suite is added.
Reuse: `RewardCalc.base_reward` and `redo_multiplier`, `RealmService.calculate_stage_reward`
(`RealmService.gd:320`), `ConfigService.get_rewards_cfg`, `EconomyService.add_ase/add_ekwan`.

## Test plan

Commands (replace `<checkout>` with the worktree path; each agent sets its own `ECHOES_TEST_SAVE_DIR` and deletes it first):

```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --check-only --quit --path <checkout>
/usr/bin/perl -e 'alarm shift; exec @ARGV' 200 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =realm_reward,economy,objective,venture_char
```

- Add `seam`, `stage`, `save_integrity` and the `fingerprint_*` suites that move. Read the `Tests:` line every time.
- Run `--import` only if a new `class_name` file exists, and before believing any fingerprint failure.
- Phase 2 and 4 must show each moved value before and after, with its cause.
- In-game steps for Jeff: **no confirmed debug-console command reaches the shrine or stage-settlement payout.**
  `DebugController.gd` exists, but I have not found an Ase or stage command. Phase 1 finds the real commands or
  states there is none, then gives play steps: start `realm.01`, clear a shrine stage, read the resolve card
  (Ase and Ekwan), compare with the Phase 1 table.

## Open items for Jeff (before the phase that uses them)

1. Remove or keep inactive `ekwan_base_factor` and `ekwan_shrine_multiplier` (Phase 4).
2. Per-encounter Ekwan: keep a share of encounter Ase, or pay none (Phase 4).
3. Config shape for "boss does not pay" (Phase 3).
4. Target numbers (Phase 5).
5. Notion edits: ECONOMY-004 depends on ECONOMY-001 only; ECONOMY-003 gains ECONOMY-004. Not made.
6. When ITEM-001 is due, the orchestrator writes its opening prompt (D-01).

## Correction (2026-10-19)
The suite named `reward` contains a 991-second test (`AGENTS.md`, shard map). It is a long run: RUN REQUEST, main chat only.
Short filtered runs use `realm_reward`, `economy`, `objective`, `venture_char`.

## Plan update (2026-10-19, after D-09 to D-11)
- Phase 3 splits in two commits. **3a:** weights set B, `"boss": 0`, unknown type logs an error and pays 0.
  **3b:** base reward counts only `completed` objectives. Each has its own long run, attribution and re-record.
- `sr-game-designer` checks 3b first (read-only) while 3a is built. Both are disjoint in files.
- Phase 3a moves: stage and encounter payouts, partial payouts, defeat consolation, ranks, pace bonus inputs.
  Phase 3b moves: any stage with an uncompleted optional objective.

## Plan update 2 (2026-10-20, after D-12 to D-16)
Phase 3b is now wider. One completed-only base feeds all readers:

| Reader | Base (decision) |
|---|---|
| Stage payer (`StageSettlementService`) | completed objectives (D-11) |
| Retreat and return-home partials (`FlowRuntime.gd:~1201`, `VentureController.gd:~368,379`) | completed objectives (D-14) |
| Defeat consolation (`EconomyService.gd:~168`) | the fought objective's weight (D-13) |
| Pace base (`EncounterSetupService.gd:739`) | completed objectives plus the fought objective (D-15) |
| Rank (`max_possible`) | the same base on both sides of the ratio (D-12) |
| Ekwan (Phase 4) | completed objectives (D-16) |

Phase 3b starts after Phase 3a is built, run, attributed and re-recorded (same files). Phase 3b moves many
values: partials, consolation, pace, rank, and the fingerprints in pace modes. It needs its own long run and its
own attribution. The planned test list adds: first fight of a stage keeps a pace bonus; first defeat pays a
consolation; a retreat before any win pays 0; rank is not punished by an unreached objective.

## Plan update 3 (2026-10-20, D-18)
Phase 3c (new, after 3b): `cause` and `params` on every payout `breakdown` row, delta-0 rows for zero-by-rule payouts,
cause on the "Scout return" row. Phase 4 adds the Ekwan cause row. Then the UI session builds (payout-explain-ui).

## Status (2026-10-20)
Done and verified (uncommitted): Phase 1, Phase 2, Phase 3a (re-recorded once, 18 constants), Phase 3b (no re-record; harness fix D-21).
Next: Phase 3c (row contract, D-18 to D-20, D-23), then Phase 4 (Ekwan source), Phase 5 (tuning), Phase 6 (verify and close).
