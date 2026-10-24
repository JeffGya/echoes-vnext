# V2-ECONOMY-004 Phase 5.1 — fingerprint attribution (mechanics-developer)

Written in STE. Read-only work. I edited no constant and no code. I ran no Godot command.
Tags: READ = from a file or log. COMPUTED = my arithmetic or hash. COMMENT = from a code comment (not evidence).

## 0. Result

All 10 moved constant pairs (5 modes x FINAL and SAVE, in each of the 2 suites) are PROVED.
The restore test gives the old constant in all 20 cases. The forward test (BEFORE plus formula) gives the new hash in all 20 cases.
No field outside the prediction moved. ROUNDS held in every mode.

### 0.1 Where the prediction is wrong or too wide

1. **(b) rank changed in 1 mode only.** `endure` went A -> S. In the other 4 moved modes the rank was S and stays S.
2. **(c) `pace_state` moved a hash in 1 mode only.** FINAL hashes `objective_state.pace_state`, not the top-level `data.pace_state` (FINAL keeps only the key name of `pace_state`, in `data_keys`). `objective_state.pace_state` changed only in base-suite `purify_shrine` (`full` -> `partial`). In the other 9 moved cases, (c) adds nothing to the hash.
3. **(d) `formula_inputs` content is not hashed.** FINAL keeps only the key name, and the key stays. So the `{}` change adds nothing to any hash. Only the removal of the key `pace_bonus_awarded` moves FINAL, and only in the 4 pace modes (`combat`, `purify_shrine`, `recover`, `pursue`). `endure` never had that key.
4. **(a) the enemy bonus was in the Ase of 4 modes, the pace bonus in 4 modes.** `recover` lost only the pace Ase (0 kills). `endure` lost only the enemy Ase (no-pace mode).
5. **The virtue, stage-index and realm-order removals are invisible to these fixtures.** The fixtures do not dispatch the stage settlement. SAVE `ase` equals FINAL `ase_awarded` in every mode, before and after.
6. **Finding (doc wording):** `decisions.md` D-70 says "full at par or better (fraction 1.0)". The code (`PaceService.bonus_fraction`, `core/combat/PaceService.gd:144-151`) gives fraction 1.0 up to 1.1 x par (`pace_full_ratio`), not up to par. `phase5-1-build.md` §1.4 states the band correctly (1.1 to 1.6). The D-70 text is the imprecise one. No fixture is affected.

## 1. Moved and held constants

`old` = the constant in the file now = the `expected=` in the log (all checked at full length, COMPUTED). `new` = the `actual=` in the log = my hash of the AFTER payload.

