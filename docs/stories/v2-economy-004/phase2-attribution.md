# V2-ECONOMY-004 Phase 2: attribution of the moved fingerprints

Status: attribution complete. No constant is edited. The prediction holds for all 14 values.

## 1. Result

The prediction was: "each of the 14 FINAL hashes moved ONLY because `surface` changed from `combat` to the type of the stage's first objective. Nothing else moved."

I tried to prove it wrong. I could not. All 14 values are PROVED by arithmetic (section 3).

- Each FINAL hash moved for one cause: `surface` changed from `"combat"` to `"guide_spirit"`.
- No ROUNDS hash moved. No SAVE hash moved.
- No Ase value moved. No Ekwan value moved.

## 2. Table of moved values

Cause A: `surface` changed `"combat"` to `"guide_spirit"` (first objective of `realm.01` `stage.0`).

| # | File | Mode | Old (HEAD constant) | New (log `actual=`) | Cause | Proof |
|---|---|---|---|---|---|---|
| 1 | `tests/FlowFingerprintTests.gd` | COMBAT | `e0043b496aa493283d87769c19660e63bcb8d39422aae1000833a0402dd8c746` | `ed003dfc81afa150d57ab5c8a20f53b2d7a2d326d7ffb6cabf07b10ab577e575` | A | PROVED |
| 2 | `tests/FlowFingerprintTests.gd` | PURIFY_SHRINE | `24c3b92582022ad8558bb323c5e9f7513126b8f1bb04308648d003a1eebcf7e8` | `6affa11177d7819589cfb8f878af88328ef313d9707fc75d287cbd44daf2b69c` | A | PROVED |
| 3 | `tests/FlowFingerprintTests.gd` | RECOVER | `33e43352f7aa027a6d034a3d24c07308825adb4b62ae3227310c03856d1626e7` | `b7ab501f78f904271faaa7856203c31f561ec795c03812ce5ba0ca62c442921d` | A | PROVED |
| 4 | `tests/FlowFingerprintTests.gd` | PROTECT | `298e2a9335ad20092d836eef06602c82bd297fe6013642836080af8bbc4648a7` | `d6441d4a031bbd021f67de2954623e2e63c435455cabb386dc42a38b6f73b7e9` | A | PROVED |
| 5 | `tests/FlowFingerprintTests.gd` | ENDURE | `b71e750707ca784e8a002b6b122a80ca37a952234f7355372d31b3e698ac6b39` | `bc3131f83a24e7e3dd9706f453050085487e34fe416c45481affe62fa9730219` | A | PROVED |
| 6 | `tests/FlowFingerprintTests.gd` | PURSUE | `9f9cd0632e4f01fbc25e25488d2ba969c222c49fe0bb15603affcf3d88ad1681` | `10e8479053f4142de715cb47acf131cfea67104ecce0d4bc2931498b847a89cc` | A | PROVED |
| 7 | `tests/FlowFingerprintTests.gd` | GUIDE_SPIRIT | `af7bd3c7577970a1e7d9540a9c3f5a023de1c1ac8c7f9a6c7749c2e65aa03f78` | `e0440f36a0d91017e3436acd8d4214bc88f3ffa84401a199bb96786e4f023658` | A | PROVED |
| 8 | `tests/FlowFingerprintSeekTests.gd` | COMBAT | `e0043b496aa493283d87769c19660e63bcb8d39422aae1000833a0402dd8c746` | `ed003dfc81afa150d57ab5c8a20f53b2d7a2d326d7ffb6cabf07b10ab577e575` | A | PROVED |
| 9 | `tests/FlowFingerprintSeekTests.gd` | PURIFY_SHRINE | `5502ad6dbe2075fc59f8e9bbcd2fa01ba5a9bd9adba72cea93f5dd05edb65d10` | `7f30053fb8eaf18ed775fdac6f5a3406fc5997d847686ccc4543fee787acb446` | A | PROVED |
| 10 | `tests/FlowFingerprintSeekTests.gd` | RECOVER | `33e43352f7aa027a6d034a3d24c07308825adb4b62ae3227310c03856d1626e7` | `b7ab501f78f904271faaa7856203c31f561ec795c03812ce5ba0ca62c442921d` | A | PROVED |
| 11 | `tests/FlowFingerprintSeekTests.gd` | PROTECT | `298e2a9335ad20092d836eef06602c82bd297fe6013642836080af8bbc4648a7` | `d6441d4a031bbd021f67de2954623e2e63c435455cabb386dc42a38b6f73b7e9` | A | PROVED |
| 12 | `tests/FlowFingerprintSeekTests.gd` | ENDURE | `b71e750707ca784e8a002b6b122a80ca37a952234f7355372d31b3e698ac6b39` | `bc3131f83a24e7e3dd9706f453050085487e34fe416c45481affe62fa9730219` | A | PROVED |
| 13 | `tests/FlowFingerprintSeekTests.gd` | PURSUE | `9f9cd0632e4f01fbc25e25488d2ba969c222c49fe0bb15603affcf3d88ad1681` | `10e8479053f4142de715cb47acf131cfea67104ecce0d4bc2931498b847a89cc` | A | PROVED |
| 14 | `tests/FlowFingerprintSeekTests.gd` | GUIDE_SPIRIT | `853b6a425e43de956056f3e199e7a988fc0c1d44901bc17584a0b4994aad7ee5` | `cebaa35d85f3e2ab2201235f3ccedb2e42a6689aa48c8874330a239cc0a069af` | A | PROVED |

