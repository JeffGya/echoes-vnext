# V2-ECONOMY-004 Part A — Phase 3b build (completed-only base)

Written in STE. Tags: READ = seen in code or output. MEASURED = I ran it. PREDICTED = not run.
Scope: D-11 to D-15. Not in scope: Ekwan (Phase 4), weights, the 0.25 constant, the 0.12 factor,
`required` flags, the D94 gate, generator, `ui/`. No fingerprint, baseline or pace constant was edited.

## 1. Design

One helper owns the rule: `RewardCalc.base_reward(objectives, cfg, logger, t, mode, fought_index)`.
`mode` selects which objectives count (READ, `RewardCalc.gd`):

| Mode constant | Counts | Reader |
|---|---|---|
| `MODE_COMPLETED` (default) | objectives with `completed` true | stage payer, retreat partial, return-home partial |
| `MODE_COMPLETED_PLUS_FOUGHT` | completed ones, plus the objective at `fought_index` | pace base, rank base |
| `MODE_FOUGHT` | only the objective at `fought_index` | defeat consolation |

- Select first, then weigh. A not-selected objective is never looked up, so it logs nothing.
  A selected type with no key still logs `economy.reward.unknown_objective_type` and counts 0 (D-07 from 3a).
- No "all objectives" mode exists. No reader needs it. Boss: never completed, weight 0, so it adds nothing.
- Why a mode string and not three functions: one loop, one place for the unknown-type log.
- `ActiveStageService.get_stage_base_reward(..., mode = MODE_COMPLETED)` reads `flow_ctx.active_encounter_objective_index` as the fought index.
- `RewardCalc.compute(..., fought_index = -1)` gets one new last parameter. It returns a new key `consolation_base` (fought weight).
  `base_reward` in its result is now the rank base (completed + fought). `FlowEncounterState` passes `consolation_base` to `reward_encounter_complete`.

### Rank (D-12)
Rank uses `MODE_COMPLETED_PLUS_FOUGHT` on both sides: the numerator (`kept`, and `base x defeat_factor`) and `max_possible` use the same `base`.
On a victory the fought objective is already complete when `compute` runs (READ, `FlowRuntime.gd:1696-1700` marks it before `build_final_snapshot`), so plus-fought equals completed.
On a defeat the fought objective is not complete; plus-fought keeps the rank base equal to the pace base (both D-15 style). DECISION FOR REVIEW: D-12 says "completed-only base" for rank. I added the fought objective on defeat only in effect. Completed-only on a defeat would give a numerator of 0 on a first defeat. Either way that rank is F in practice. Say if you want strict completed-only.

### D-15 order check (READ)
`SituationEngagementService.gd:172` sets `active_encounter_objective_index`, then line ~182 `EncounterSetupService.setup(t)` runs, which calls `_setup_pace` (`:688`, `:739`). The index is set before the pace base is read. Confirmed. No BLOCKED.
Other paths to an encounter: `ContactController.gd:650` (hostile claimant) sets -1, so it has no fought objective. `DebugController.gd:312` sets -1.

## 2. Readers of the stage base (grep: `base_reward`, `get_stage_base_reward`, `stage_base`)

| Reader | Place | Mode now |
|---|---|---|
| Stage payer | `StageSettlementService.gd:124` | `MODE_COMPLETED` (default, no edit needed) |
| Encounter retreat partial | `FlowRuntime.gd:1202` | `MODE_COMPLETED` (default) |
| Return-home partial | `VentureController.gd:379` | `MODE_COMPLETED` (default) |
| Pace base | `EncounterSetupService.gd:739` | `MODE_COMPLETED_PLUS_FOUGHT` |
| Rank base, `base_reward` result key | `RewardCalc.compute` via `FlowEncounterState.gd:189` | `MODE_COMPLETED_PLUS_FOUGHT` |
| Defeat consolation base | `RewardCalc.compute` -> `FlowEncounterState.gd:229` -> `EconomyService.reward_encounter_complete` | `MODE_FOUGHT` |
| Pace consumers (not readers) | `CombatState.gd:95`, `FlowEncounterState.gd:202`, `EncounterSnapshotBuilder.gd:293` | read `combat_state.stage_base`, set at fight start |

The 0.25 in `EconomyService.gd:168-169` and the 0.12 factor are unchanged.

## 3. Diff summary