| File | Line | Mode | Kind | Old | New | Changed fields (BEFORE -> AFTER) | Cause | Status |
|---|---|---|---|---|---|---|---|---|
| `tests/FlowFingerprintTests.gd` | 671 | combat | FINAL | `0dc88742bd4c9853ee009b651b0a202587cc28318635ddfb9014a72e537b6059` | `908c9e1569b238860c6827ce48d6ecf79e7a430212f6fa5e213a755d2b57426a` | `ase_awarded` 56 -> 50; `data_keys` lost `pace_bonus_awarded` | a, d | PROVED |
| `tests/FlowFingerprintTests.gd` | 672 | combat | SAVE | `6189dfedc768af2c9ed17b7a86c90fb822b2cfbf6c97f61a0467abb6c34c79bf` | `9352e6b49858eb2dc4ab6c73c0b3b7df19f5de2cb4e180f50079be1bb9bf3aca` | `ase` 56 -> 50 | a | PROVED |
| `tests/FlowFingerprintTests.gd` | 753 | purify_shrine | FINAL | `2a9b902cb89875a5bc047112577fc946239f1ac2de4bdf8a32cbfb3344351514` | `4658f206fe8674f195281ebdbcc44e8c0497f9f0b609fc778b90676ea3606959` | `ase_awarded` 56 -> 50; `data_keys` lost `pace_bonus_awarded`; `objective_state.pace_state` full -> partial | a, c, d | PROVED |
| `tests/FlowFingerprintTests.gd` | 754 | purify_shrine | SAVE | `e2e3de48f5e8cc42ae5bd1b634b52d78bf1b598dc47e683822733d353b6e5e34` | `af54a21da43971bce4969473b253e14012b8e8ed582ad1985287f2536cb26439` | `ase` 56 -> 50 | a | PROVED |
| `tests/FlowFingerprintTests.gd` | 776 | recover | FINAL | `d42db3d5368743db17c91df74346f2c46028b40c2fcf3fabbd73bce6fde17a21` | `31ec056cccc677314d33d2cdf24cd340b355cd0684dc02988583dbf6d5a068f4` | `ase_awarded` 51 -> 50; `data_keys` lost `pace_bonus_awarded` | a (pace only), d | PROVED |
| `tests/FlowFingerprintTests.gd` | 777 | recover | SAVE | `8964489e8aab8b0b1b15815fac2fc1aaede15a3ad88fcc25e448f881198b20bc` | `f9796b7777958f03eb587c61802286240ea191e37f5cf34f077e40bacb866cf6` | `ase` 51 -> 50 | a | PROVED |
| `tests/FlowFingerprintTests.gd` | 826 | endure | FINAL | `57509d53c98f6b2fbd1b11c8f39f9eb62c132fe8606829690e68b3834ef89748` | `35fe03ffe9a8c91273ebf263c440b7282c1ba14afac944e22cae829a944ba5c9` | `ase_awarded` 55 -> 50; `rank` A -> S | a (enemy only), b | PROVED |
| `tests/FlowFingerprintTests.gd` | 827 | endure | SAVE | `98aacda1e5d7cdf7eed08a9c859a9f66be227eb2cb5bc87a12559e84bd2b967e` | `af54a21da43971bce4969473b253e14012b8e8ed582ad1985287f2536cb26439` | `ase` 55 -> 50 | a | PROVED |
| `tests/FlowFingerprintTests.gd` | 861 | pursue | FINAL | `c3101065cd2c8228ba4dfa72df7c8910b392ed69a313119f0d9eea47162a100d` | `23d10f38d127333956eec3181ca978d44da19eeee8cc78e2140f0a45399669c7` | `ase_awarded` 56 -> 50; `data_keys` lost `pace_bonus_awarded` | a, d | PROVED |
| `tests/FlowFingerprintTests.gd` | 862 | pursue | SAVE | `6189dfedc768af2c9ed17b7a86c90fb822b2cfbf6c97f61a0467abb6c34c79bf` | `9352e6b49858eb2dc4ab6c73c0b3b7df19f5de2cb4e180f50079be1bb9bf3aca` | `ase` 56 -> 50 | a | PROVED |
| `tests/FlowFingerprintSeekTests.gd` | 27 | combat | FINAL | `0dc88742bd4c9853ee009b651b0a202587cc28318635ddfb9014a72e537b6059` | `908c9e1569b238860c6827ce48d6ecf79e7a430212f6fa5e213a755d2b57426a` | same as base combat FINAL | a, d | PROVED |
| `tests/FlowFingerprintSeekTests.gd` | 28 | combat | SAVE | `6189dfedc768af2c9ed17b7a86c90fb822b2cfbf6c97f61a0467abb6c34c79bf` | `9352e6b49858eb2dc4ab6c73c0b3b7df19f5de2cb4e180f50079be1bb9bf3aca` | `ase` 56 -> 50 | a | PROVED |
| `tests/FlowFingerprintSeekTests.gd` | 40 | purify_shrine | FINAL | `17c5859e6b8d951647c446844e29810475635ea4e89cde36f812fd57d3c86056` | `2150fa9844108ff0e4130d7ce3f8f674217fd390d5ecdaf0b2bb4382d2e8a424` | `ase_awarded` 56 -> 50; `data_keys` lost `pace_bonus_awarded` (pace_state stays `full`) | a, d | PROVED |
| `tests/FlowFingerprintSeekTests.gd` | 41 | purify_shrine | SAVE | `1bb8b869cddcae97c1a5c133118e2010a5883c998f2c172f904f05da3e1ad7b7` | `53cc63d72fda11556577a75d2e71279d1a0a347ed52ad5bb058b3a26718dd9a9` | `ase` 56 -> 50 | a | PROVED |
| `tests/FlowFingerprintSeekTests.gd` | 52 | recover | FINAL | `d42db3d5368743db17c91df74346f2c46028b40c2fcf3fabbd73bce6fde17a21` | `31ec056cccc677314d33d2cdf24cd340b355cd0684dc02988583dbf6d5a068f4` | same as base recover FINAL | a, d | PROVED |
| `tests/FlowFingerprintSeekTests.gd` | 53 | recover | SAVE | `8964489e8aab8b0b1b15815fac2fc1aaede15a3ad88fcc25e448f881198b20bc` | `f9796b7777958f03eb587c61802286240ea191e37f5cf34f077e40bacb866cf6` | `ase` 51 -> 50 | a | PROVED |
| `tests/FlowFingerprintSeekTests.gd` | 77 | endure | FINAL | `57509d53c98f6b2fbd1b11c8f39f9eb62c132fe8606829690e68b3834ef89748` | `35fe03ffe9a8c91273ebf263c440b7282c1ba14afac944e22cae829a944ba5c9` | same as base endure FINAL | a, b | PROVED |
| `tests/FlowFingerprintSeekTests.gd` | 78 | endure | SAVE | `98aacda1e5d7cdf7eed08a9c859a9f66be227eb2cb5bc87a12559e84bd2b967e` | `af54a21da43971bce4969473b253e14012b8e8ed582ad1985287f2536cb26439` | `ase` 55 -> 50 | a | PROVED |
| `tests/FlowFingerprintSeekTests.gd` | 89 | pursue | FINAL | `c3101065cd2c8228ba4dfa72df7c8910b392ed69a313119f0d9eea47162a100d` | `23d10f38d127333956eec3181ca978d44da19eeee8cc78e2140f0a45399669c7` | same as base pursue FINAL | a, d | PROVED |
| `tests/FlowFingerprintSeekTests.gd` | 90 | pursue | SAVE | `6189dfedc768af2c9ed17b7a86c90fb822b2cfbf6c97f61a0467abb6c34c79bf` | `9352e6b49858eb2dc4ab6c73c0b3b7df19f5de2cb4e180f50079be1bb9bf3aca` | `ase` 56 -> 50 | a | PROVED |
| both | 799/800, 64/65 | protect | FINAL, SAVE | held | held | none | — | held (see §4) |
| both | 948/949, 103/104 | guide_spirit | FINAL, SAVE | held | held | none | — | held (see §4) |

