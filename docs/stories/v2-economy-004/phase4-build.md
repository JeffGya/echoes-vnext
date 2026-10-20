# V2-ECONOMY-004 Part A — Phase 4 build (separate Ekwan source)

Written in STE. Tags: READ = seen in code. MEASURED = I ran it. PREDICTED = not run.
Scope: D-05, D-06, D-10, D-16, D-24, D-27 to D-32. No `ui/` file was edited. No fingerprint constant was edited.

## 1. Design

One shared producer pays and previews the stage. I extended it. I did not fork it.

| Item | Where | Change |
|---|---|---|
| Config table | `data.rewards.objective_ekwan` (`data/balance.json`) | NEW. Set B: pursue 2, combat 2, protect 3, guide_spirit 3, endure 4, recover 5, shrine 6, boss 0. Every `ObjectiveModel.VALID_TYPES` entry has a key. Name kept from the proposal. No conflict found. |
| Selection and lookup | `RewardCalc._sum_selected()` (private) | NEW. `base_reward()` now calls it with `objective_weights`. `stage_ekwan()` calls it with `objective_ekwan`. One body: the two tables cannot differ in what they select or in how a missing key behaves. |
| Stage Ekwan sum | `RewardCalc.stage_ekwan(objectives, cfg, logger, t)` | NEW. Sum over COMPLETED objectives only (mode `MODE_COMPLETED`). Not rounded. |
| Missing key (D-07 rule) | `_sum_selected` | Logs `economy.reward.unknown_objective_type` through `logger.warn`, pays 0. The log data gained the field `table` (`objective_weights` or `objective_ekwan`). |
| Rounding and replay (D-30) | `EconomyService.stage_payout_rows()` | Returns `ekwan = roundi(float(ekwan_base) * redo_multiplier)`. One rounding, on the stage sum. |
| Payment | `EconomyService.settle_stage_complete()` | The `ekwan_factor` parameter is gone. New last parameter `ekwan_base: int = 0`. Adds `rows["ekwan"]` with `add_ekwan`. No Ekwan breakdown row (D-32). |
| Plan | `StageSettlementService._plan()` | Gives `ekwan_base` (from `RewardCalc.stage_ekwan`) in place of `ekwan_factor`. The first-objective read (`objectives[0]`) is deleted. |
| Preview | `StageSettlementService.preview()` | Returns `{rows, ase, ekwan}`. Same `_plan()` and same `stage_payout_rows()` as the payment. |
| Fights (D-28) | `EconomyService.reward_encounter_complete()` | The `ekwan_factor` parameter, the Ekwan payment and the "Sanctum share" row are gone. The result keeps `ekwan_awarded: 0` (shape rule). |
| Fight caller | `FlowEncounterState.build_final_snapshot()` | The factor code and the argument are gone. `add_ekwan(_data, ...)` still writes `ekwan_awarded` (0 on a fight card). |
| Snapshot block | `ResolveSnapshotBuilder.add_stage_payout(data, rows, ase, ekwan)` | Writes the new key `stage_payout_ekwan` beside `stage_payout_ase`. |
| Producer | `FlowEncounterState.gd`, same condition as before (`victory and objectives_remaining == 0`) | Passes the preview Ekwan. |
| Replay | `PendingResultService.build_snapshot` | Copies `stage_payout_ekwan` with the rows (`stored.get(..., 0)`). |

Key names (both are PROPOSALS from the brief, kept): `data.rewards.objective_ekwan`, `stage_payout_ekwan`.

One thing I did NOT remove: `FlowEncounterState.gd` still reads the first objective type for the banner `surface` (`_combat_surface`). That read is D-08 (a separate follow-up), not Ekwan. I moved its three lines next to the line that uses them. The behaviour is the same.

Payment, receipt stamp and exactly-once behaviour are unchanged. The preview still makes no RNG call, no save write, no log and no receipt.

D-30 check: the "replay row shows only when the amount changes" rule applies to the Ase `replay` row only. Ekwan has no row (D-32), so no Ekwan replay row exists.

## 2. Removal audit (AGENTS.md exception: D-27)

Keys removed from `data/balance.json` (`data.rewards`): `ekwan_base_factor` (0.12), `ekwan_shrine_multiplier` (1.5). No alias.
Method: `grep -rnE "ekwan_base_factor|ekwan_shrine_multiplier|ekwan_factor"` over `core/ ui/ tests/ scripts/ data/ docs/ CONVENTIONS.md AGENTS.md ANSWERS.md`, then reading each hit.

