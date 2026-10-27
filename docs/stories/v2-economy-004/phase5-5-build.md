# V2-ECONOMY-004 Phase 5.5: summon price by village size (build note)

Decisions applied: D-55, D-57, D-59, D-60, D-61, D-66, D-73, D-76, D-80, D-85.
Status: built, compile clean, short suites green. Not committed.

## 1. Design

One price function: `SummonService.price_for(summoning_cfg, grade, echo_number)` (`core/sanctum/SummonService.gd`).

| Function | Purpose |
|---|---|
| `living_count(save_data)` | Number of Echoes in the village. Today it is `sanctum.roster.size()`. The permadeath story changes this one function (D-66). |
| `price_for(cfg, grade, echo_number)` | Price of the Echo with that number. Uncalled = table value. Called = table value + `called_extra`. Chosen = table value + `chosen_extra`. |
| `village_ceiling(cfg)` | `data.summoning.village_ceiling` (14). A number above it pays the ceiling price. |
| `batch_prices(cfg, grade, living, count)` | Price of summon 1..count in one action. Summon i pays for Echo `living + i`. |
| `GRADES`, `MAX_BATCH` | The three grade keys and the batch cap (10, the old literal). |

The Echo number being bought = `living_count + 1`.
An Echo number below the first table entry (Echo 1) pays the first entry. This case does not occur in play.

Callers (none does price math itself):

| Caller | Use |
|---|---|
| `SanctumController.handle_summon` | Spends the SUM of `batch_prices`. Never `count x one price`. |
| `SanctumController.handle_grade_select` | Validates the grade against `SummonService.GRADES`. Logs the next price. |
| `FlowSummonState.build_snapshot` | Calls `price_for` and `batch_prices` for every price field. |

Denied summon (balance below the batch total): no spend, no Echo. The handler logs `sanctum.summon.denied` with the list of prices.
It returns the SUMMON snapshot with `data.summon_denied = { reason: "insufficient_ase", count, total_cost, ase_balance }`.
This follows the retreat denial (`retreat_denied`). The old denial returned no snapshot.

`EchoFactory` draw order: unchanged. No new draws. `echo_id` (`roster.size() + 1`, three places): not changed, as ordered.

### Config (`data.summoning`)

| Key | Value |
|---|---|
| `price_by_echo_number` | Dictionary, string keys "2" to "14" (table below) |
| `village_ceiling` | 14 |
| `called_extra` | 90 |
| `chosen_extra` | 340 |

Skill unlock (D-61, D-76): `unlock_conditions.ase_cost` is 60 on all 14 skills in `data.skills.definitions`. No code change was needed.
`ProgressionController.handle_unlock_skill` (`:433`) and `FlowSanctumState.gd:198` already read this key.
Standing 6 and 9 skills do not exist. No content added.

Opening (D-58, D-73): not changed (52 Ase, first trial 40, awakening boost). Echo 2 is a normal `sanctum.summon`, so it calls the same code.
With one Echo in the roster the price of Echo 2 is 60. The shortfall found in Phase 5.0 (40 to 52 Ase against 60) is unchanged. Jeff decides (follow-up 22).

## 2. Price table

| Echo number | Uncalled | Called (+90) | Chosen (+340) |
|---|---|---|---|
| 2 | 60 | 150 | 400 |
| 3 | 60 | 150 | 400 |
| 4 | 70 | 160 | 410 |
| 5 | 85 | 175 | 425 |
| 6 | 100 | 190 | 440 |
| 7 | 120 | 210 | 460 |
| 8 | 145 | 235 | 485 |
| 9 | 175 | 265 | 515 |
| 10 | 210 | 300 | 550 |
| 11 | 250 | 340 | 590 |
| 12 | 300 | 390 | 640 |
| 13 | 360 | 450 | 700 |
| 14 and above | 430 | 520 | 770 |

Example: roster of 3, batch of 3 pays 70 + 85 + 100 = 255 (not 3 x 70 = 210).

## 3. Removal audit (removal exception)

Removed from `data/balance.json` `data.summoning`: `ase_cost_per_summon` (60), `ase_cost_per_summon_by_grade` (60 / 150 / 400). No alias in config.