Note on equal hashes: the seek-suite FINAL of combat, recover, endure and pursue is byte-equal to the base-suite FINAL (the same constants before and after). Their ROUNDS constants differ. This was already so before Phase 5.1.
The SAVE hash `af54a21d…` is the same for base `purify_shrine` and both `endure` modes after the change. Before, they differed only in `ase` (56 and 55). With `ase` 50 in both, the payloads are equal.

## 2. Field-level diff

Method: I flattened every BEFORE and AFTER payload to path -> value and listed every changed, added and removed path (COMPUTED).
The full diff for every moved case has only these paths:

| Path | Where it changed |
|---|---|
| FINAL `ase_awarded` | all 10 moved FINALs |
| FINAL `data_keys` (one element `pace_bonus_awarded` removed; the rest shift one index) | combat, purify_shrine, recover, pursue (both suites) |
| FINAL `rank` | endure (both suites) |
| FINAL `objective_state.pace_state` | base `purify_shrine` only |
| SAVE `ase` | all 10 moved SAVEs |

No other path changed. This includes `ekwan_awarded` (0), `enemies_defeated`, `echoes_survived`, `round_ended`, `combat_result`, `surface`, `action_keys`, all other `objective_state` fields, SAVE `ekwan` (0) and the party XP, level and rank.
No key other than `pace_bonus_awarded` left `data_keys`. No key was added. `formula_inputs`, `pace_state` and `pace_changed_rank` stay in `data_keys`.
protect and guide_spirit (both suites, FINAL and SAVE): 0 changed paths.