| Hit | What I did |
|---|---|
| `data/balance.json:1571-1572` | Removed. Added `objective_ekwan` and a comment key. |
| `core/economy/StageSettlementService.gd` (read both keys, `_plan`) | Migrated: `ekwan_base` from `RewardCalc.stage_ekwan`. |
| `core/economy/EconomyService.gd` (`reward_encounter_complete`, `settle_stage_complete` parameters) | Migrated: parameter removed from the fight payer; stage payer takes `ekwan_base`. |
| `core/state/flow/states/venture/FlowEncounterState.gd` (read both keys, passed factor) | Removed. Fights pay no Ekwan. |
| `tests/EconomyCharacterizationTests.gd` (`_encounter_factor`, the 12% tables, `_SHRINE_FACTOR`) | Rewritten for the new source. |
| `tests/EconomyTests.gd:163-174` (`settle_stage_complete(30, 1.0, 0, 0.12, ...)`) | Migrated: `settle_stage_complete(30, 1.0, 0, logger, 0, {}, 5)`; expects exactly 5. |
| `tests/EconomyRewardTests.gd` lines 215, 266, 274, 482, 1016 (old argument `0.0`) | Migrated: argument removed. |
| `tests/EconomyCharacterizationTests.gd:614,627` | New test `ekwan_old_keys_removed` names the keys on purpose, to prove they are absent. |
| `ui/` | NO hit for the removed keys or `ekwan_factor`. No `ui/` file edited. |
| `scripts/` | No hit. |
| `CONVENTIONS.md:924` (described the 12% model) | Rewritten to the new rule. `CONVENTIONS.md:926` (said rows carry `currency: ekwan`) rewritten to match D-32. |
| `docs/v2-migration-map.md:459` | Added a "Superseded" note. |
| `docs/stories/v2-infra-003/defect-register.md` lines 386, 643, 971 and the `ekwan_shrine_multiplier` text of line 211 | History of defect D83. Left as written. Line 211 (the status row) got one pointer sentence. |
| `docs/stories/v2-economy-004/*` (proposal, plan, decisions, phase 1 to 3 files) | Story records of the old model. Left as written. |

Related hits that are NOT removed keys (read, left):
- `ui/components/RewardEntryItem.gd:26` colours a row when `currency == "ekwan"`. No row has that currency now. The branch is dead but harmless. A UI session decides whether to remove it.
- `ui/screens/venture/ResolveScreen.gd:188-190,396-400` shows the Ekwan row and chip when `ekwan_awarded > 0`. On a fight card the value is 0 now. The stage Ekwan arrives as `stage_payout_ekwan`, which the UI session must read. I did not edit it.
- `docs/resolve-snapshot-block-spec.md` lines 61, 85, 128, 145 describe the `ekwan_awarded` shape. The shape is unchanged. I added one note under the block table (line 128).

## 3. Diff summary (Phase 4 only)

| File | Change |
|---|---|
| `data/balance.json` | `objective_ekwan` added. Two old keys removed. |
| `core/economy/RewardCalc.gd` | `_sum_selected`, `stage_ekwan` added. `base_reward` now delegates. |
| `core/economy/EconomyService.gd` | Fight Ekwan removed. `settle_stage_complete` and `stage_payout_rows` carry `ekwan`. Comments updated. |
| `core/economy/StageSettlementService.gd` | `_plan`, `settle`, `preview`. |
| `core/state/flow/states/venture/FlowEncounterState.gd` | Factor removed. Preview Ekwan passed. |
| `core/state/flow/states/venture/ResolveSnapshotBuilder.gd` | `add_stage_payout` takes `ekwan`. |
| `core/state/flow/PendingResultService.gd` | Replay copies `stage_payout_ekwan`. |
| `tests/EconomyCharacterizationTests.gd` | See section 4. |
| `tests/EconomyTests.gd`, `tests/EconomyRewardTests.gd` | Call sites. |
| `tests/VentureCharacterizationTests.gd` | One behaviour fix (below). No key list changed. |
| `tests/FlowFingerprintTests.gd` | Comment near line 494 only. |
| `docs/resolve-snapshot-block-spec.md`, `docs/v2-migration-map.md`, `docs/stories/v2-infra-003/defect-register.md`, `CONVENTIONS.md` | Notes, section 2. |

`tests/VentureCharacterizationTests.gd`, test `complete_stage_no_encounter_advances_and_pays_nothing`: it failed. It expected Ekwan to rise on a stage whose generated objective is NOT completed. Under the completed-only rule (D-16) that stage pays 0 Ekwan: correct behaviour. I set the stage objective to one completed `recover` (one comment line gives the cause) and the check now expects exactly +5. The Ase assertion passed before because of the virtue bonus. This is not a key list. It is a fixture change. Flag it if you want it done another way.

No key list needed a change: the new key is only on a real stage-ending victory card, which no `venture_char` list builds.

## 4. Tests (`econ_char` is now 37 tests; all MEASURED)

New or rewritten in `tests/EconomyCharacterizationTests.gd`:

