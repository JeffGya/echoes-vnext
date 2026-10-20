# V2-ECONOMY-004 Phase 3a: attribution of the moved fingerprints

Written in STE. Status: attribution complete. No constant is edited.

## 0. Disagreements with the prediction

1. **Prediction: none is wrong.** I tried to prove it wrong and could not. Every moved hash is PROVED (section 3).
2. **The build-agent PREDICTED table was wrong on one row.** `phase3a-build.md` section 3 predicted that `fingerprint_guide_spirit` FINAL moves. It held in both suites. Cause: the fixture is the `protect` variant, which has no pace. Its rank stays S at base 16 (section 4).
3. **One field the prediction names did not move in most modes.** `pace_state` moved in one mode only: base-suite `purify_shrine` (`partial` to `full`). In every other pace mode, it was `full` before and stays `full`.
4. **Ekwan did not move in any mode.** The prediction allowed a rounding follow-on. None occurred (section 3.3).
5. **Finding (comment, not code):** `tests/FlowFingerprintTests.gd:661-662` says "par 7.3, round 7, ratio 0.96 -> full, +3 Ase. ase 55 -> 58". After the re-record, the pace bonus is +1 and Ase is 56. The re-record agent must correct this comment.

## 1. Table of moved values

Cause P: the pace maximum `roundi(stage_base x 0.05)` fell from 3 to 1 because the stage base fell from 60 to 16.
Cause R: the rank ratio fell because `base` fell from 60 to 16 in both `kept` and `max_possible`.

"Old" is the constant now in the file. It equals the log `expected=` value in every row (checked by script, full 64-character strings).
"New" is the log `actual=` value. My hash of the new `FP_DEBUG` payload equals it in every row.

