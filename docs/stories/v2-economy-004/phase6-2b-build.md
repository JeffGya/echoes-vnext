# V2-ECONOMY-004 step 6.2b build: retreat roll on saved numbers; retreated fight returns (backend)

Rules: D-109 (items 1 and 2), D-106. Nothing is committed. `ui/` is untouched.

## Change 1: retreat roll key (`core/runtime/FlowRuntime.gd` `_handle_encounter_retreat`)

- Old key: `encounter.retreat.<encounter_id>.<t>`. `t` is not saved, so a reload changed the roll.
- New key: `encounter.retreat.<encounter_id>.<run_count>.<turn_count>.<attempt>`.
  - `turn_count`: stage `explore_map.turn_count` (saved).
  - `attempt`: new additive field `retreat_attempts` on the stage record (saved). Default 0.
  - `run_count`: realm `run_count` (saved). This is one number more than the brief named. Reason: a replay may rebuild the stage, and then `turn_count` and `retreat_attempts` restart at 0. Without `run_count` a replay would repeat the same rolls for the same `encounter_id`. Remove it if you do not want it.
- New helper `ActiveStageService.next_retreat_roll_key(flow_ctx, encounter_id)`: reads the three numbers, increments `retreat_attempts`, writes the stage back, returns the key.
- The handler calls it after the D-79 denial check and after the Ase spend, before the roll. A denied retreat counts no attempt. It then calls `_mark_save_requested("encounter.retreat.attempt")`, so the dispatch flush writes the count whether the roll succeeds or fails.
- The null-seed fallback hashes the same key string.
- `CampaignSeed` path style is kept. No other draw moved. The forced retreat is not touched.
- A stage with no record (unit setups) gets attempt 0 and nothing is saved for it.

Seed rule for a second attempt: the attempt number is in the key, so a second try uses a different stream. It can still give the same result by chance (50% at 50%). The test pins that keys differ and that 16 attempt keys do not give one single draw.

## Change 2: a retreated normal fight returns (`core/realms/ActiveStageService.gd`)

- `apply_retreat_return` sets `retreat_pass_turn = <turn_count after the retreat's +1>` on a normal fight it marks passed. Additive field. Objective fights do not get it.
- `find_explore_target` Tier 4 now also takes a passed non-objective situation when `_retreat_passed_due`: it has `retreat_pass_turn` and `explore_map.turn_count > retreat_pass_turn`.
- Order: Tier 1/2 (unvisited targets) and Tier 3 (frontier) still come first. Tier 4 is the last tier.
- Not at once: on the turn of the retreat, `turn_count == retreat_pass_turn`, so it is not offered. It becomes due on the next turn. If nothing else remains, the party parks for that turn and the fight is offered on the next one.
- `stage.ignore_situation` is NOT changed. It sets `passed` only, no `retreat_pass_turn`, so an ignored normal fight is still never re-offered. Same code path did not force a change. No report needed beyond this line.
- Mid-path stops and engagement already treat a passed situation as engageable when its id is the target id (`situation_blocks_step`, `StageExploreTurnService:464`). I changed neither.
- The re-offer carries the tier tag `TIER_PASSED_OBJECTIVE` (same name as for objectives). Only its name is misleading; behaviour (`advance`, bark state key) is the same as for a passed objective. Not changed.

## Tests (suite `retreat`, 28 of 28 pass)

| Test | What it pins |
|---|---|
| `roll_same_after_reload` (REWRITTEN from `roll_tick_is_not_saved`) | Old meaning: a reload changes `t`, so the roll key moves (it pinned the bug). New meaning: after a REAL reload, the key rebuilt from the saved numbers (`run_count`, `turn_count`, `retreat_attempts - 1`) gives the same roll as the live attempt, at ticks that differ by 7 dispatches. Reason: the old assertions describe the fixed defect. |
| `roll_ignores_tick` (new) | The same saved state gives the same outcome at 5 tick offsets. |
| `attempt_count_saved_and_keys_differ` (new) | `retreat_attempts` is 1 on disk after a failed and after a successful attempt; 0 after a denied one; two attempts give different keys; 16 keys do not give one draw. |
| `retreat_passed_fight_returns_later` (new) | Tier 4: not offered on the retreat turn; offered on a later turn; an ignored fight (no marker) not offered; an unvisited situation and an open frontier both come first. |
| `retreat_marks_pass_turn` (new) | A retreat writes `retreat_pass_turn` (4) on a normal fight only. |