| Test | Proves |
|---|---|
| `ekwan_per_type` | Each type, completed alone, pays its amount. Config has a key for every `VALID_TYPES` entry, the boss at 0, and no extra key. |
| `ekwan_sums_completed_only` | combat + recover = 7. An incomplete objective pays 0 and is not looked up. Through the real payer: +2 banked. |
| `ekwan_unknown_type_logs_and_pays_zero` | Missing key logs `economy.reward.unknown_objective_type` (`table: objective_ekwan`, `t` as injected) and pays 0. The Ase table is unaffected. |
| `ekwan_replay_rounds_once_on_the_sum` | recover 5 at run 3 (0.7 = 3.5) pays 4. protect 3 at run 5 and 6 (0.5 = 1.5) pays 2. combat + protect at 0.7 = 3.5 pays 4 (per-objective rounding would give 3). Two-objective realm.02 cells. |
| `fights_pay_no_ekwan` | No fight result carries Ekwan. No row has a currency other than `ase`. |
| `ekwan_old_keys_removed` | Both keys absent from `data.rewards`. No `.gd` file under `core/` names a removed key or `ekwan_factor`. |
| `stage_payer_matrix` (rewritten) | Ekwan per type at run 0 and run 1; no Ekwan row. |
| `encounter_payer_victory`, `encounter_payer_defeat` (rewritten) | Ekwan is 0. Ase values unchanged. |
| `stage_preview_equals_paid` (extended) | Preview Ekwan equals paid Ekwan and the balance. Two objective cases, runs 0, 1 and 3. |
| `stage_payout_keys_on_real_victory_card` (extended) | `stage_payout_ekwan` present on the stage-ending victory card, absent on a mid-stage victory and on a defeat. `flow.complete_stage` pays the previewed Ekwan (8 = combat 2 + shrine 6) and the card's `ekwan_awarded` is 0. |

Float result of the x.5 cells (MEASURED, by the test passing): `5 x 0.7` rounds to 4, `3 x 0.5` rounds to 2. `roundi` rounds half away from zero.

### Filtered runs (MEASURED; `ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase4`, deleted before each run)

Compile check: no `SCRIPT ERROR` line (checked after the last edit).

| Filter | `Tests:` line |
|---|---|
| `=econ_char` | `Tests: 37 total, 37 passed, 0 failed` |
| `=realm_reward,economy,objective,venture_char,pending_result,save_integrity,unified_resolve` | `Tests: 91 total, 91 passed, 0 failed` |
| `=foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity,retreat,flow_transaction,seam,stage` | `Tests: 110 total, 110 passed, 0 failed` |
| `=econ_char,economy,realm_reward` (re-run after the doc edits) | `Tests: 51 total, 51 passed, 0 failed` |

A first run of `venture_char` failed one test (section 3). It passed after the fixture change. I did not run `reward` or the full suite.

## 5. What no test observes

- The `reward` suite call sites (5 edited lines) compile, but no short run executes them. Section 7 asks for it.
- `FlowEncounterState` on a real fight inside the fingerprint harness is observed only by the fingerprint suites (RUN REQUEST).
- The UI. Nothing in `ui/` reads `stage_payout_ekwan` yet.

## 6. PREDICTED moved values (no constant edited)

The harness hashes `ekwan_awarded` (value) and the sorted `data_keys` in FINAL (`FlowFingerprintTests._final_fingerprint`, line 366). The SAVE fingerprint hashes `economy.ekwan` (line 416). ROUNDS has no Ekwan.

| Recorded value | Moves? | One cause |
|---|---|---|
| `*_FINAL_HASH` (7 in `FlowFingerprintTests`, 7 in `FlowFingerprintSeekTests`) | PREDICTED yes, in each mode where the old fight paid at least 1 Ekwan | D-28: a fight pays no Ekwan, so `ekwan_awarded` is 0. |
| `*_SAVE_HASH` (14) | PREDICTED yes, in the same modes | D-28: the fight no longer banks Ekwan, so `economy.ekwan` stays 0. |
| `*_ROUNDS_HASH` | PREDICTED hold | Rounds run before any reward read. |
| `fingerprint_determinism_*` | PREDICTED hold | Self-checks, no constants. |
| `combat_baseline`, `combat_roundtrip` | PREDICTED hold | They pin ticks, save reasons and outcomes. `ekwan_awarded` stays 0 on retreat cards. |

- The new snapshot key `stage_payout_ekwan` does NOT move FINAL in the harness. The harness enters the fight with `objectives_remaining` 1, so the preview is absent (D-26 recorded the same for `stage_payout_ase`). Result: `data_keys` is unchanged by this phase.
- A mode moves only if the old fight Ekwan was above 0. Old fight Ekwan = `roundi(fight Ase x factor)`. A mode with fight Ase below 5 (a defeat with a small consolation) paid 0 Ekwan and would HOLD. I cannot tell which modes are those without a run. If a FINAL or SAVE hash holds, check that mode's `ase_awarded` in the `FP_DEBUG final=` line.
- Proof recipe, as in D-26: for each moved hash, take the `FP_DEBUG` payload, put the old `ekwan_awarded` back (`roundi(ase_awarded x 0.12)`; x 0.18 in the shrine mode if its first objective is a shrine) and hash. The result must equal the old constant. That shows D-28 is the only cause.
- `venture_char` key lists: no change (MEASURED: they pass).

