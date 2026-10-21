# V2-ECONOMY-004 Part A — Phase 5.2 build (Echoes stipend moves to the stage payout)

Written in STE. Tags: READ = seen in code. RAN = I ran it. PREDICTED = not run.
Decisions: D-43, D-44, D-45, D-46, D-53, D-66, D-81. Nothing committed, nothing pushed.

## 1. Design

| Item | Where |
|---|---|
| Fight payout loses the Echoes bonus. A won fight pays 0 Ase and has no rows. The defeat consolation (D-13) is unchanged. | `EconomyService.reward_encounter_complete` (params `echo_bonus` and `echoes_survived` removed) |
| `echo_bonus` leaves the `RewardCalc.compute` result. `echoes_survived` and `total_echoes` stay: the rank reads them. | `RewardCalc.compute` |
| New helper that counts "home", "started" and "lost" names. | `RewardCalc.echo_tally(actors)` |
| New stipend input for the stage payout. | `StageSettlementService._echo_home()`, called by `_plan()` |
| One producer for payment and preview. The stipend is one more row and is added to `ase`. | `EconomyService.stage_payout_rows(..., echo_home)` |
| Payer and preview pass the same input. | `settle_stage_complete(..., echo_home)`; `StageSettlementService.settle()` and `preview()` |
| Config (additive, under `data.rewards`) | `echo_home_ase` 2, `echo_home_cap` 10, `echo_home_cap_replay` 5 |

Rules built:
- Stipend = `mini(alive * echo_home_ase, cap)`. It is NOT multiplied by the redo factor (D-53). Realm scale is a later step (D-63).
- Cap = `echo_home_cap_replay` when the realm `run_count` > 0, else `echo_home_cap`. The replay factor 0.35 is step 5.3 and is not built here.
- "Home" = a party Echo with `is_dead == false` (READ, `phase5-0-confirmations.md` section 1). Allies (`is_ally`) and the spirit (`is_spirit`) are not counted. "Started" = all party Echoes of the fight.
- With a fight context, the tally reads the LAST fight's `ectx.actors`. The payer reads it at `VentureController.gd:680`, before `encounter_ctx` is set to null. The preview reads the same list inside `build_final_snapshot`.
- With no fight context (the no-encounter path), `alive` = `started` = the number of roster Echoes whose id is in `sanctum.active_party_ids` (the same filter that `EncounterSetupService` uses to build the party).
- The row is added whenever `started` > 0, also at 0 Ase, so the card can name the lost Echoes. An empty party gives no row.
- A retreat and a return home never reach the stage payer, so they pay no stipend (D-46). I changed nothing there.
- Mid-stage fight cards carry no stipend row and no Ase for it. They keep `echoes_survived` for the count chip.
- No death record is added (D-66). Today a dead Echo is rebuilt alive for the next fight (READ, `phase5-0-confirmations.md` section 1), so "lost" lists only the last fight's dead.

## 2. The row

Stage row, `cause` = `echoes_alive`, `currency` = `ase`, `label` = "Echoes home" (placeholder, D-84).

| Param | Type | Meaning |
|---|---|---|
| `alive` | int | party Echoes not dead at the stage end |
| `started` | int | party Echoes of the fight |
| `lost` | Array of String | display NAMES of the dead party Echoes; no ids |
| `cap` | int | 10, or 5 on a replay |
| `replay` | bool | `run_count` > 0 |

`delta` = `mini(alive * 2, cap)`. The old fight row `echoes_alive` (params `count`) is gone.
The row is inside `stage_payout_rows`. No new key appears in the snapshot `data`.

## 3. Removal audit: `echo_survived_bonus`, `echo_bonus`, fight row `echoes_alive`

Searched: `core/`, `ui/`, `tests/`, `scripts/`, `data/`, `docs/`, `tools/`, `CONVENTIONS.md`, `AGENTS.md`, `.github/`. No alias kept.