## 3. Derivation from the formulas

Fixture facts (READ from the BEFORE payloads): every fight is a win, 5 Echoes home, run 0 (redo 1.0). SAVE `ase` = FINAL `ase_awarded`, so no stage payout is in the fixture.

### 3.1 Fight Ase

Old win pay (`EconomyService.reward_encounter_complete`, before the edit): `roundi((enemy_bonus + echo_bonus + pace_bonus) x redo)`, enemy 5 per kill, echo 10 per Echo home.
New win pay: `roundi(echo_bonus x redo)` = `roundi(10 x 5 x 1.0)` = 50 in every mode.
The old pace Ase is the remainder: old Ase - 5 x kills - 50.

| Mode | Kills | Old Ase | Old pace remainder | Removed | New Ase |
|---|---|---|---|---|---|
| combat | 1 | 56 | 56 - 5 - 50 = 1 | 5 enemy + 1 pace = 6 | 50 |
| purify_shrine (both) | 1 | 56 | 1 | 6 | 50 |
| pursue | 1 | 56 | 1 | 6 | 50 |
| recover | 0 | 51 | 1 | 1 pace | 50 |
| endure (no-pace mode) | 1 | 55 | 0 | 5 enemy | 50 |
| protect (no-pace mode) | 0 | 50 | 0 | 0 | 50 (held) |
| guide_spirit, `guide_mode` protect (no-pace) | 0 | 50 | 0 | 0 | 50 (held) |

The pace remainder of 1 agrees with the old curve: `roundi(16 x 0.05 x f)` = 1 for f >= 0.625 (stage base 16 from `phase3a-attribution.md` §3.1).

### 3.2 Pace fraction and pace_state

`bonus_fraction`: ratio = round_ended / par; 1.0 when ratio <= 1.1; 0.0 when ratio >= 1.6; else (1.6 - ratio) / 0.5.
New `pace_state`: `full` at fraction 1.0, `none` at 0.0, `partial` between.
Par values are COMMENT values from `tests/FlowFingerprintTests.gd` (lines 663, 745, 769, 848). The payloads do not carry `par_rounds`.

| Mode | Round | Par (COMMENT) | Ratio | Fraction | Old state (Ase rule: paid 1 = max 1) | New state | Observed |
|---|---|---|---|---|---|---|---|
| combat | 7 | 7.3 | 0.959 | 1.0 | full | full | full |
| recover | 2 | 3.27 | 0.612 | 1.0 | full | full | full |
| pursue | 4 | 4.5 | 0.889 | 1.0 | full | full | full |
| purify_shrine (base) | 8 | 6.58 | 1.2158 | 0.7684 | full (`roundi(0.8 x 0.7684)` = `roundi(0.6147)` = 1 = max) | partial | partial |
| purify_shrine (seek) | 7 | not in the file | — | 1.0 (from the observed `full`) | full | full | full |

For seek `purify_shrine`, I could not derive the fraction independently. The old `full` needs only f >= 0.625. The new `full` needs f = 1.0, so the observed AFTER value shows f = 1.0 (ratio <= 1.1, par >= 6.37).

### 3.3 Rank