| File | Change |
|---|---|
| `core/economy/RewardCalc.gd` | `MODE_*` constants; `base_reward` takes `mode`, `fought_index`; `compute` takes `fought_index`, returns `consolation_base`. Old D39 narrative comment replaced by a short one. |
| `core/realms/ActiveStageService.gd` | `get_stage_base_reward` takes `mode`, passes the fought index. Comment at `:496` was stale; replaced (see section 5). Old D39 narrative comment shortened. |
| `core/combat/EncounterSetupService.gd` | `_setup_pace` passes `MODE_COMPLETED_PLUS_FOUGHT`. |
| `core/state/flow/states/venture/FlowEncounterState.gd` | passes `active_encounter_objective_index` to `compute`; consolation reads `consolation_base`. |
| `core/runtime/controllers/VentureController.gd` | deleted an outdated comment ("rises on every multi-objective stage"). No code change. |
| `tests/EconomyCharacterizationTests.gd` | Fixtures mark pre-boss objectives completed. KNOWN DEFECT label removed. Six new tests (section 4). |
| `tests/EconomyRewardTests.gd` | The 28 `ObjectiveModel.make(...)` calls pass `completed = true` so base stays 30 / 130 / 60. |
| `tests/VentureCharacterizationTests.gd` (outside your list) | `_expected_intel_partial` mirror sums completed objectives only; `_setup_retreat_env` completes objective 0. Needed or `venture_char/retreat_success_spends_ase_and_awards_intel` fails (it requires a positive partial). |

`StageSettlementService.gd`, `FlowRuntime.gd`: no change; the default mode is the rule.

## 4. Tests (all MEASURED passing)

New in `econ_char`: `stage_payer_pays_completed_only` (a), `uncompleted_optional_adds_nothing` (b), `pace_base_completed_plus_fought` (c),
`first_defeat_pays_fought_weight` (d), `partials_pay_completed_weights` (e), `rank_not_lowered_by_unreached` (f).
Changed: `unknown_type_logs_and_pays_zero` also checks that an uncompleted unknown type logs nothing.
Limits (say so plainly): (e) tests the shared helper and the formula `roundi(base x 0.12 [x 1.5])`. It does not dispatch a real retreat or return-home.
The retreat handler is covered by `venture_char/retreat_*` with objective 0 completed. The return-home handler needs a built explore map; its read is the same call as the retreat read.
Defeat of a non-objective situation: the test pins 0 Ase (see section 6, finding 2).

## 5. Stale comment (`ActiveStageService.gd:~496`)

Confirmed stale. It said "Used for stub-completed types (recover/protect/endure/pursue)". READ: `mark_stage_objective_completed` has one caller, `ContactController.gd:581` (a good charge contact). No code completes a type without a fight. Replaced with one line.

## 6. MEASURED results (short filtered runs, `ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-phase3b`, deleted before each run)

| Filter | `Tests:` line |
|---|---|
| `=econ_char,realm_reward,economy,objective` | 56 total, 56 passed, 0 failed |
| `=venture_char,pending_result,seam,stage` (before the venture_char fix) | 78 total, 77 passed, 1 failed (venture_char retreat) |
| `=venture_char,retreat` (after the fix) | 24 total, 24 passed, 0 failed |
| `=save_integrity,unified_resolve,foundation_ui` | 52 total, 52 passed, 0 failed |
| `=fingerprint_combat,fingerprint_recover,fingerprint_purify_shrine` | 3 total, 0 passed, 3 failed (drift only; confirms the prediction below) |

Compile check: no error. I did not run `reward`, the full suite, or `pending_result,seam,stage` after the venture_char fix (they passed in the run before it; the fix touched only `tests/VentureCharacterizationTests.gd`).

## 7. PREDICTED moved values (no constant edited)

Single cause for all of them: the fingerprint harness `FlowFingerprintTests._setup_encounter` calls `FlowEncounterState.enter` directly.
It never sets `flow_ctx.active_encounter_objective_index` (stays -1) and realm.01 stage 0 (guide_spirit + boss) has NO completed objective.
So at every read the harness gets: pace base 0 (was 16), rank base 0 (was 16), consolation base 0 (was 16 x 0.25). Production sets the index to 0 on engage, so production gives 16 on the first fight.