`failed_retreat_spend_survives_reload` stays. Its comment says a re-roll after a reload is possible; that is no longer true. The test body is still valid (the 10 Ase is on disk). I did not edit that comment.

Probes that the tests can fail (files restored, `cmp` clean): (a) old key back in the handler: `roll_same_after_reload` and `roll_ignores_tick` fail. (b) Tier 4 marker clause removed: `retreat_passed_fight_returns_later` fails ("retreat, later turn: expected offered=true").

Not tested end to end: a full advance loop that walks to the returned fight and engages it. Probe to show it: build a stage with one passed normal fight with `retreat_pass_turn`, no frontier, dispatch `stage.advance_turn` twice, and read `pending_situation_id`.

## Filtered runs (own `ECHOES_TEST_SAVE_DIR`, deleted before each run). Compile check: zero errors.

| Filter | Result |
|---|---|
| `=econ_char,seam` | 123 of 123 |
| `=objective,objective_combat` | 91 of 91 |
| `=stage,stage_stop_ui,stage_camera` | 84 of 84 |
| `=pending_result,save_integrity` | 30 of 30 |
| `=unified_resolve,foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity` | 52 of 52 |
| `=venture_char,flow_transaction,retreat,payout_ui,summon_price_ui,sanctum.summon` | 131 of 131 |

`=combat_baseline` alone did NOT finish in 115 s (the alarm stopped it). It goes in the RUN REQUEST. I could not record its failing lines.

## PREDICTED moved values

`combat_baseline` (not re-recorded):

| Constant | Old | Predicted new |
|---|---|---|
| `RETREAT_TICK_OUTCOMES` (4 rows, pad 0 to 3, ticks 7 to 10) | pad0 resolve/true, pad1 resolve/true, pad2 encounter/false, pad3 encounter/false | `tick` values stay 7 to 10. `success` and `snapshot_type` become IDENTICAL in all 4 rows (same saved state, same key; one value, unknown until run). So the table test fails on the recorded table, and its second check ("at least one padding offset must differ") also fails. This test no longer has a meaning: it pins tick-binding, which is removed. |
| `RETREAT_FALLBACK_OUTCOME` (`success: true`, `flow.resolve`) | resolve/true | May move (the fallback hashes the new key). 50% chance. |

Others: `snapshot_fingerprint`, `fingerprint_*`, `fingerprint_determinism_*`, `combat_roundtrip`, `maturity_baseline`, `reward`, `fingerprint_seek`: should not move. No draw other than `encounter.retreat.*` changed, no explore snapshot changed, the new stage field `retreat_attempts` is not in a snapshot. `combat_roundtrip` retreats at 100% (roll short-circuits). Risk: a baseline whose save content is hashed would see `retreat_attempts`; I know of none.

## RUN REQUEST (main chat runs; a subagent must not)

1. Command A: `rm -rf /tmp/echoes-vnext-tests && /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =combat_baseline` (tool `timeout: 3700000`). Expected: more than 2 minutes. Read back: every failing line with expected and actual.
2. Command B (own run each, same shape): `=fingerprint_seek`, `=reward`, `=combat_roundtrip`, `=maturity_baseline`, then `fingerprint` (all `fingerprint_*` and `fingerprint_determinism_*`).
3. Files edited by the runs: none.
4. Verify: `git status --short` shows only the three source files, `tests/RetreatTests.gd`, this doc.
5. Then an attribution agent explains each moved `combat_baseline` value. Expected failures: only the two retreat constants above.

## Docs

`CONVENTIONS.md` not edited in this step (the `encounter.retreat` row does not state the roll key; grep it if you want the key written there).

## combat_baseline old and new lines

Test `combat_baseline/retreat_roll_is_tick_independent` (was `retreat_roll_is_tick_bound`), table `RETREAT_TICK_OUTCOMES`.

- expected (old) = `[pad0 flow.resolve true t7; pad1 flow.resolve true t8; pad2 flow.encounter false t9; pad3 flow.encounter false t10]`
- actual (new) = `[pad0 flow.resolve true t7; pad1 flow.resolve true t8; pad2 flow.resolve true t9; pad3 flow.resolve true t10]`

One cause: the roll key no longer contains the tick (D-109). The same saved state gives the same roll at every tick. `RETREAT_FALLBACK_OUTCOME` is unchanged and passed.