| # | File | Mode | Hash | Old | New | Changed fields (old -> new) | Cause | Proof |
|---|---|---|---|---|---|---|---|---|
| 1 | `FlowFingerprintTests.gd` | combat | final | `ed003dfc81afa150d57ab5c8a20f53b2d7a2d326d7ffb6cabf07b10ab577e575` | `c794a27a73e2dd078818733b4982a78155b6c533f2f28012b77c67a0f250d39c` | `ase_awarded` 58 -> 56 | P | PROVED |
| 2 | `FlowFingerprintTests.gd` | combat | save | `0458140c7144696073328049cafc901551ffda572649e45b0bd6f8ab5e82e352` | `f874acb9885d1fac15de6c7599f79cbd0757d265e843f4437518516e5d2a8d03` | `ase` 58 -> 56 | P | PROVED |
| 3 | `FlowFingerprintTests.gd` | purify_shrine | final | `6affa11177d7819589cfb8f878af88328ef313d9707fc75d287cbd44daf2b69c` | `38703984ff11841e07605d5c984f3415ae9ece30b159d14b6717e1e1c6e7e563` | `ase_awarded` 57 -> 56; `objective_state.pace_state` partial -> full | P | PROVED |
| 4 | `FlowFingerprintTests.gd` | purify_shrine | save | `930439633fdb06e3230da43ce270f90c35b86e4f6cb60f46f953bfb19aa282d4` | `c9b2c5fe1656ea4fa9f950196385a86c557a3f93c3186666655048d3a9de6c02` | `ase` 57 -> 56 | P | PROVED |
| 5 | `FlowFingerprintTests.gd` | recover | final | `b7ab501f78f904271faaa7856203c31f561ec795c03812ce5ba0ca62c442921d` | `093ae9a2fdc93af9018ad88400664e04a0f718a05697b563f3397983a6ee8ceb` | `ase_awarded` 53 -> 51 | P | PROVED |
| 6 | `FlowFingerprintTests.gd` | recover | save | `0b9bb5db21150c1e886ab7b3401b83287d6c82c168317d3d15e239dfa88b12b6` | `c797d389c2186b0b2ad7e57f66c9f03e0058104850df48d544bea8770174436d` | `ase` 53 -> 51 | P | PROVED |
| 7 | `FlowFingerprintTests.gd` | endure | final | `bc3131f83a24e7e3dd9706f453050085487e34fe416c45481affe62fa9730219` | `95adef7bd15dcace4cc5bf5873d9c31dbb66b1744aa00ea6fe8bf3602d04a95e` | `rank` S -> A | R | PROVED |
| 8 | `FlowFingerprintTests.gd` | pursue | final | `10e8479053f4142de715cb47acf131cfea67104ecce0d4bc2931498b847a89cc` | `8a3b058cd867a492b3834bb5bf0ed073a4dc3897d6efd1522cd4d423d7953f98` | `ase_awarded` 58 -> 56 | P | PROVED |
| 9 | `FlowFingerprintTests.gd` | pursue | save | `0458140c7144696073328049cafc901551ffda572649e45b0bd6f8ab5e82e352` | `f874acb9885d1fac15de6c7599f79cbd0757d265e843f4437518516e5d2a8d03` | `ase` 58 -> 56 | P | PROVED |
| 10 | `FlowFingerprintSeekTests.gd` | combat | final | `ed003dfc81afa150d57ab5c8a20f53b2d7a2d326d7ffb6cabf07b10ab577e575` | `c794a27a73e2dd078818733b4982a78155b6c533f2f28012b77c67a0f250d39c` | `ase_awarded` 58 -> 56 | P | PROVED |
| 11 | `FlowFingerprintSeekTests.gd` | combat | save | `0458140c7144696073328049cafc901551ffda572649e45b0bd6f8ab5e82e352` | `f874acb9885d1fac15de6c7599f79cbd0757d265e843f4437518516e5d2a8d03` | `ase` 58 -> 56 | P | PROVED |
| 12 | `FlowFingerprintSeekTests.gd` | purify_shrine | final | `7f30053fb8eaf18ed775fdac6f5a3406fc5997d847686ccc4543fee787acb446` | `467c807fd36eb9345e086b9e36537314f83fd20ee31a699c04cfc611e9b092b5` | `ase_awarded` 58 -> 56 | P | PROVED |
| 13 | `FlowFingerprintSeekTests.gd` | purify_shrine | save | `324f6c16a1e785088ae34d7211b08dd91684c9228dfe215ee079ec4256f193fc` | `81c41df33723843a53cc452928934d89288aa75c3dc5c171980126cbc09dd8e6` | `ase` 58 -> 56 | P | PROVED |
| 14 | `FlowFingerprintSeekTests.gd` | recover | final | `b7ab501f78f904271faaa7856203c31f561ec795c03812ce5ba0ca62c442921d` | `093ae9a2fdc93af9018ad88400664e04a0f718a05697b563f3397983a6ee8ceb` | `ase_awarded` 53 -> 51 | P | PROVED |
| 15 | `FlowFingerprintSeekTests.gd` | recover | save | `0b9bb5db21150c1e886ab7b3401b83287d6c82c168317d3d15e239dfa88b12b6` | `c797d389c2186b0b2ad7e57f66c9f03e0058104850df48d544bea8770174436d` | `ase` 53 -> 51 | P | PROVED |
| 16 | `FlowFingerprintSeekTests.gd` | endure | final | `bc3131f83a24e7e3dd9706f453050085487e34fe416c45481affe62fa9730219` | `95adef7bd15dcace4cc5bf5873d9c31dbb66b1744aa00ea6fe8bf3602d04a95e` | `rank` S -> A | R | PROVED |
| 17 | `FlowFingerprintSeekTests.gd` | pursue | final | `10e8479053f4142de715cb47acf131cfea67104ecce0d4bc2931498b847a89cc` | `8a3b058cd867a492b3834bb5bf0ed073a4dc3897d6efd1522cd4d423d7953f98` | `ase_awarded` 58 -> 56 | P | PROVED |
| 18 | `FlowFingerprintSeekTests.gd` | pursue | save | `0458140c7144696073328049cafc901551ffda572649e45b0bd6f8ab5e82e352` | `f874acb9885d1fac15de6c7599f79cbd0757d265e843f4437518516e5d2a8d03` | `ase` 58 -> 56 | P | PROVED |

