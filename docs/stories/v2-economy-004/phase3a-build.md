# V2-ECONOMY-004 Part A — Phase 3a build

Written in STE. Tags: READ = seen in code or run output. MEASURED = I ran it. PREDICTED = not run.
Scope: weights set B (D-09), boss key at 0 (D-10), unknown type logs an error and counts 0 (D-07).
Not in scope: completed-only base (Phase 3b), Ekwan (Phase 4), any fingerprint or baseline edit.

## 1. Diff summary

| File | Change |
|---|---|
| `data/balance.json` | `data.rewards.objective_weights` = pursue 8, combat 10, recover 12, protect 12, endure 14, shrine 15, guide_spirit 16, boss 0. One comment key added: `_objective_weights_comment`. |
| `core/economy/RewardCalc.gd` | `base_reward(objectives, reward_cfg, logger = null, t = 0)`. A type with no key logs and counts 0. A key with 0 logs nothing. `compute(...)` gets two last optional parameters `logger`, `t` and passes them on. |
| `core/economy/StageSettlementService.gd` | passes `logger, t` to `base_reward`. |
| `core/realms/ActiveStageService.gd` | `get_stage_base_reward(flow_ctx, config_service, logger = null, t = 0)` passes them on. |
| `core/combat/EncounterSetupService.gd` | `_setup_pace` passes `logger, t`. |
| `core/runtime/FlowRuntime.gd` | retreat partial passes `logger, t`. |
| `core/runtime/controllers/VentureController.gd` | return-home partial passes `logger, t`. |
| `core/state/flow/states/venture/FlowEncounterState.gd` | `RewardCalc.compute` call passes `flow_ctx.logger, t`. |
| `tests/EconomyCharacterizationTests.gd` | Weights, boss and tables inverted to set B. Four new tests (section 4). |
| `tests/EconomyRewardTests.gd` | `_default_cfg()` gets the five missing types (D-09 values). Existing 30 / 40 / 60 untouched. |

Callers of `base_reward` (grep): `StageSettlementService.settle`, `RewardCalc.compute`,
`ActiveStageService.get_stage_base_reward`. Callers of `get_stage_base_reward`:
`EncounterSetupService.gd:739`, `FlowRuntime.gd:1202`, `VentureController.gd:379`. All have a logger and `t`.
No wall clock. No `print()`. The weight logic exists once, in `base_reward`.

## 2. Logger decision

- `base_reward` stays `static`. It takes an optional `StructuredLogger` and an injected `t`. Default null: a caller without a logger sees no log and still gets 0.
- `StructuredLogger` has no error severity. `info`, `debug` and `warn` exist. `warn` stores severity `info`.
  `log_event` with severity `"error"` is dropped: `_should_log("error")` is false at every level (READ, `StructuredLogger.gd:33-40`).
  So the error uses `logger.warn(t, "economy.reward.unknown_objective_type", ..., { type, objective_index })`.
- Why not a check at config load: D-07 names a runtime log for an objective type, and a stage can hold a type that config load never sees.
- Cost: one stage with an unknown type logs once per reader call. In one fight that is fight start (pace base), fight end (`compute`) and stage settlement. I accept this. A load-time check would log once and is a Jeff decision.

## 3. Moved values

### MEASURED (I ran an A/B on 6 fingerprint suites: HEAD `balance.json` against the new one, same tree otherwise)

HEAD `balance.json` baseline: 6 passed, 0 failed. New: 1 passed, 5 failed (drift only). I restored `balance.json` after the A/B (`cmp` equal).
Fixture stage is `realm.01` `stage.0`, objectives `[guide_spirit, boss]`. Stage base goes from 60 (0 + boss 60) to 16.

| Suite | FINAL | SAVE | Field change |
|---|---|---|---|
| `fingerprint_combat` | moved | moved | `ase_awarded` 58 to 56 |
| `fingerprint_purify_shrine` | moved | moved | `ase_awarded` 57 to 56, `objective_state.pace_state` partial to full |
| `fingerprint_recover` | moved | moved | `ase_awarded` 53 to 51 |
| `fingerprint_pursue` | moved | moved | `ase_awarded` 58 to 56 |
| `fingerprint_endure` | moved | held | `rank` S to A |
| `fingerprint_protect` | held | held | none |

Single cause for every move: the stage base captured at fight start falls from 60 to 16.
- Pace modes: the pace maximum is `roundi(base x 0.05)`: 3 at base 60, 1 at base 16 (READ, `PaceService.max_bonus_ase`). The pace bonus falls by up to 2. In purify_shrine the 1 Ase is now the maximum, so `pace_state` becomes `full`.
- `endure` is a no-pace mode. The base enters the rank ratio (`RewardCalc.compute`: `kept` and `max_possible`). A lower base lowers the ratio. Rank S becomes A.
- `ROUNDS_HASH` has no Ase or base. It held in the six runs (no ROUNDS drift was printed). I did not read it in detail.
- No `economy.reward.unknown_objective_type` line appeared in any run.

### PREDICTED (not run)