| Hit before the change | Action |
|---|---|
| `SanctumController.gd:163` (`summ_cfg.get("ase_cost_per_summon")`) | Replaced by `SummonService.batch_prices` |
| `SanctumController.gd:164` (`..._by_grade`) | Same |
| `SanctumController.gd:263` (grade select, `..._by_grade`) | Replaced by `SummonService.GRADES` and `price_for` |
| `FlowSummonState.gd:58` (flat config read) | Removed. Calls `price_for` |
| `FlowSummonState.gd:59` (`..._by_grade`) | Removed |
| `FlowSummonState.gd:89` (snapshot key `ase_cost_per_summon`) | KEPT as a snapshot key. Value = next uncalled price |
| `ui/screens/sanctum/SummonScreen.gd:62` | Reads the SNAPSHOT key. Not edited (`ui/`). It still works. The UI session removes the read later |
| `data/balance.json:103,104` | Removed |
| `tests/SanctumSummonTests.gd` | Tests pinned flat 60 / 150 / 400 and used `economy.ase.add` on the real save. Rewritten with a pinned roster and a direct `economy.ase` set |
| `docs/stories/v2-economy-004/*.md` (phase1, phase5-0, tuning proposal) | History. Not edited |

A test (`sanctum.summon/legacy_price_config_removed`) checks that the config keys are gone and that no `core/` file names `ase_cost_per_summon_by_grade`.
Grep of `core/`, `data/`, `tests/`, `tools/`, `scripts/` after the change: the key `ase_cost_per_summon` remains only as the snapshot key in `FlowSummonState.gd`, and in `ui/screens/sanctum/SummonScreen.gd:62`.

## 4. SUMMON snapshot fields (for the UI session)

All in `data` of the SUMMON snapshot. The batch fields follow the SELECTED grade. The grade resets to `uncalled` on state entry.

| Field | Type | Meaning |
|---|---|---|
| `living_count` | int | Echoes in the village (the roster size today) |
| `village_ceiling` | int | Echo number where the price turns flat (14, from config) |
| `price_flat` | bool | True when the next uncalled price equals the one after it |
| `summon_grade_options[].ase_cost` | int | Price of the NEXT summon of that grade (changed meaning: was a flat price) |
| `summon_grade_options[].ase_cost_after` | int | Price of the summon after the next one, same grade (new) |
| `batch_prices` | Array[int], 10 entries | Price of summon 1..10 in one action, selected grade |
| `batch_totals` | Array[int], 10 entries | Running sums of `batch_prices`. Total for count N = `batch_totals[N-1]` |
| `batch_affordable_max` | int, 0..10 | Largest count the balance pays. 0 = no summon is affordable |
| `ase_short_by` | int | For ONE summon (the next): `max(0, batch_prices[0] - ase_balance)`. See ASSUMED 1 |
| `ase_cost_per_summon` | int | LEGACY. Equals the next uncalled price. Remove the UI read later |
| `summon_disabled`, `summon_disabled_reason` | bool, String | True (`not_enough_ase`) when `batch_affordable_max` is 0 |
| `actions["cta.summon"].disabled` | bool | Same as `summon_disabled` |
| `summon_denied` | Dictionary | Only on the snapshot returned by a denied `sanctum.summon`: `reason`, `count`, `total_cost`, `ase_balance` |

The UI must clamp the count to `batch_affordable_max` (at least 1). A larger count is denied by the handler.
For a count above 1 the UI computes the shortfall as `batch_totals[count-1] - ase_balance` (subtraction only).

## 5. Tests

`sanctum.summon` now has 26 tests. New: price table Echo 2 to 16, called and chosen prices, `living_count`, batch of 3 at Echo 4 pays 255,
deny at 254 (3 x 70 = 210 would have passed), `batch_prices` / `batch_totals` / `batch_affordable_max`, `ase_short_by` and `summon_disabled`,
`price_flat` at rosters 11, 12, 13, 14, 20, grade options with `ase_cost_after`, 14 skills at 60, legacy config removed.
Changed: `sanctum.summon` (pinned roster, direct Ase set), `PartyTests._t_over_cap_capped` (Ase set directly to 5000 so a larger real roster cannot cause a silent denial),
`SkillUnlockTests._t_unlock_skill_spends_ase` (spends 60: 100 to 40).