10 suite-mode values moved (5 per file). They carry 18 hash constants: 4 modes x 2 hashes + endure x 1, per file.
No field other than the ones in the "Changed fields" column moved. This includes `ekwan_awarded`, `round_ended`, `enemies_defeated`, `echoes_survived`, `surface`, `data_keys`, `action_keys`, `combat_result` and the party XP in SAVE.

## 2. Method

1. **Old payloads.** `/tmp/echoes-econ004-p2r-a.log` (base suite) and `/tmp/echoes-econ004-p2r-b.log` (Seek suite). These are passing Phase 2 runs. I identified the suite by hashing: p2r-a matches 7/7 FINAL and 7/7 SAVE constants of `FlowFingerprintTests.gd`. p2r-b matches 7/7 and 7/7 of `FlowFingerprintSeekTests.gd`. So each old payload hashes to the constant now in the file.
2. **New payloads.** `p3a-a.log` (base, 6 modes), `p3a-b.log` (base `guide_spirit`), `p3a-c.log` (Seek, 7 modes).
3. **Hash function.** The harness hashes `JSON.stringify(v, "", true).sha256_text()` (`tests/FlowFingerprintTests.gd:419-420`). The log prints `JSON.stringify(final_fp)` with the same defaults (lines 455-456). I hashed the printed text with `hashlib.sha256` over UTF-8 (`python3 -I`).
4. **Round trip.** For all 154 `FP_DEBUG` payloads in the 7 logs, Python `json.dumps(sort_keys=True, separators=(",",":"), ensure_ascii=False)` of the parsed text equals the printed text byte for byte. So a parse, edit and re-dump makes the same bytes the harness would hash.
5. **Field diff.** A recursive diff of old against new for every mode, FINAL and SAVE.
6. **Restore proof.** For each moved hash: take the NEW payload, set only the changed fields back to their old values, re-dump, hash. The result equals the OLD constant in all 18 rows. This proves that no other field moved.
7. **Mismatch lines.** I parsed every `drifted: expected=... actual=...` pair at full length. Each `expected=` is a constant in the current file. Each `actual=` equals my hash of the new payload.

## 3. Derivation from the formulas

Inputs: `data.rewards` in `data/balance.json`: `enemy_defeated_bonus` 5, `echo_survived_bonus` 10, `pace_bonus_pct` 0.05, `pace_full_ratio` 1.1, `pace_zero_ratio` 1.6, `rank_thresholds` S 0.90 / A 0.75, `ekwan_base_factor` 0.12.
Stage `realm.01` stage 0, objectives `[guide_spirit, boss]`. Old base 0 + 60 = 60. New base 16 + 0 = 16.
Redo is 1.0: every old payload has rank S, and `_compute_rank` returns S only when `run_count == 0` (`RewardCalc.gd:176`). So `run_count` is 0 and `redo_multiplier` is 1.0.

### 3.1 Encounter Ase (cause P)

On a victory, `EconomyService.reward_encounter_complete` pays `roundi((enemy_bonus + echo_bonus + pace_bonus) x redo)` (`core/economy/EconomyService.gd:150-152`). The stage base is not paid here. It enters only through the pace bonus.

Pace maximum: `PaceService.max_bonus_ase = roundi(stage_base x 0.05)`.
- Old: 60 x 0.05 = 3.0000000000000004 (IEEE); `roundi` = 3.
- New: 16 x 0.05 = 0.8; `roundi` = 1.

Pace paid: `roundi(stage_base x 0.05 x f)`, f = the curve fraction. Old `full` means paid >= 3, so f >= 0.8333. Then new paid = `roundi(0.8 f)` with 0.8 f in [0.667, 0.8], so new paid = 1 = new maximum, state `full`.

