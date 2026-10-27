# V2-ECONOMY-004 Phase 2: repair of D66 and D83

Status: code changed, no fingerprint constant changed. Re-recording waits for the RUN REQUEST (section 5).

## 1. Diff summary

Two reads changed from the key `"obj_type"` to the key `"type"`. `ObjectiveModel.make()` writes `type`.

| File | Line | Change |
|---|---|---|
| `core/economy/StageSettlementService.gd` | 145 to 147 | `.get("obj_type", "combat")` became `.get("type", "combat")`. The stale comment "CARRIED VERBATIM, INCLUDING ITS BUG" (5 lines) was removed. |
| `core/state/flow/states/venture/FlowEncounterState.gd` | 211 | Same key change. No stale comment existed at this site. |

Not changed: weights, factors, the boss stub, `RewardCalc`, `EconomyService`, `data/`, the first-objective-only rule (Phase 4 ends it under D-06).

Effect on Ekwan: a stage or encounter whose FIRST objective is `shrine` now uses factor 0.12 x 1.5 = 0.18. Both payers agree.

## 2. What `_combat_surface` and `surface` now receive

- `FlowEncounterState.gd:346`: `_combat_surface := _obj_type if not _obj_type.is_empty() else "combat"`.
- `_obj_type` now holds the type of `stage_objectives[0]` (the FIRST objective of the stage), for example `guide_spirit`. It was always `"combat"` before.
- It is not the type of the objective being fought. This is the old behavior of the code. Phase 2 does not change it.
- `_combat_surface` goes to `ResolveSnapshotBuilder.add_banner(...)` (line 425). That call writes `data["surface"]`.

Readers of `data["surface"]` on the combat Resolve snapshot:

| Reader | Effect |
|---|---|
| `core/state/flow/PendingResultService.gd:438` | Replays a stored `surface` into a restored Resolve snapshot. An old save keeps `combat`. A string, so nothing breaks. |
| `tests/FlowFingerprintTests.gd:367` | Puts `surface` in the FINAL fingerprint payload. This is the source of the moved hashes. |
| `ui/screens/venture/ResolveScreen.gd:274` | Reads `surface` only in `_render_situation_result`. A combat Resolve does not use that path (READ-FROM-CODE, from Phase 1). No UI text changes. |

## 3. Test changes (`tests/EconomyCharacterizationTests.gd`)

- Stage payer matrix: the `shrine` rows use the new table `_SHRINE_STAGE_PAID` (Ekwan at factor 0.18). Other types keep `_STAGE_PAID`.
- `econ_char/stage_payer_shrine_ekwan` (renamed from `..._ordinary_ekwan`): expects `roundi(ase x 0.18)`.
- `econ_char/encounter_payer_shrine_ekwan` (renamed): mirror factor expects 0.18. The mirror `_encounter_factor` now reads `type`.
- `encounter_payer_victory` and `encounter_payer_defeat`: shrine cells expect Ekwan 6 (victory), and `_SHRINE_DEFEAT_PAID` (defeat).
- `econ_char/ekwan_sites_read_type` (renamed from `..._read_obj_type`): each site must contain `.get("type", "combat")` once and the string `"obj_type"` zero times.
- `objective_model_writes_type_not_obj_type`: label removed. It still asserts the model key.
- Kept: the other `KNOWN DEFECT` labels (Phase 3 and Phase 4).

Rounding note: stage 3, run_count 0, shrine pays Ase 125 and Ekwan 23 (`roundi(22.5)`). The test passes, so the float result rounds up.

Results seen after the change (each run used `ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase2`, deleted before the run):

| Suite | `Tests:` line |
|---|---|
| `econ_char` | 14 total, 14 passed, 0 failed |
| `realm_reward` | 5 total, 5 passed, 0 failed |
| `economy` | 9 total, 9 passed, 0 failed |
| `objective` | 18 total, 18 passed, 0 failed |
| `venture_char` | 16 total, 16 passed, 0 failed |

The compile check printed no error.

## 4. Prediction of moved recorded values (all PREDICTED, none run)

Cause A: `surface` changes from `combat` to the first-objective type. Cause B: Ekwan changes on a shrine first objective.

| Constant | File | Moves? | Reason |
|---|---|---|---|
| `*_FINAL_HASH`, 7 modes (COMBAT, PURIFY_SHRINE, RECOVER, PROTECT, ENDURE, PURSUE, GUIDE_SPIRIT) | `tests/FlowFingerprintTests.gd` | PREDICTED to move, all 7 | The fingerprint harness uses `realm.01` `stage.0`, seed 12346. Phase 1 reports the first objective as `guide_spirit`. `surface` goes `combat` to `guide_spirit` (cause A). |
| `*_FINAL_HASH`, 7 modes | `tests/FlowFingerprintSeekTests.gd` | PREDICTED to move, all 7 | The Seek suite calls `FlowFingerprintTests._run_mode_fingerprint`. Same cause A. |
| `*_ROUNDS_HASH`, `*_SAVE_HASH` | both files | PREDICTED to hold | `surface` is not in the rounds payload. The save payload holds Ase and Ekwan. Stage 0 is not `shrine`, so Ekwan does not change (no cause B). |
| `SANCTUM_FINGERPRINT_HASH`, `STAGE_EXPLORE_FINGERPRINT_HASH` | `tests/FlowSnapshotFingerprintTests.gd` | PREDICTED to hold | These are Sanctum and Stage explore snapshots. They do not pass through `build_final_snapshot`. |
| `*_EMOTION_HASHES` | `tests/CombatBaselineTests.gd` | PREDICTED to hold | Emotion does not read the Ekwan factor or `surface`. Optional run (group C). |
| Payout asserts in `pending_result`, `seam`, `economy`, `realm_reward`, `venture_char` | various | PREDICTED to hold | Those fixtures use no `shrine` first objective, or already passed in the short runs above (`economy`, `realm_reward`, `venture_char`). `pending_result`, `seam` and `snapshot_fingerprint` are not yet run. |