`RewardCalc.rank_score` = (0.40 + 0.40 x home / started + 0.20 x pace_credit) x redo. pace_credit = fraction in a pace mode, 1.0 in a no-pace mode. S needs >= 0.90 on run 0.
All modes: home 5 of 5 (started = 5, the 5 party ids in SAVE; ASSUMED, see OPEN), redo 1.0.

| Mode | pace_credit | Score | New rank | Old rank | Moved |
|---|---|---|---|---|---|
| combat, recover, pursue, seek purify_shrine | 1.0 | 1.00 | S | S | no |
| base purify_shrine | 0.7684 | 0.9537 | S | S | no |
| endure | 1.0 (no-pace) | 1.00 | S | A | yes |
| protect, guide_spirit | 1.0 (no-pace) | 1.00 | S | S | no |

Old endure rank A came from the old enemy ceiling (U = 10 unearned, `phase3a-attribution.md` §3.2). The new score reads no enemy count, so the party-all-home win is S.
Seek `purify_shrine` is S for any f >= 0.625 (score >= 0.925), so its rank does not depend on the unknown par.

## 4. Why some modes held

| Mode | Reason |
|---|---|
| protect (both suites) | No-pace mode, 0 kills: no enemy Ase and no pace Ase was in the old 50. No `pace_bonus_awarded` key and no `objective_state.pace_state` before. Rank S before and S now (score 1.0). So no hashed field changes. |
| guide_spirit (both suites) | The fixture runs `guide_mode` `protect` (payload `objective_state.guide_mode`). `PaceService.is_pace_mode` is true for GUIDE_SPIRIT only with `escort`. 0 kills. The same reasoning as protect. |

## 5. ROUNDS held

`grep -c "rounds fingerprint drifted"` = 0 in all six Phase 5.1 logs (a to f). `_assert_hashes` (`tests/FlowFingerprintTests.gd:679-700`) adds every mismatch (rounds, final, save) before it returns. So a ROUNDS drift would show in the same line. It does not.
Structural reason: the ROUNDS payload holds turns, positions and `_mode_state_snapshot` (`tests/FlowFingerprintTests.gd:247-266`, 17 keys). None of them carries Ase, rank, pace state or `stage_base`. The removed `combat_state` keys `stage_base` and `pace_bonus_pct` have no reader left in `core/` (grep, COMPUTED); the fight AI never read them (`phase3a-attribution.md` §5).
The 7 determinism suites (log d) and `combat_baseline` and `combat_roundtrip` (log c) passed.

## 6. Method

1. Parsed every `FP_DEBUG <tag> final=` and `save=` line in `/tmp/echoes-econ004-p4r-{a,b,c}.log` (BEFORE) and `/tmp/echoes-econ004-p51-{a,b,c}.log` (AFTER).
2. Hash: `sha256(json.dumps(v, sort_keys=True, separators=(',',':'), ensure_ascii=False))`, run with `python3 -I`. For every payload this equals the sha256 of the printed text. Each BEFORE hash equals the constant now in the file. Each AFTER hash equals the log's `actual=`.
3. Parsed every `drifted: expected=… actual=…` pair at full length. Each `expected=` equals the file constant. Each `actual=` equals my AFTER hash. Modes without a mismatch line have AFTER hash = constant.
4. Restore test: on each AFTER payload I set back only the explained fields to their BEFORE values (`ase_awarded` or `ase`, `rank`, `objective_state.pace_state`, and `pace_bonus_awarded` put back into the sorted `data_keys`). The hash equals the old constant in 20 of 20 moved cases (and stays equal in the 8 held cases).
5. Forward test: on each BEFORE payload I set the new values from the formulas in §3 (Ase 50; rank from the score; `pace_state` from the fraction where par is known; key removed in pace modes). The hash equals the AFTER hash in 20 of 20 moved cases. For seek `purify_shrine` the forward test kept `pace_state` unchanged (par unknown).
6. Scripts: `/private/tmp/claude-501/-Users-jeffreygyamfi-Sites-echoes-vnext--claude-worktrees-echoes-vnext-test-timing-9693e6/48139a16-a765-4a09-8016-bf89438bb2e8/scratchpad/prove.py` (with `ex.py` and `diff.py` in the same folder). Scratch only; not in the repo.