| Suite | Mode | Kills x 5 | Survivors x 10 | Old pace | New pace | Old Ase | New Ase | Observed |
|---|---|---|---|---|---|---|---|---|
| both | combat (round 7) | 5 | 50 | 3 (full) | 1 (full) | 58 | 56 | 58 -> 56 |
| both | pursue (round 4) | 5 | 50 | 3 (full) | 1 (full) | 58 | 56 | 58 -> 56 |
| both | recover (round 2) | 0 | 50 | 3 (full) | 1 (full) | 53 | 51 | 53 -> 51 |
| Seek | purify_shrine (round 7) | 5 | 50 | 3 (full) | 1 (full) | 58 | 56 | 58 -> 56 |
| base | purify_shrine (round 8) | 5 | 50 | 2 (partial) | 1 (full) | 57 | 56 | 57 -> 56 |

Base-suite `purify_shrine`: old paid 2 at maximum 3. So `roundi(3 f)` = 2, which gives f in [0.5, 0.8333). New paid 1 needs `roundi(0.8 f)` = 1, so f >= 0.625. The observed new value 56 (pace 1, not 0) is consistent only with f in [0.625, 0.8333). Paid 1 equals the new maximum 1, so `pace_state` becomes `full` (`PaceService.pace_state`, "paid >= max" branch). The payload does not carry `par_rounds`, so the exact f is NOT observed. The hash restore proves the field set; the arithmetic shows the values are possible.

### 3.2 Rank (cause R, and why pace modes kept S)

`RewardCalc.compute`: `kept = base + rank_enemy_bonus + echo_bonus`; `max_possible = base + ceiling_enemies x 5 + total_echoes x 10 + max_pace_bonus`. Let U = the unearned part of `max_possible` (not-killed reached enemies x 5, plus lost echoes x 10). U is a multiple of 5.

**endure** (no pace, reached-enemy mode). Earned without base: 5 + 50 = 55.
- Old S: 115 / (115 + U) >= 0.90, so U <= 12.78.
- New A: 71 / (71 + U) < 0.90, so U > 7.89; and >= 0.75, so U <= 23.67.
- The only multiple of 5 in (7.89, 12.78] is U = 10.
- Check: old 115 / 125 = 0.920 -> S. New 71 / 81 = 0.877 -> A. Matches the log.

**combat, purify_shrine** (not reached-enemy modes, win by killing every enemy, all 5 echoes alive): U = 0.
- combat new: (71 + 1) / 72 = 1.000 -> S. purify base new: (71 + 1) / 72 = 1.000 -> S (old 117 / 118 = 0.992).

**recover, pursue** (reached-enemy modes, pace): S held. For recover, new (66 + 1) / (67 + U) >= 0.90 gives U <= 7.4, so U is 0 or 5. Pursue has `all_enemies_defeated`, U = 0.

### 3.3 Ekwan (held in every mode)

Ekwan = `roundi(encounter Ase x 0.12)` (`EconomyService.gd:235`). The first objective is `guide_spirit`, so the shrine multiplier does not apply (`FlowEncounterState.gd:210-216`).

| Old Ase | Old Ekwan | New Ase | New Ekwan |
|---|---|---|---|
| 58 | 6.96 -> 7 | 56 | 6.72 -> 7 |
| 57 | 6.84 -> 7 | 56 | 6.72 -> 7 |
| 53 | 6.36 -> 6 | 51 | 6.12 -> 6 |

## 4. Why some values held

| Value | Why it held |
|---|---|
| `fingerprint_guide_spirit` (both suites), FINAL and SAVE | The fixture runs `guide_mode` `protect` (`FlowFingerprintTests.gd:948`, `FlowFingerprintSeekTests.gd:108`; payload `objective_state.guide_mode` = `protect`). `PaceService.is_pace_mode` returns true for GUIDE_SPIRIT only for `escort`. So no pace bonus: Ase = 0 kills + 50 = 50 at any base. Ekwan `roundi(6.0)` = 6. Rank: old 110 / (110 + U), new 66 / (66 + U). S held at the new base, so U <= 7.33 (U is 0 or 5). Both ratios stay >= 0.90. |
| `fingerprint_seek/protect` and base `protect` | Same as above: `protect` is not in `PACE_MODES`. Kills 0, survivors 5, Ase 50, Ekwan 6, rank S with U <= 5. |
| `endure` SAVE | SAVE holds `ase`, `ekwan` and party XP only (`_save_fingerprint`, lines 395-416). It has no `rank`. Endure has no pace, so Ase = 55 at any base. Only `rank` moved, and `rank` is in FINAL only. |
| `combat` SAVE moved | Combat is a pace mode. The pace bonus fell 3 -> 1, so the saved `ase` fell 58 -> 56. |