## 6. PREDICTED moved values (one cause each)

| Value | Predicted | Cause | Seen |
|---|---|---|---|
| SANCTUM snapshot fingerprint (`SANCTUM_FINGERPRINT_HASH`) | no move | The change touches only the SUMMON snapshot and `data/balance.json` summoning keys | `snapshot_fingerprint` green; nothing re-recorded |
| SUMMON snapshot key list | grows | New fields in section 4 | no test pins this list |
| Any fingerprint that reads `data.skills` `ase_cost` | would move | Skill cost 40 to 60 | none found; suites green |
| Any recorded value that holds a summon price | would move | Flat 60 / 150 / 400 replaced by the table | only the tests listed in section 5 |
| `maturity_baseline`, `fingerprint_*`, `fingerprint_seek`, `combat_roundtrip` | no move | No `EchoFactory` draw changed; no combat or stage input changed | NOT RUN here: see RUN REQUEST |

## 7. RUN REQUEST (main chat)

I ran these in short groups and all printed a `Tests:` line with 0 failed: `sanctum.summon, sanctum.party, sanctum.layout, onboarding, skill_unlock, skill_reach` (108);
`prog, econ_char, economy, realm_reward, venture_char, pending_result, save_integrity` (142); `foundation_ui, snapshot_contract, snapshot_fingerprint, snapshot_purity, flow_transaction` (48);
`echofactory, sanctum_pulse, institution, vow` (59); `stage` (10); `seam` (44).

Not run by me (long): the fingerprint family, seek, baseline, roundtrip, maturity_baseline, and `reward`.

1. Command (run each group as its own run; replace the names; delete the save dir before each):
   ```
   rm -rf /tmp/echoes-econ004-phase55; ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase55 /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path /Users/jeffreygyamfi/Sites/echoes-vnext/.claude/worktrees/echoes-vnext-test-timing-9693e6 -- tests =<GROUP>
   ```
   Pass tool `timeout` 3700000.
   Groups: (a) `fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue,fingerprint_guide_spirit,fingerprint_seek`
   (b) `fingerprint_determinism_combat,fingerprint_determinism_purify_shrine,fingerprint_determinism_recover,fingerprint_determinism_protect,fingerprint_determinism_endure,fingerprint_determinism_pursue,fingerprint_determinism_guide_spirit`
   (c) `combat_baseline,combat_roundtrip` (d) `maturity_baseline` (e) `snapshot_fingerprint` (f) `reward` alone.
2. Expected duration: minutes per group; `reward` is the longest.
3. Files edited by the run: none. The tests write only under `/tmp/echoes-econ004-phase55`. No restore step is needed.
4. Restore check: `git status --short` must list only the files in section 8.
5. Read back: the `Tests:` line of each group and any line with a failure mark.

## 8. Files changed

- `core/sanctum/SummonService.gd`
- `core/runtime/controllers/SanctumController.gd`
- `core/state/flow/states/sanctum/FlowSummonState.gd`
- `data/balance.json`
- `tests/SanctumSummonTests.gd`, `tests/PartyTests.gd`, `tests/SkillUnlockTests.gd`
- `docs/stories/v2-economy-004/phase5-5-build.md` (this file)

## 9. Findings (not fixed, out of scope)

1. `handle_summon` spends Ase (step 4) BEFORE the `seed_root` check (step 5). A missing `seed_root` loses the Ase and gives no Echo. Pre-existing.
2. `echo_id = roster.size() + 1` in `SummonService.gd` (two places) and `RecruitmentService.gd:227`. It repeats an id once permadeath removes Echoes. Permadeath story, as ordered.
3. A recruit raises `living_count` by 1 (no Ase spent) and so raises the next summon price. This matches D-55 and ANSWERS #28.
4. `FlowSnapshotFingerprintTests` has no SUMMON snapshot case, so the new fields have no fingerprint cover. Only `sanctum.summon` tests cover them.
5. Test log lines `RetreatService: ... retreat_ase_cost is missing` and `SaveService: missing schema_version` appear in suites I ran. They come from test fixtures that use a thin config or an invalid save on purpose. Not caused by this change; I did not investigate.