| Recorded value | Moves? | Why |
|---|---|---|
| `*_FINAL_HASH`, `*_SAVE_HASH` of all mode fingerprints (combat, purify_shrine, recover, protect, endure, pursue, guide_spirit, seek) | PREDICTED yes. MEASURED yes for combat, purify_shrine, recover. | rank base 16 -> 0 changes rank in the final snapshot; pace base 16 -> 0 removes the pace bonus (1 Ase) in pace modes, so ase and the save hash move. In the three measured suites the final and save hashes both drifted. |
| `*_ROUNDS_HASH` | PREDICTED held | rounds are before any reward read; 3a held them. |
| `fingerprint_determinism_*` | PREDICTED hold | self-checks, no constants. |
| `reward/pace_*` pure tests | PREDICTED hold | they pass `pace_stage_base` and completed objectives explicitly. |
| `reward/pace_guide_spirit_runtime_escort_vs_protect` and other runtime `reward` tests | PREDICTED hold | they check that a Pace row exists, not its value (READ, `EconomyRewardTests.gd:~895`). Not run. |
| `combat_baseline`, `combat_roundtrip` | PREDICTED unknown | they use the same harness if they read rank or ase. Not run. Include them in the run. |

RECOMMENDED fix for the main chat to decide (Jeff's call, not mine): make the harness production-shaped by setting `flow_ctx.active_encounter_objective_index = 0` in `_setup_encounter`. Then pace and rank base stay 16 on the first fight, and PREDICTED: the FINAL and SAVE hashes HOLD at their 3a values. That avoids a re-record that only records a harness gap. If Jeff prefers to record the 0-base values, re-record with attribution per mode.

## 8. RUN REQUEST (main chat runs; I do not)

1. Command A, the `reward` suite (own group):
   `ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-3b-reward /usr/bin/perl -e 'alarm shift; exec @ARGV' 4216 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =reward` with tool `timeout` 3700000.
   Expected: about 1054 s (shard-map comment; one test is 991 s). Do I think it is needed? Yes, once. The pace base reaches the runtime tests of this suite. Phase 3a held, so I predict it holds. I could not run it.
2. Command B, the fingerprint and baseline group (shows the PREDICTED drift, or the hold after the harness fix):
   `ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-3b-fp /usr/bin/perl -e 'alarm shift; exec @ARGV' 1800 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =fingerprint_combat,fingerprint_purify_shrine,fingerprint_recover,fingerprint_protect,fingerprint_endure,fingerprint_pursue,fingerprint_guide_spirit,fingerprint_seek,combat_baseline,combat_roundtrip` with tool `timeout` 1900000.
   Expected: about 1500 s serial (shard-map estimates 279 + 344 + 490 + 194 s, plus the small ones). Delete the save dir before each run.
3. Files the run edits: none. The suites write only under the `ECHOES_TEST_SAVE_DIR` directory.
4. Restore check: `git status --short` must show the same file list as before; `git diff --stat` must show no new file under `tests/` or `data/`. Delete the two `/tmp/echoes-econ004-3b-*` directories after reading.
5. Read back: each `Tests:` line, each `❌` line with `expected=` and `actual=` hashes (copy raw), and the `reward` suite result line.

## OPEN — questions and assumptions

ASSUMED: Rank on a defeat uses completed + fought, not strict completed-only | WHY: it keeps rank base equal to pace base, and a strict completed-only numerator would be 0 on a first defeat (rank F either way); on a victory both are identical | WRONG IF: Jeff wants strict completed-only on a defeat (a one-word change: `MODE_COMPLETED` in `compute`).

ASSUMED: A defeat of a non-objective combat situation pays 0 consolation (fought index -1 has no objective weight) | WHY: D-13 says the base is the weight of the fought objective; a non-objective situation has none | WRONG IF: Jeff wants a flat consolation for non-objective fights. Before 3b it paid 25% of the stage sum.

ASSUMED: Editing `tests/VentureCharacterizationTests.gd` (two lines) is in scope | WHY: the suite fails without it and it is a mirror of the rule I changed | WRONG IF: Jeff wants that suite untouched.

BLOCKED: Re-record or fix the harness? | CHECKED: `FlowFingerprintTests.gd:120-196` (the harness never sets the objective index); three measured drifts | NEED: Jeff's decision on section 7 (RECOMMENDED: set the index in the harness).

Findings, report only (not fixed):
1. `EconomyService.gd:100-125` comments still say the base is the "sum of its objective weights" and that the consolation reads "the stage base". Both are stale after 3b.
2. Consolation for non-objective fights is now 0 (see ASSUMED).
3. Repeat return-home partial still has no stamp (B5). Under 3b it can pay only for completed weights, so the exploit is smaller; it is not closed.
4. Ekwan code untouched: it still reads the first objective type and a percentage of Ase (Phase 4).
5. The `_t_pool_frequency` test now reads weights through `MODE_FOUGHT` with index 0; frozen table unchanged.

Ponytail: skipped an "all objectives" mode (no reader needs it), a config switch for the rank base, and a new test for the real retreat dispatch (needs a booted fight). Not checked: `reward` suite, fingerprint harness values after a fix, return-home dispatch.