| Value | Prediction | Cause |
|---|---|---|
| `fingerprint_guide_spirit` FINAL (x1 in `FlowFingerprintTests`) | moves | same base 60 to 16. `guide_spirit` carries pace only in `escort` mode, so SAVE moves only if a pace bonus pays. |
| `FlowFingerprintSeekTests`: 7 FINAL, and SAVE where a pace bonus pays | move like the matching modes above | same cause, same harness stage |
| `fingerprint_determinism_*` x7 | hold | They compare two runs of the same code with each other. |
| 14 FINAL total | up to 12 of 14 move (the two `protect` constants likely hold) | as above. The exact set needs the run. |
| `reward` suite | holds | `EconomyRewardTests` reads the inline `_default_cfg()`, not `balance.json`. Tests that build a fight through the fingerprint harness compare live values with each other (Phase 3 proposal, section 6). Risk: a test that asserts a pace bonus of 3 on the real stage base. |
| `combat_baseline`, `combat_roundtrip` | hold | I found no `ase_awarded` or `stage_base` constant in either file. `combat_roundtrip` asserts Ase 0 on a forced retreat. |
| `pending_result`, `seam`, `stage`, `save_integrity`, `foundation_ui`, `unified_resolve`, `retreat` | hold (MEASURED: 122 passed, 0 failed) | |
| Retreat and return-home partial (`roundi(base x 0.12)`) | change at runtime | MEASURED in the new `partial_payout_uses_stage_base` test: combat 1, guide_spirit 2, combat + shrine 3, pursue 1. |

## 4. Tests

`econ_char` now has 18 tests (14 old, 4 new; two old tests renamed).

| Test | Checks |
|---|---|
| `base_reward_per_type` | every weight equals set B; no extra keys |
| `every_type_has_a_weight` (was `unweighted_types_add_zero`) | every `VALID_TYPES` entry has a key and pays its weight; no log line |
| `boss_stub_adds_zero` (was `boss_stub_adds_sixty`) | boss stub adds 0 and logs nothing (D-10) |
| `stage_payer_matrix`, `encounter_payer_victory`, `encounter_payer_defeat` | Ase and Ekwan tables recomputed from the real formulas; stage-0 Set B values equal the proposal table (18/20/22/24/25/26) |
| `objective_pool_frequency` | "zero" column is 0 (every non-boss type has a weight) |
| `combat_and_shrine_single_objective` (new) | base 10 and 15; defeat pays 3 and 4 |
| `multi_objective_stage_sums` (new) | combat + shrine + boss: base 25, stage pays 35 Ase and 4 Ekwan through real `settle()` |
| `partial_payout_uses_stage_base` (new) | `get_stage_base_reward` and the 0.12 factor |
| `unknown_type_logs_and_pays_zero` (new) | log type, `t`, `type`, `objective_index`; removed `shrine` key pays 0 and logs; stage payer logs; no `combat` default |

Labels kept: `KNOWN DEFECT (Phase 4 will change this)` on the shrine Ekwan table;
`KNOWN DEFECT (Phase 3b will change this)` on the stage matrix (base sums uncompleted objectives).
Not covered: a "partial run" through the real retreat dispatch. The test calls `get_stage_base_reward` and the formula. The dispatch needs a booted fight.

MEASURED `Tests:` lines (own save dir `/tmp/echoes-econ004-phase3a`, deleted before each run):
- `=econ_char`: `Tests: 18 total, 18 passed, 0 failed`
- `=econ_char,realm_reward,economy,objective,venture_char`: `Tests: 66 total, 66 passed, 0 failed`
- `=pending_result,seam,stage,save_integrity,foundation_ui,unified_resolve,retreat`: `Tests: 122 total, 122 passed, 0 failed`
- six fingerprint suites: `Tests: 6 total, 1 passed, 5 failed` (drift only, section 3)

`EconomyRewardTests` registers as suite `reward` (READ, `register_test("reward/...")`). I did NOT run it.

## 5. RUN REQUEST (main chat)

Phase 3b is not built. The fingerprint constants are NOT re-recorded. This run reads the real drift.
Group A is needed: it gives the exact moved set and values for the re-record. Group B is the check that `reward` holds; run it only if Jeff wants that proof before the re-record (it is the 1054 s floor of the full run, and CI runs it on the pull request anyway).

Setup: `rm -rf /tmp/echoes-econ004-3a-run`, `export ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-3a-run`, `<checkout>` = the worktree path.

Group A (fingerprints; est. 280 s + 344 s + 8 suites of 8 to 200 s; run in two commands):
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 1500 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =fingerprint_guide_spirit,fingerprint_seek
```
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 1500 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue
```
Tool `timeout` for each: 1800000. Delete the save dir before each command.

Group B (`reward`; est. 1054 s; includes `reward/pace_guide_spirit_runtime_escort_vs_protect` at about 991 s):
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 4216 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =reward
```
Tool `timeout`: 3600000.

Group C (`combat_baseline` 490 s, `combat_roundtrip` 194 s; prediction: hold):
```bash
/usr/bin/perl -e 'alarm shift; exec @ARGV' 1960 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =combat_baseline,combat_roundtrip
```
Tool `timeout`: 2400000.

Files edited by the runs: none. Restore check: `git status --short` must show the same list as before the run.

Output to read back for each command: every `Tests:` line; every `drifted: expected=... actual=...`; every `FP_DEBUG <tag> final=...` and `FP_DEBUG <tag> save=...` line; the names of failed tests. Compare with section 3 (diff each FP_DEBUG payload field by field against the pre-change payload; the old payloads are in the Phase 2 record).

## OPEN — questions and assumptions

ASSUMED: `logger.warn` (stored with severity `info`) is an acceptable "error" through `StructuredLogger` | WHY: the class has no error severity and `log_event` drops severity `error` | WRONG IF: Jeff wants a real `error` severity added to `StructuredLogger` (then `_should_log` and its tests change; that is outside this phase).
ASSUMED: the unknown-type log may repeat once per reader call | WHY: `base_reward` is a pure static helper; a per-stage dedupe needs state | WRONG IF: Jeff wants one log per stage (use a load-time check instead).
ASSUMED: the five new keys in the `reward` suite's inline `_default_cfg()` use the D-09 values | WHY: no existing assertion reads those types | WRONG IF: a future test needs them on the 30 / 40 / 60 scale.
BLOCKED: none.