## 5. ROUNDS held

`_assert_hashes` (`tests/FlowFingerprintTests.gd:674-695`) appends EVERY mismatch (rounds, final, save) before it returns. `grep -c "rounds fingerprint drifted"` is 0 in all six Phase 3a logs (a, b, c, d, e, f). Each of the 10 failure messages names only `final` and, where listed, `save`. So all 14 ROUNDS hashes held.

Structural support: the ROUNDS payload holds turns, positions and `_mode_state_snapshot` (lines 245-264). None of these fields carry Ase, base or pace state. The only readers of `combat_state["stage_base"]` are `FlowEncounterState.gd:202` (the reward) and `EncounterSnapshotBuilder.gd:291-293` (the snapshot pace state). No AI or movement code reads it.

## 6. Other suites

Log d `Tests: 65 total, 65 passed`, log e `Tests: 39 total, 39 passed`, log f `Tests: 87 total, 87 passed`. No `economy.reward.unknown_objective_type` line appears in any Phase 3a log.

## 7. Constants to re-record (not edited by this agent)

Line numbers are from the current working tree.

| File:line | Constant | Old | New |
|---|---|---|---|
| `tests/FlowFingerprintTests.gd:666` | `COMBAT_FINAL_HASH` | `ed003dfc81afa150d57ab5c8a20f53b2d7a2d326d7ffb6cabf07b10ab577e575` | `c794a27a73e2dd078818733b4982a78155b6c533f2f28012b77c67a0f250d39c` |
| `tests/FlowFingerprintTests.gd:667` | `COMBAT_SAVE_HASH` | `0458140c7144696073328049cafc901551ffda572649e45b0bd6f8ab5e82e352` | `f874acb9885d1fac15de6c7599f79cbd0757d265e843f4437518516e5d2a8d03` |
| `tests/FlowFingerprintTests.gd:748` | `PURIFY_SHRINE_FINAL_HASH` | `6affa11177d7819589cfb8f878af88328ef313d9707fc75d287cbd44daf2b69c` | `38703984ff11841e07605d5c984f3415ae9ece30b159d14b6717e1e1c6e7e563` |
| `tests/FlowFingerprintTests.gd:749` | `PURIFY_SHRINE_SAVE_HASH` | `930439633fdb06e3230da43ce270f90c35b86e4f6cb60f46f953bfb19aa282d4` | `c9b2c5fe1656ea4fa9f950196385a86c557a3f93c3186666655048d3a9de6c02` |
| `tests/FlowFingerprintTests.gd:771` | `RECOVER_FINAL_HASH` | `b7ab501f78f904271faaa7856203c31f561ec795c03812ce5ba0ca62c442921d` | `093ae9a2fdc93af9018ad88400664e04a0f718a05697b563f3397983a6ee8ceb` |
| `tests/FlowFingerprintTests.gd:772` | `RECOVER_SAVE_HASH` | `0b9bb5db21150c1e886ab7b3401b83287d6c82c168317d3d15e239dfa88b12b6` | `c797d389c2186b0b2ad7e57f66c9f03e0058104850df48d544bea8770174436d` |
| `tests/FlowFingerprintTests.gd:821` | `ENDURE_FINAL_HASH` | `bc3131f83a24e7e3dd9706f453050085487e34fe416c45481affe62fa9730219` | `95adef7bd15dcace4cc5bf5873d9c31dbb66b1744aa00ea6fe8bf3602d04a95e` |
| `tests/FlowFingerprintTests.gd:856` | `PURSUE_FINAL_HASH` | `10e8479053f4142de715cb47acf131cfea67104ecce0d4bc2931498b847a89cc` | `8a3b058cd867a492b3834bb5bf0ed073a4dc3897d6efd1522cd4d423d7953f98` |
| `tests/FlowFingerprintTests.gd:857` | `PURSUE_SAVE_HASH` | `0458140c7144696073328049cafc901551ffda572649e45b0bd6f8ab5e82e352` | `f874acb9885d1fac15de6c7599f79cbd0757d265e843f4437518516e5d2a8d03` |
| `tests/FlowFingerprintSeekTests.gd:27` | `COMBAT_FINAL_HASH` | `ed003dfc81afa150d57ab5c8a20f53b2d7a2d326d7ffb6cabf07b10ab577e575` | `c794a27a73e2dd078818733b4982a78155b6c533f2f28012b77c67a0f250d39c` |
| `tests/FlowFingerprintSeekTests.gd:28` | `COMBAT_SAVE_HASH` | `0458140c7144696073328049cafc901551ffda572649e45b0bd6f8ab5e82e352` | `f874acb9885d1fac15de6c7599f79cbd0757d265e843f4437518516e5d2a8d03` |
| `tests/FlowFingerprintSeekTests.gd:40` | `PURIFY_SHRINE_FINAL_HASH` | `7f30053fb8eaf18ed775fdac6f5a3406fc5997d847686ccc4543fee787acb446` | `467c807fd36eb9345e086b9e36537314f83fd20ee31a699c04cfc611e9b092b5` |
| `tests/FlowFingerprintSeekTests.gd:41` | `PURIFY_SHRINE_SAVE_HASH` | `324f6c16a1e785088ae34d7211b08dd91684c9228dfe215ee079ec4256f193fc` | `81c41df33723843a53cc452928934d89288aa75c3dc5c171980126cbc09dd8e6` |
| `tests/FlowFingerprintSeekTests.gd:52` | `RECOVER_FINAL_HASH` | `b7ab501f78f904271faaa7856203c31f561ec795c03812ce5ba0ca62c442921d` | `093ae9a2fdc93af9018ad88400664e04a0f718a05697b563f3397983a6ee8ceb` |
| `tests/FlowFingerprintSeekTests.gd:53` | `RECOVER_SAVE_HASH` | `0b9bb5db21150c1e886ab7b3401b83287d6c82c168317d3d15e239dfa88b12b6` | `c797d389c2186b0b2ad7e57f66c9f03e0058104850df48d544bea8770174436d` |
| `tests/FlowFingerprintSeekTests.gd:77` | `ENDURE_FINAL_HASH` | `bc3131f83a24e7e3dd9706f453050085487e34fe416c45481affe62fa9730219` | `95adef7bd15dcace4cc5bf5873d9c31dbb66b1744aa00ea6fe8bf3602d04a95e` |
| `tests/FlowFingerprintSeekTests.gd:89` | `PURSUE_FINAL_HASH` | `10e8479053f4142de715cb47acf131cfea67104ecce0d4bc2931498b847a89cc` | `8a3b058cd867a492b3834bb5bf0ed073a4dc3897d6efd1522cd4d423d7953f98` |
| `tests/FlowFingerprintSeekTests.gd:90` | `PURSUE_SAVE_HASH` | `0458140c7144696073328049cafc901551ffda572649e45b0bd6f8ab5e82e352` | `f874acb9885d1fac15de6c7599f79cbd0757d265e843f4437518516e5d2a8d03` |

Do not change any `*_ROUNDS_HASH`, any `PROTECT_*`, any `GUIDE_SPIRIT_*`, or either `ENDURE_SAVE_HASH`.

## 8. What the fingerprints cannot show

- FINAL records only the NAMES of `data` keys. So `pace_bonus_awarded`, `pace_changed_rank`, the top-level `pace_state` and `reward_breakdown` are not hashed. Their change (pace bonus 3 -> 1) is visible only through `ase_awarded` and `objective_state.pace_state`.
- The stage-cadence payout (base 16 instead of 60 at `flow.complete_stage`) is not in these fingerprints. SAVE is taken after the encounter, before stage settlement. `econ_char` covers it.
- The exact pace fraction for base-suite `purify_shrine` is not observed: `par_rounds` is not in any payload.