## 7. Re-record list

Replace each old value with the new value. Add the comment line directly above the `const <MODE>_ROUNDS_HASH` line, after the last existing `# Re-recorded:` line of that mode.

| File:line | Constant | Old | New |
|---|---|---|---|
| `tests/FlowFingerprintTests.gd:671` | `COMBAT_FINAL_HASH` | `0dc88742bd4c9853ee009b651b0a202587cc28318635ddfb9014a72e537b6059` | `908c9e1569b238860c6827ce48d6ecf79e7a430212f6fa5e213a755d2b57426a` |
| `tests/FlowFingerprintTests.gd:672` | `COMBAT_SAVE_HASH` | `6189dfedc768af2c9ed17b7a86c90fb822b2cfbf6c97f61a0467abb6c34c79bf` | `9352e6b49858eb2dc4ab6c73c0b3b7df19f5de2cb4e180f50079be1bb9bf3aca` |
| `tests/FlowFingerprintTests.gd:753` | `PURIFY_SHRINE_FINAL_HASH` | `2a9b902cb89875a5bc047112577fc946239f1ac2de4bdf8a32cbfb3344351514` | `4658f206fe8674f195281ebdbcc44e8c0497f9f0b609fc778b90676ea3606959` |
| `tests/FlowFingerprintTests.gd:754` | `PURIFY_SHRINE_SAVE_HASH` | `e2e3de48f5e8cc42ae5bd1b634b52d78bf1b598dc47e683822733d353b6e5e34` | `af54a21da43971bce4969473b253e14012b8e8ed582ad1985287f2536cb26439` |
| `tests/FlowFingerprintTests.gd:776` | `RECOVER_FINAL_HASH` | `d42db3d5368743db17c91df74346f2c46028b40c2fcf3fabbd73bce6fde17a21` | `31ec056cccc677314d33d2cdf24cd340b355cd0684dc02988583dbf6d5a068f4` |
| `tests/FlowFingerprintTests.gd:777` | `RECOVER_SAVE_HASH` | `8964489e8aab8b0b1b15815fac2fc1aaede15a3ad88fcc25e448f881198b20bc` | `f9796b7777958f03eb587c61802286240ea191e37f5cf34f077e40bacb866cf6` |
| `tests/FlowFingerprintTests.gd:826` | `ENDURE_FINAL_HASH` | `57509d53c98f6b2fbd1b11c8f39f9eb62c132fe8606829690e68b3834ef89748` | `35fe03ffe9a8c91273ebf263c440b7282c1ba14afac944e22cae829a944ba5c9` |
| `tests/FlowFingerprintTests.gd:827` | `ENDURE_SAVE_HASH` | `98aacda1e5d7cdf7eed08a9c859a9f66be227eb2cb5bc87a12559e84bd2b967e` | `af54a21da43971bce4969473b253e14012b8e8ed582ad1985287f2536cb26439` |
| `tests/FlowFingerprintTests.gd:861` | `PURSUE_FINAL_HASH` | `c3101065cd2c8228ba4dfa72df7c8910b392ed69a313119f0d9eea47162a100d` | `23d10f38d127333956eec3181ca978d44da19eeee8cc78e2140f0a45399669c7` |
| `tests/FlowFingerprintTests.gd:862` | `PURSUE_SAVE_HASH` | `6189dfedc768af2c9ed17b7a86c90fb822b2cfbf6c97f61a0467abb6c34c79bf` | `9352e6b49858eb2dc4ab6c73c0b3b7df19f5de2cb4e180f50079be1bb9bf3aca` |
| `tests/FlowFingerprintSeekTests.gd:27` | `COMBAT_FINAL_HASH` | `0dc88742bd4c9853ee009b651b0a202587cc28318635ddfb9014a72e537b6059` | `908c9e1569b238860c6827ce48d6ecf79e7a430212f6fa5e213a755d2b57426a` |
| `tests/FlowFingerprintSeekTests.gd:28` | `COMBAT_SAVE_HASH` | `6189dfedc768af2c9ed17b7a86c90fb822b2cfbf6c97f61a0467abb6c34c79bf` | `9352e6b49858eb2dc4ab6c73c0b3b7df19f5de2cb4e180f50079be1bb9bf3aca` |
| `tests/FlowFingerprintSeekTests.gd:40` | `PURIFY_SHRINE_FINAL_HASH` | `17c5859e6b8d951647c446844e29810475635ea4e89cde36f812fd57d3c86056` | `2150fa9844108ff0e4130d7ce3f8f674217fd390d5ecdaf0b2bb4382d2e8a424` |
| `tests/FlowFingerprintSeekTests.gd:41` | `PURIFY_SHRINE_SAVE_HASH` | `1bb8b869cddcae97c1a5c133118e2010a5883c998f2c172f904f05da3e1ad7b7` | `53cc63d72fda11556577a75d2e71279d1a0a347ed52ad5bb058b3a26718dd9a9` |
| `tests/FlowFingerprintSeekTests.gd:52` | `RECOVER_FINAL_HASH` | `d42db3d5368743db17c91df74346f2c46028b40c2fcf3fabbd73bce6fde17a21` | `31ec056cccc677314d33d2cdf24cd340b355cd0684dc02988583dbf6d5a068f4` |
| `tests/FlowFingerprintSeekTests.gd:53` | `RECOVER_SAVE_HASH` | `8964489e8aab8b0b1b15815fac2fc1aaede15a3ad88fcc25e448f881198b20bc` | `f9796b7777958f03eb587c61802286240ea191e37f5cf34f077e40bacb866cf6` |
| `tests/FlowFingerprintSeekTests.gd:77` | `ENDURE_FINAL_HASH` | `57509d53c98f6b2fbd1b11c8f39f9eb62c132fe8606829690e68b3834ef89748` | `35fe03ffe9a8c91273ebf263c440b7282c1ba14afac944e22cae829a944ba5c9` |
| `tests/FlowFingerprintSeekTests.gd:78` | `ENDURE_SAVE_HASH` | `98aacda1e5d7cdf7eed08a9c859a9f66be227eb2cb5bc87a12559e84bd2b967e` | `af54a21da43971bce4969473b253e14012b8e8ed582ad1985287f2536cb26439` |
| `tests/FlowFingerprintSeekTests.gd:89` | `PURSUE_FINAL_HASH` | `c3101065cd2c8228ba4dfa72df7c8910b392ed69a313119f0d9eea47162a100d` | `23d10f38d127333956eec3181ca978d44da19eeee8cc78e2140f0a45399669c7` |
| `tests/FlowFingerprintSeekTests.gd:90` | `PURSUE_SAVE_HASH` | `6189dfedc768af2c9ed17b7a86c90fb822b2cfbf6c97f61a0467abb6c34c79bf` | `9352e6b49858eb2dc4ab6c73c0b3b7df19f5de2cb4e180f50079be1bb9bf3aca` |