## 7. RUN REQUEST (the main chat runs; I do not)

Group A, fingerprints and baselines. Expect FINAL and SAVE drift only, and ROUNDS held.
1. Command: `rm -rf /tmp/echoes-econ004-p4-fp; ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-p4-fp /usr/bin/perl -e 'alarm shift; exec @ARGV' 1800 /opt/homebrew/bin/godot --headless --quit --path /Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/echoes-vnext-test-timing-9693e6 -- tests =fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue,fingerprint_guide_spirit,fingerprint_seek,combat_baseline,combat_roundtrip > /tmp/echoes-econ004-p4-fp.log 2>&1`, tool `timeout` 1900000.
2. Expected duration: about 1500 s (shard-map comments: `combat_baseline` 490, `fingerprint_seek` 344, `fingerprint_guide_spirit` 279, `combat_roundtrip` 194, plus the small suites).

Group B, `reward` as its own group.
1. Command: `rm -rf /tmp/echoes-econ004-p4-reward; ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-p4-reward /usr/bin/perl -e 'alarm shift; exec @ARGV' 1800 /opt/homebrew/bin/godot --headless --quit --path <same checkout> -- tests =reward > /tmp/echoes-econ004-p4-reward.log 2>&1`, tool `timeout` 1900000.
2. Expected duration: about 1054 s (shard-map comment; `reward/pace_guide_spirit_runtime_escort_vs_protect` alone is 991 s).
3. My view: needed once. Reason: it is the only run that executes the 5 changed call sites (`defeat_payout`, `economy_service_adds_ase`, `pace_breakdown_row`, `pace_escort_reward_protect_none`), and the 991 s test drives a real fight through `FlowEncounterState`, where I removed the factor and added a key. No reward number should change. Expect `Tests: 39 total, 39 passed, 0 failed` (D-27 recorded 39). If you want to save 17 minutes, accept that those four tests run only in CI.

Both groups:
- Files the run edits: none. The suites write only under `ECHOES_TEST_SAVE_DIR`. No `trap` is needed.
- Restore check: `git status --short` and `git diff --stat` show the same list and counts as before the run; `cmp` `data/balance.json` against a copy taken before the run.
- Read back: every `Tests:` line; every `❌` line with `expected=` and `actual=` copied raw; for group A, the `FP_DEBUG ... final=` and `save=` payloads of every drifting hash (for the proof recipe in section 6). Do not run Group A and Group B together: they share nothing, but two Godot runs at once slow both.

## OPEN — questions and assumptions

ASSUMED: The missing-key log stays at `logger.warn`, not a new error level | WHY: `StructuredLogger` has `warn` and no `error`; Phase 3a used `warn` for the Ase table and the brief says to share that design | WRONG IF: Jeff wants a higher severity for D-07. Then both tables change together in `_sum_selected`.
ASSUMED: The log data gained the field `table` for both tables | WHY: without it the two tables' log lines cannot be told apart | WRONG IF: a tool matches the exact data of the Ase log line (the existing test does not).
ASSUMED: The replayed card copies `stage_payout_ekwan` together with the rows (rows present means the key is written, 0 if the stored copy lacks it) | WHY: rows and Ekwan are produced together in this build | WRONG IF: a saved result from before this phase carries rows without the key; it would show Ekwan 0. Saves are disposable, so I did not add a presence check.
ASSUMED: Changing the `venture_char` no-encounter fixture (one completed `recover`) is in scope | WHY: the test asserted Ekwan from an incomplete objective, which D-16 makes 0 | WRONG IF: you want that test left red or fixed another way.
ASSUMED: Editing `CONVENTIONS.md` lines 924 and 926 is in scope | WHY: AGENTS.md exception requires migrating every `docs/` reference to a removed key; `CONVENTIONS.md` named both keys | WRONG IF: you want the canon file left to a doc pass.
FINDING (not fixed): `ui/components/RewardEntryItem.gd:26` and `ResolveScreen.gd:188-190` still treat Ekwan as a breakdown row and as `ekwan_awarded`. The UI session must read `stage_payout_ekwan`.
FINDING (not fixed): stale header text in `ResolveSnapshotBuilder.gd` ("SIXTEEN BLOCKS") and `PendingResultService.gd` ("SEVENTEEN-BLOCK LIBRARY"), reported in Phase 3c and 3d.
BLOCKED: none.