| Hit | Action |
|---|---|
| `data/balance.json:1558` `echo_survived_bonus` | Removed. Three new keys and one `_echo_home_comment` added. |
| `core/economy/RewardCalc.gd` `echo_bonus` local and result key | Removed |
| `core/economy/EconomyService.gd` params, fight row, comments | Removed or rewritten |
| `core/state/flow/states/venture/FlowEncounterState.gd:203` caller (and a comment) | Updated |
| `core/economy/StageSettlementService.gd:50` header comment about the echoes bonus | Replaced with one line |
| `tests/EconomyCharacterizationTests.gd` (4 call sites, 3 tests) | Migrated (see section 5) |
| `tests/EconomyRewardTests.gd` (cfg key, 5 call sites, 3 tests) | Migrated; READ ONLY, not run |
| `tests/Stage004SeamTests.gd:1341` comment | Comment fixed |
| `tests/FlowSnapshotFingerprintTests.gd` `snapshot_purity/build_final_snapshot_pays_rewards` | Assertion changed: a win must NOT pay at combat end; a defeat must |
| `ui/` | No consumer of `echo_bonus`, `echoes_alive` or `echo_survived_bonus`. `ui/` does not read `cause`/`params`, and does not read `stage_payout_rows`. `ResolveScreen.tscn:221` "Echoes survived" is the label of the `echoes_survived` count chip: still valid. No `ui/` edit made. |
| `docs/stories/v2-economy-004/phase*.md`, `decisions.md` | History. Not edited. |
| `docs/resolve-snapshot-block-spec.md` | One note added after the Phase 4 note. |
| `scripts/`, `tools/`, `CONVENTIONS.md`, `.github/` | No hit |

New test `econ_char/removed_bonus_keys_absent` now also names `echo_survived_bonus` and `echo_bonus`: it fails if either returns to `data.rewards` or to any `core/` file.

## 4. Tests

New in `econ_char` (4):
- `stipend_per_echo_and_cap`: 1 to 7 Echoes pay 2, 4, 6, 8, 10, 10, 10; row params; stage `ase` = base + stipend.
- `stipend_replay_cap`: on `run_count` 1, 1/2/3/5 Echoes pay 2, 4, 5, 5; cap 5; redo factor does not touch it.
- `stipend_dead_echo_and_no_encounter`: 1 dead of 3 gives alive 2, started 3, lost name; ally and spirit not counted; all dead gives a delta-0 row; no-encounter party of 3 gives 6 and no lost; empty party gives no row; params hold no id key.
- `stipend_dead_echo_on_real_card`: the real stage-ending victory card with one dead Echo: row 8 Ase, 4 of 5, lost name; `echoes_survived` 4; fight `ase_awarded` 0; `flow.complete_stage` pays 33 = card preview.

Extended: `stage_payout_keys_on_real_victory_card` (all five home: row 10, stage Ase 35, fight Ase 0, no fight row, `echoes_survived` 5, preview = paid).
Updated old assertions: `encounter_payer_victory` (0, no rows), `cause_encounter_rows`, `speed_pays_no_ase` (0 each), `stage_payer_matrix`, `multi_objective_stage_sums`, `stage_payer_pays_completed_only` (+2: the stage environment has a party of 1 and no fight, so `_ONE_ECHO_STIPEND` = 2). A defeat still pays the consolation (`encounter_payer_defeat`, unchanged and green).

RAN: compile check, 0 errors. `ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase52`, deleted before each run, exact-name filters:

| Filter | `Tests:` line |
|---|---|
| `=econ_char,realm_reward,economy,objective,venture_char` | 94 total, 94 passed, 0 failed |
| `=pending_result,save_integrity,unified_resolve,foundation_ui,snapshot_contract` | 68 total, 68 passed, 0 failed |
| `=snapshot_fingerprint,snapshot_purity,retreat,flow_transaction,seam,stage` | 85 total, 85 passed, 0 failed |