Do not touch: every `*_ROUNDS_HASH`, and the protect and guide_spirit constants in both files.

### 7.1 Comment lines (one per mode, both files; the existing style)

- combat (above `FlowFingerprintTests.gd:670` and `FlowFingerprintSeekTests.gd:26`):
  `# Re-recorded: no enemy or pace Ase (D-40, D-49), ase 56 -> 50; key pace_bonus_awarded removed. COMBAT_FINAL_HASH and COMBAT_SAVE_HASH moved; COMBAT_ROUNDS_HASH held.`
- purify_shrine, base file (above `FlowFingerprintTests.gd:752`):
  `# Re-recorded: no enemy or pace Ase (D-40, D-49), ase 56 -> 50; key pace_bonus_awarded removed; pace_state follows the fraction (D-70), full -> partial at 0.77. PURIFY_SHRINE_FINAL_HASH and PURIFY_SHRINE_SAVE_HASH moved; PURIFY_SHRINE_ROUNDS_HASH held.`
- purify_shrine, seek file (above `FlowFingerprintSeekTests.gd:39`):
  `# Re-recorded: no enemy or pace Ase (D-40, D-49), ase 56 -> 50; key pace_bonus_awarded removed. PURIFY_SHRINE_FINAL_HASH and PURIFY_SHRINE_SAVE_HASH moved; PURIFY_SHRINE_ROUNDS_HASH held.`