For each row, the log value `expected=` equals the constant at `git show HEAD:<file>`. The test files have no change against `HEAD`.

## 3. Evidence method

1. `_hash(v)` is `JSON.stringify(v, "", true).sha256_text()` (`tests/FlowFingerprintTests.gd:419-420`).
2. The log line `FP_DEBUG <tag> final=` prints `JSON.stringify(final_fp)` (line 455). The Godot defaults are `indent=""` and `sort_keys=true`. So the printed text is the same byte string that `_hash` hashes.
3. For each mode, a script (Python, `hashlib.sha256` over UTF-8) did these steps:
   - It took the `final=` text from the log.
   - It hashed the text as printed. The result equals the log `actual=` value (the NEW value).
   - It replaced the one occurrence of `"surface":"guide_spirit"` with `"surface":"combat"`. It hashed the result. The result equals the HEAD constant (the OLD value).
4. The script did this for all 7 modes in log A and all 7 modes in log B. All 28 checks matched. The `surface` key occurs once in each payload.

The step 3 replacement reproduces the old hash byte for byte. This proves that the old payload and the new payload differ only in `surface`. So `ase_awarded`, `ekwan_awarded`, `round_ended`, `rank`, `objective_state` and `combat_result` did not move.

## 4. Check that nothing else moved

| Value | Method | Result |
|---|---|---|
| ROUNDS hash, 14 values | `_assert_hashes` (lines 670-695) puts EVERY mismatch (rounds, final, save) in one message. It does not stop at the first one. Each of the 14 failure messages holds only `final fingerprint drifted`. | All 14 held. The rounds payload is not printed, so this is the only evidence. It is direct. |
| SAVE hash, 14 values | The script hashed each `FP_DEBUG <tag> save=` text. Each result equals the `*_SAVE_HASH` constant at HEAD. | All 14 held. |
| Ase, Ekwan | The values are in the FINAL and SAVE payloads. Both payloads reproduce the old hash (section 3 and the SAVE row). | No change. |
| Other suites | Log C: `Tests: 134 total, 134 passed, 0 failed`. Log D (`combat_baseline`): `Tests: 18 total, 18 passed, 0 failed`. | Held. |

Ekwan per mode (from the new payloads; the same as before by the proof):