Not run: `reward` and the full suite, as ordered. Fingerprint, seek, `combat_baseline` and `combat_roundtrip` suites are not run (RUN REQUEST).

## 5. PREDICTED moved values (no constant edited)

Evidence (READ, `phase5-1-attribution.md`): every fingerprint fixture is a win with 5 of 5 Echoes home and run 0. After 5.1 the fixture Ase is 50 (5 x 10), and SAVE `ase` = FINAL `ase_awarded`. The harness hashes the KEY NAMES of `data` (sorted), not the rows (`FlowFingerprintTests._final_fingerprint`). The SAVE hash holds `ase`, `ekwan` and party XP.

| Recorded value | Moves? | One cause |
|---|---|---|
| `*_FINAL_HASH`, all 7 base modes (combat, purify_shrine, recover, protect, endure, pursue, guide_spirit) and the seek FINALs | PREDICTED yes, in EVERY mode, protect and guide_spirit included | `ase_awarded` 50 -> 0: a won fight pays 0 Ase |
| `*_SAVE_HASH`, same modes | PREDICTED yes, in EVERY mode | save `economy.ase` 50 -> 0 (the fixtures do not dispatch `flow.complete_stage`, so no stage payout lands) |
| `data_keys` of the final snapshot | PREDICTED hold | No key is added or removed. The stipend is a row inside `stage_payout_rows`; `ase_awarded` and `reward_breakdown` keys stay (an empty array is still a key). |
| `echoes_survived`, `rank`, `ekwan_awarded`, `objective_state`, `combat_result` | PREDICTED hold | Not touched by this step |
| `*_ROUNDS_HASH` | PREDICTED hold | Rounds finish before any reward read |
| `fingerprint_determinism_*` | PREDICTED hold | Self-checks, no constants |
| `combat_baseline`, `combat_roundtrip` | PREDICTED hold | They pin ticks, save reasons and outcomes. `combat_roundtrip` reads `ase_awarded` only for the forced-retreat card (0 already). `combat_baseline` sets `ase = 500` and does not assert a win payout. I did not read every assertion |
| Side effect | PREDICTED | With `ase` 0 and equal party XP, several SAVE hashes can become equal across modes, as `af54a21d...` did in 5.1. Equality after the change is not a defect. |

The new FINAL `ase_awarded` is 0 in every mode, and the new SAVE `ase` is 0. Expected shape: 14 constants in the base fingerprint suites, plus the matching seek constants. Only the run can confirm.

`reward` tests that had to change (edited, NOT run):
`compute_echo_bonus` (renamed `compute_no_echo_bonus`; asserts the key is absent), `defeat_payout` (signature), `economy_service_adds_ase` (win pays 0; stage pays 34 with 2 Echoes home), `pace_no_breakdown_row` (signature), `pace_escort_reward_protect_none` (signature); `_default_cfg()` now holds the three new keys instead of `echo_survived_bonus`.
Others in `reward` (`pace_*`, `rank_*`, `redo_*`) read none of the changed signatures, by grep. Risk: a compile error in `EconomyRewardTests.gd` would fail the whole project compile; the compile check passed with 0 errors, so the file parses.

## 6. RUN REQUEST (for the main chat)

1. Commands. Delete the save dir before each. Run each group on its own, from the checkout root:
```
rm -rf /tmp/echoes-econ004-phase52-run; ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase52-run /usr/bin/perl -e 'alarm shift; exec @ARGV' 1800 /opt/homebrew/bin/godot --headless --quit --path /Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/echoes-vnext-test-timing-9693e6 -- tests =<group> > /tmp/echoes-econ004-p52-<group>.log 2>&1
```
   Groups: `fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue,fingerprint_guide_spirit` (seven fingerprint suites, expect FINAL and SAVE failures); `fingerprint_seek`; `combat_baseline`; `combat_roundtrip`; `reward` (its own group, expect green); `save_integrity` as a roundtrip check is already green in the short run. Also `fingerprint_determinism_combat,fingerprint_determinism_purify_shrine,fingerprint_determinism_recover,fingerprint_determinism_protect,fingerprint_determinism_endure,fingerprint_determinism_pursue,fingerprint_determinism_guide_spirit` (expect green).
   Use tool `timeout` 1900000 for the fingerprint group; 700000 for the others.