- recover (above `FlowFingerprintTests.gd:775` and `FlowFingerprintSeekTests.gd:51`):
  `# Re-recorded: no pace Ase (D-49), ase 51 -> 50; key pace_bonus_awarded removed. RECOVER_FINAL_HASH and RECOVER_SAVE_HASH moved; RECOVER_ROUNDS_HASH held.`
- endure (above `FlowFingerprintTests.gd:825` and `FlowFingerprintSeekTests.gd:76`):
  `# Re-recorded: no enemy Ase (D-40), ase 55 -> 50; rank is the win + home + pace score (D-49), A -> S. ENDURE_FINAL_HASH and ENDURE_SAVE_HASH moved; ENDURE_ROUNDS_HASH held.`
- pursue (above `FlowFingerprintTests.gd:860` and `FlowFingerprintSeekTests.gd:88`):
  `# Re-recorded: no enemy or pace Ase (D-40, D-49), ase 56 -> 50; key pace_bonus_awarded removed. PURSUE_FINAL_HASH and PURSUE_SAVE_HASH moved; PURSUE_ROUNDS_HASH held.`

Line numbers are the current lines. They shift down by 1 for each line added above them in the same file; apply from the bottom of each file upward, or re-grep the constant name.

## OPEN — questions and assumptions

ASSUMED: Echoes started = 5 in every fixture | WHY: SAVE lists 5 party ids and `echoes_survived` = 5; the payloads do not carry `total_echoes` | WRONG IF: the fixture counts more Echoes started than the party. The observed S for endure bounds it: 0.4 + 0.4 x 5/N + 0.2 >= 0.90 needs N <= 6.

ASSUMED: The par values in the fingerprint comments (7.3, 3.27, 4.5, 6.58) are still correct | WHY: the observed `pace_state` agrees with each of them, and the rank does not change for any fraction >= 0.625 | WRONG IF: a fixture par moved since those comments. The hash proofs do not depend on par; only §3.2 and the base `purify_shrine` fraction 0.77 in the comment line do.

NOT VERIFIED: the exact fraction of seek `purify_shrine` (par not in any payload or comment; the observed `full` shows f = 1.0). The top-level `data.pace_state`, `pace_changed_rank` value and `formula_inputs` value (FINAL does not hash them, so no fingerprint can show them; a test that reads the Resolve snapshot `data` would be the probe). The stage settlement change (virtue, stage index, realm order): no fingerprint fixture reaches it; `reward`, `econ_char` and `realm_reward` are the suites that do.

FINDING: `decisions.md` D-70 says "full at par or better". The code gives full up to 1.1 x par (`pace_full_ratio`). The D-70 wording should say "at 1.1 times par or better". Not a code defect.

FINDING (out of scope, no action): the history comments at `tests/FlowFingerprintTests.gd:851-853` describe the old D-22 rule ("pace_state from the Ase paid"). They record past re-records, so I left them. The new comment lines in §7.1 make the change of rule explicit.

BLOCKED: none.