| Mode | Base suite Ase / Ekwan | Seek suite Ase / Ekwan |
|---|---|---|
| COMBAT | 58 / 7 | 58 / 7 |
| PURIFY_SHRINE | 57 / 7 | 58 / 7 |
| RECOVER | 53 / 6 | 53 / 6 |
| PROTECT | 50 / 6 | 50 / 6 |
| ENDURE | 55 / 7 | 55 / 7 |
| PURSUE | 58 / 7 | 58 / 7 |
| GUIDE_SPIRIT | 50 / 6 | 50 / 6 |

No mode has a `shrine` first objective. The PURIFY_SHRINE mode forces the fight mode only (`dev_combat_objective`). The Ekwan factor reads `stage_objectives[0]`, which is `guide_spirit`. So the shrine multiplier does not apply. This agrees with the prediction (no cause B).

## 5. Shared values between the two suites

5 modes (COMBAT, RECOVER, PROTECT, ENDURE, PURSUE) have the same FINAL value in both files, old and new. This is expected:

- The Seek suite calls `FlowFingerprintTests._run_mode_fingerprint` with directive `directive.seek_signs` (`tests/FlowFingerprintSeekTests.gd:10`, lines 31-108).
- The directive changes movement, so the ROUNDS constants differ between the files.
- The FINAL payload has no position data. In these 5 modes the outcome fields are the same, so the FINAL payload is the same.

PURIFY_SHRINE and GUIDE_SPIRIT have different FINAL values between the files. That difference is at HEAD too. The outcomes differ: PURIFY_SHRINE ends at round 8 with Ase 57 (base) against round 7 with Ase 58 (Seek). GUIDE_SPIRIT ends at round 25 (base) against round 26 (Seek).

## 6. First-objective type per mode

All 14 new payloads have `"surface":"guide_spirit"`. The fight mode is in `objective_state.type` (`combat`, `purify_shrine`, `recover`, `protect`, `endure`, `pursue`, `guide_spirit`). It differs per mode. The surface does not.

This matches Phase 1 (`phase1-characterization.md:97`, stage 0 is `guide_spirit` at seed 12346). Phase 1 read this from `_setup_stage_env`. The fingerprint harness `_setup_encounter` uses the same realm and stage (`tests/FlowFingerprintTests.gd:144-148`). The logs now confirm it for this harness.

## 7. Disagreements with the prediction or the brief

1. None with the prediction.
2. The brief said "the failing tests stop at the first mismatch". The code does not do this. `_assert_hashes` lists every mismatch (`tests/FlowFingerprintTests.gd:671-694`). This makes the ROUNDS and SAVE evidence stronger, not weaker.

## 8. Constants to re-record (not edited by this agent)