2. Expected duration: fingerprint group about 25 minutes by the shard map; the others a few minutes.
3. Files the run edits: none (suites write only under `ECHOES_TEST_SAVE_DIR`). No `trap` needed.
4. Restore check: `git status --short` lists exactly the files in section 7 and nothing else; `git diff --stat` unchanged.
5. Read back: every `Tests:` line; every line that starts with `❌`, with `expected=` and `actual=` raw; the `FP_DEBUG ... final=` line of each mode (check `ase_awarded` 0 and `data_keys` unchanged); the SAVE `ase`. If a `data_keys` change shows, or a `ROUNDS` hash moves, stop: that is not in the prediction.

## 7. Files changed

- `core/economy/RewardCalc.gd`
- `core/economy/EconomyService.gd`
- `core/economy/StageSettlementService.gd`
- `core/state/flow/states/venture/FlowEncounterState.gd`
- `data/balance.json`
- `tests/EconomyCharacterizationTests.gd`
- `tests/EconomyRewardTests.gd`
- `tests/FlowSnapshotFingerprintTests.gd`
- `tests/Stage004SeamTests.gd` (one comment)
- `docs/resolve-snapshot-block-spec.md` (one note)
- `docs/stories/v2-economy-004/phase5-2-build.md`

## 8. Skipped (Ponytail)

- No `echo_home` object type or class: a plain Dictionary, like `counts`.
- No death record or stage-start record (D-66).
- No second preview path for the no-encounter clear card (`StageExploreSnapshotBuilder`); Phase 3d left it out and no brief asked for it. See OPEN.
- No test for the fingerprint hashes: they are constants, run by the main chat.

## OPEN — questions and assumptions

ASSUMED: On the no-encounter path, "home" and "started" are both the number of roster Echoes in `sanctum.active_party_ids` (nobody fought, so nobody died) | WHY: D-45 brief; the party is built with the same filter | WRONG IF: Jeff wants no stipend, or a different count, for a stage cleared without a fight.
ASSUMED: The row appears at delta 0 when every party Echo is dead (so the card can name the lost) | WHY: D-81 needs `lost` on the row | WRONG IF: the UI wants no row at 0 Ase; then the row must be dropped and `lost` moved elsewhere.
ASSUMED: The stipend uses the LAST fight's dead only | WHY: D-81 says so until permadeath (D-66) | WRONG IF: Jeff expects a death in an earlier fight of the same stage to count. Today a dead Echo returns alive in the next fight (READ, 5.0 section 1), so earlier deaths are invisible to the stage payer.
ASSUMED: Config defaults for missing keys are 0 (stipend off), not 2/10/5 | WHY: AGENTS.md "no hard-coded tunables"; `balance.json` holds the values | WRONG IF: a test or tool builds a reward config without the three keys and expects a stipend.
ASSUMED: `snapshot_purity/build_final_snapshot_pays_rewards` keeps its name but now asserts "a win does not pay at combat end" | WHY: smallest change; the probe still checks the stage Storyweight and emotion write-back | WRONG IF: Jeff wants it renamed.
BLOCKED: none.

FINDING (not fixed, out of scope): the no-encounter stage clear card (`StageExploreSnapshotBuilder.gd:388`) has no stage payout preview, so the stipend is paid on that path but not shown beforehand. Phase 3d named this gap too.
FINDING: `core/state/flow/states/venture/ResolveSnapshotBuilder.gd:29` and `PendingResultService.gd:398` still carry stale block-count comments (Phase 3d reported them).