If the FINAL hash of a mode does NOT move, the prediction is wrong for that mode. The attribution agent must find out why.

To prove cause A alone: the `FP_DEBUG` line `final=` for each mode must show `"surface":"guide_spirit"`. The BEFORE payload equals that payload with `"surface":"combat"`. The attribution agent recomputes the hash with that one change and compares it with the constant now in the file.

## 5. RUN REQUEST (for the main chat)

Order of work: run, read, send the output to the attribution agent. Do not edit any constant before attribution.

### 5.1 Commands

`<checkout>` is `/Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/echoes-vnext-test-timing-9693e6`. Use a distinct save directory for each group. Delete it before the run. The groups may run in parallel on a machine with 4 cores. They must not share a save directory.

Group A: the seven fingerprint suites that hold the FINAL hashes.

```bash
rm -rf /tmp/echoes-econ004-p2-a && ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-p2-a /usr/bin/perl -e 'alarm shift; exec @ARGV' 1300 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue,fingerprint_guide_spirit 2>&1 | tee /tmp/echoes-econ004-p2-a.log
```

Group B: the Seek copies (seven modes, one suite).

```bash
rm -rf /tmp/echoes-econ004-p2-b && ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-p2-b /usr/bin/perl -e 'alarm shift; exec @ARGV' 1376 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =fingerprint_seek 2>&1 | tee /tmp/echoes-econ004-p2-b.log
```

Group C: the other suites that can show a moved value.

```bash
rm -rf /tmp/echoes-econ004-p2-c && ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-p2-c /usr/bin/perl -e 'alarm shift; exec @ARGV' 700 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =snapshot_fingerprint,pending_result,seam,save_integrity,stage,combat_roundtrip,fingerprint_determinism_combat 2>&1 | tee /tmp/echoes-econ004-p2-c.log
```

Group D (optional, 490 s alone): `combat_baseline`. PREDICTED to hold. Run it only if the main chat wants proof.

```bash
rm -rf /tmp/echoes-econ004-p2-d && ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-p2-d /usr/bin/perl -e 'alarm shift; exec @ARGV' 1960 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =combat_baseline 2>&1 | tee /tmp/echoes-econ004-p2-d.log
```

Use a tool `timeout` above the alarm: 1400000 for A, 1500000 for B, 800000 for C, 2100000 for D.

The `fingerprint_determinism_*` suites compare two runs of the same process. They hold no recorded constant. Only `fingerprint_determinism_combat` is in group C, as a sample.

### 5.2 Expected duration (from the comments in `scripts/test-shard-map.sh`; they are estimates)

| Group | Estimate |
|---|---|
| A | about 280 s for `fingerprint_guide_spirit`, plus the other six (inside shards of about 100 s each). Estimate 450 to 600 s. |
| B | 344 s |
| C | `combat_roundtrip` 194 s, `fingerprint_determinism_combat` and the rest about 100 s. Estimate 350 s. |
| D | 490 s |

### 5.3 Files the run edits

None. No command here edits a source file. The run writes logs to `/tmp/echoes-econ004-p2-*.log` and saves to `/tmp/echoes-econ004-p2-*`. No `trap` is needed.

### 5.4 How to verify the restore

```bash
git -C <checkout> status --short
git -C <checkout> diff --stat
```

The output must list only these paths as changed by this phase: `core/economy/StageSettlementService.gd`, `core/state/flow/states/venture/FlowEncounterState.gd`, `tests/EconomyCharacterizationTests.gd`, `docs/stories/v2-economy-004/phase2-repair.md`. Earlier changes from Phase 1 (`AGENTS.md`, `scripts/test-shard-map.sh`, `ui/AppRoot.gd`, the new `econ_char` test files) stay as they were.

### 5.5 Output lines to read back

From each log, copy:

1. Each `Tests:` line.
2. Each line with `fingerprint drifted: expected=... actual=...`. `expected` is the BEFORE value (the constant in the file now). `actual` is the AFTER value.
3. Each `FP_DEBUG <tag> final=...` line (the AFTER payload with `surface`), and the `save=` lines.
4. Each failed test name and its error text.

BEFORE values are in the files at `HEAD`. Read them with:

```bash
git -C <checkout> show HEAD:tests/FlowFingerprintTests.gd | grep -n "_HASH *:="
git -C <checkout> show HEAD:tests/FlowFingerprintSeekTests.gd | grep -n "_HASH *:="
git -C <checkout> show HEAD:tests/FlowSnapshotFingerprintTests.gd | grep -n "_HASH *:="
```

Only one run per group is needed. The mismatch message already carries the BEFORE value, so no second run is needed.

## 6. Findings outside this phase (not fixed)

- `FlowEncounterState.gd` names the surface from the FIRST objective (`stage_objectives[0]`), not from the objective being fought. This keeps the old behavior. If the banner should show the fought objective, that is a design decision for Jeff.