| File:line | Constant | Old | New |
|---|---|---|---|
| `tests/FlowFingerprintTests.gd:666` | `COMBAT_FINAL_HASH` | `e0043b496aa493283d87769c19660e63bcb8d39422aae1000833a0402dd8c746` | `ed003dfc81afa150d57ab5c8a20f53b2d7a2d326d7ffb6cabf07b10ab577e575` |
| `tests/FlowFingerprintTests.gd:748` | `PURIFY_SHRINE_FINAL_HASH` | `24c3b92582022ad8558bb323c5e9f7513126b8f1bb04308648d003a1eebcf7e8` | `6affa11177d7819589cfb8f878af88328ef313d9707fc75d287cbd44daf2b69c` |
| `tests/FlowFingerprintTests.gd:771` | `RECOVER_FINAL_HASH` | `33e43352f7aa027a6d034a3d24c07308825adb4b62ae3227310c03856d1626e7` | `b7ab501f78f904271faaa7856203c31f561ec795c03812ce5ba0ca62c442921d` |
| `tests/FlowFingerprintTests.gd:794` | `PROTECT_FINAL_HASH` | `298e2a9335ad20092d836eef06602c82bd297fe6013642836080af8bbc4648a7` | `d6441d4a031bbd021f67de2954623e2e63c435455cabb386dc42a38b6f73b7e9` |
| `tests/FlowFingerprintTests.gd:821` | `ENDURE_FINAL_HASH` | `b71e750707ca784e8a002b6b122a80ca37a952234f7355372d31b3e698ac6b39` | `bc3131f83a24e7e3dd9706f453050085487e34fe416c45481affe62fa9730219` |
| `tests/FlowFingerprintTests.gd:856` | `PURSUE_FINAL_HASH` | `9f9cd0632e4f01fbc25e25488d2ba969c222c49fe0bb15603affcf3d88ad1681` | `10e8479053f4142de715cb47acf131cfea67104ecce0d4bc2931498b847a89cc` |
| `tests/FlowFingerprintTests.gd:943` | `GUIDE_SPIRIT_FINAL_HASH` | `af7bd3c7577970a1e7d9540a9c3f5a023de1c1ac8c7f9a6c7749c2e65aa03f78` | `e0440f36a0d91017e3436acd8d4214bc88f3ffa84401a199bb96786e4f023658` |
| `tests/FlowFingerprintSeekTests.gd:27` | `COMBAT_FINAL_HASH` | `e0043b496aa493283d87769c19660e63bcb8d39422aae1000833a0402dd8c746` | `ed003dfc81afa150d57ab5c8a20f53b2d7a2d326d7ffb6cabf07b10ab577e575` |
| `tests/FlowFingerprintSeekTests.gd:40` | `PURIFY_SHRINE_FINAL_HASH` | `5502ad6dbe2075fc59f8e9bbcd2fa01ba5a9bd9adba72cea93f5dd05edb65d10` | `7f30053fb8eaf18ed775fdac6f5a3406fc5997d847686ccc4543fee787acb446` |
| `tests/FlowFingerprintSeekTests.gd:52` | `RECOVER_FINAL_HASH` | `33e43352f7aa027a6d034a3d24c07308825adb4b62ae3227310c03856d1626e7` | `b7ab501f78f904271faaa7856203c31f561ec795c03812ce5ba0ca62c442921d` |
| `tests/FlowFingerprintSeekTests.gd:64` | `PROTECT_FINAL_HASH` | `298e2a9335ad20092d836eef06602c82bd297fe6013642836080af8bbc4648a7` | `d6441d4a031bbd021f67de2954623e2e63c435455cabb386dc42a38b6f73b7e9` |
| `tests/FlowFingerprintSeekTests.gd:77` | `ENDURE_FINAL_HASH` | `b71e750707ca784e8a002b6b122a80ca37a952234f7355372d31b3e698ac6b39` | `bc3131f83a24e7e3dd9706f453050085487e34fe416c45481affe62fa9730219` |
| `tests/FlowFingerprintSeekTests.gd:89` | `PURSUE_FINAL_HASH` | `9f9cd0632e4f01fbc25e25488d2ba969c222c49fe0bb15603affcf3d88ad1681` | `10e8479053f4142de715cb47acf131cfea67104ecce0d4bc2931498b847a89cc` |
| `tests/FlowFingerprintSeekTests.gd:103` | `GUIDE_SPIRIT_FINAL_HASH` | `853b6a425e43de956056f3e199e7a988fc0c1d44901bc17584a0b4994aad7ee5` | `cebaa35d85f3e2ab2201235f3ccedb2e42a6689aa48c8874330a239cc0a069af` |

Line numbers are from `HEAD`. Both test files have no change against `HEAD`.

Do not change any `*_ROUNDS_HASH` or `*_SAVE_HASH` constant.

## 9. What a test cannot show

The fix in Phase 2 changes Ekwan on a stage whose FIRST objective is `shrine`. No fingerprint fixture has a `shrine` first objective. So the fingerprint suites cannot see the Ekwan change. Only `econ_char` (`_SHRINE_STAGE_PAID`, `encounter_payer_shrine_ekwan`) covers it.
