# V2-ECONOMY-004 step 6.2 build: a successful retreat returns the party to the path (backend)

Rules: D-79, D-104 to D-107. Design file: `phase6-early-leave-design.md` section 5. Nothing is committed. `ui/` is untouched.

## What the code does now

1. `encounter.retreat` is unchanged up to the roll: price 10 Ase from config, denied when short (D-79), roll key `encounter.retreat.<id>.<t>`, failed roll starts combat.
2. On success it settles nothing (6.1). It then calls `ActiveStageService.apply_retreat_return(flow_ctx, objective_index, t)`:
   - `turn_count` rises by 1.
   - The engaged situation is the one in `explore_map.last_situation_id` (the same field the victory path uses to find it).
   - Normal fight (`active_encounter_objective_index < 0`): the situation gets `passed = true`. This is the `stage.ignore_situation` mechanism.
   - Objective fight (index >= 0): the situation stays open. `explore_map.retreat_reoffer_id` holds its id.
3. The emotion "withdrawal" modifiers and the vow release check still run (design file section 5: keep). Not changed.
4. The party sees a new Resolve-style card, built by `VentureResolveSnapshotBuilder.build_retreat_return_snapshot(can_reenter, t)`.
5. The card action `stage.retreat_return` (new, owner `VentureController.handle_retreat_return`) goes to `flow.stage_explore`. It only works while the live card has `run_type == "retreat_return"`.
6. `FlowStageExploreState._reset_session_state` copies `retreat_reoffer_id` into `pending_situation_id` AND `last_situation_id`, then the key is gone (not in the rebuilt map). So an objective fight is offered again at once, and a later victory can still find the situation to resolve.

### Card shape (producer H)

```
type: flow.resolve
data: { run_type: "retreat_return", surface: "retreat_return", retreat_outcome: "pulled_back", can_reenter: bool }
actions: { "cta.continue": { type: "stage.retreat_return", label: "Leave", slot: "cta.continue" } }
```

No percent, no odds, no amount, no summary line, no player copy beyond the button label. `can_reenter` is true for an objective fight, false for a normal fight. The UI chooses its line from `can_reenter` (D-107 item 4).

The card is NOT a durable result: `PendingResultService` lists `retreat_return` with the other mid-stage cards (`contact_result`, `situation_result`). A quit on the card writes no `pending_result`. The retreat state (Ase spent, turn, mark) is already saved by the same dispatch.

## Why a new action and not `flow.go_state`

`flow.go_state` to `STAGE_EXPLORE` runs `_apply_victory_return_to_explore`, which calls `apply_vow_stage_entry_condition(t)`. That adds a vow compliance count (or a break) for a stage entry. A retreat is not a new entry. The new action transitions directly and skips it.

Cost: the dispatch action count guard rises from 77 to 78 (`flow_transaction/dispatch_action_count_is_78`, same step as 3c and 5.14 did).

## Effects of using one turn (traced in code, not from comments)

| Reader of `turn_count` | Effect of +1 |
|---|---|
| Escape roll `stage.escape.<stage_id>.<turn_count>` (`VentureController.handle_return_home`) | The next return-home attempt uses a new roll. Before, a failed escape repeated the same roll until the player advanced. A retreat now also works as a way to re-roll a failed escape. No draw reordered. |
| Pace (`pace_full_ratio`, `pace_zero_ratio`, `par_rounds`) | No effect. Pace counts combat rounds, not stage turns. |
| Directive timers | No effect. No directive code reads `turn_count`. |
| `stage_context.encounter_approach.turns_taken` | Written at engage time only. Nothing reads it. No effect. |
| `StageExploreSnapshotBuilder` `data.turn_count` | The `Turn N` label shows N+1. `ui/screens/venture/StageExploreScreen.gd:607`. |
| `SituationEngagementService:485` (adds `turn_cost`) | Same field, unrelated. |
| Session reset (`FlowStageExploreState`) | Keeps `turn_count` because the map is locked. |

## Findings to read (not changed)

1. **A passed normal fight is never offered again.** `ActiveStageService.find_explore_target` (Tier 4) re-offers only passed OBJECTIVES. "Non-objective passed nodes are NEVER re-offered." Rule 4 said "meets it again only later". For a normal fight, "later" is "never in this visit". This is the same as `stage.ignore_situation`. If Jeff wants a normal fight to come back, that needs a design change to Tier 4.
2. **Re-entering an objective fight reuses the same `encounter_id`** (`realm.stage.sit.N`). Every seed path keyed on it (terrain, spawn cell) gives the same board. The retreat roll key differs only by `t`.
3. **Forced retreat (`no_progress_forced_retreat`) does NOT share the new path.** Evidence: (a) the situation stays unresolved and unpassed, so a return to the path puts the party in front of the same stalemate; (b) it is not chosen, costs no Ase and pays nothing; (c) the existing tests pin its Sanctum card. It still builds `build_scout_return_snapshot(..., "forced_retreat")` with `cta.continue` to the Sanctum. New test `retreat/forced_retreat_still_ends_at_sanctum` pins: run_type, destination, no turn spent, no pass mark, no Ase change. Jeff may decide it should share the path later.
4. **Item 7, the retreat roll after a save and reload: the key does NOT repeat.** `t` is the dispatch counter (`FlowRuntime._next_tick`). `boot()` sets `sim_tick = 0` and no save field holds it. After a reload the same fight rolls at a different `t`, so a failed roll can turn into a success. This is pre-existing: the key has not changed in this step, and `combat_baseline/retreat_tick_bound` already pins it as tick-bound. It is also true without a reload: any extra dispatch changes `t`.
   - Reproduction (tests): `retreat/roll_tick_is_not_saved` (30 extra dispatches, reload, tick is lower, no tick in the save).
   - It is a PAID re-roll, not a free one: `retreat/failed_retreat_spend_survives_reload` shows the 10 Ase of the failed try is on disk after a reload (50 to 40). Each new try costs 10 Ase again, and a failed try starts combat.
   - Smallest fix, NOT applied: key the roll on saved numbers, for example `encounter.retreat.<id>.<stage turn_count>.<attempt count>` with a saved attempt counter. This moves the `combat_baseline` retreat table and every retreat roll in the tests, so it needs your decision first.
5. **Adjacent (not in scope):** `flow.go_state` to `STAGE_EXPLORE` re-runs the vow stage-entry check after every `situation_result` card. The tick guard blocks only a repeat on the same tick. This may over-count vow compliance. Not touched.

## Tests

New (`tests/RetreatTests.gd`, suite `retreat`, all pass): `success_returns_to_path_with_card`, `success_costs_one_turn`, `normal_fight_passed_objective_fight_open`, `objective_fight_offered_again_at_once`, `card_has_no_percent_or_odds`, `failed_or_denied_changes_no_stage_state` (failed roll starts combat; denied changes nothing), `forced_retreat_still_ends_at_sanctum`, `roll_tick_is_not_saved`, `failed_retreat_spend_survives_reload`. The Ase cost and denial tests from 5.4 pass unchanged.

Probe that the tests can fail: I removed the `turn_count` increment, the `passed` mark and the re-offer key in `ActiveStageService.apply_retreat_return`. Three tests failed with the right messages (`success_costs_one_turn`, `normal_fight_passed_objective_fight_open`, `objective_fight_offered_again_at_once`). The file was restored (`cmp` clean).

Rewritten tests, each with its reason:

| Test | Reason |
|---|---|
| `venture_char/retreat_success_snapshot_is_scout_return` (renamed `..._is_pulled_back`) | It pinned the scout-return card (13 data keys, "Return to Sanctum" to `flow.sanctum`, intel line, actors). A retreat now publishes the pulled-back card. New pins: 4 data keys, one slot, action `stage.retreat_return`. |
| `venture_char/retreat_success_spends_ase_and_awards_intel` (renamed `..._and_pays_nothing`) | Name only. The assertions are unchanged. |
| `venture_char/scout_return_builder_is_pure_dispatch_consumes_once` | It used `encounter.retreat` to publish the scout-return card and test the one-shot consumption. A retreat no longer does. It now uses a successful `stage.return_home` (`PendingResultTests._drive_withdrawal`). All three contract parts are kept. The card is compared with `count_revealed_situations` instead of a fixture number. |
| `econ_char/settle_retreat_pays_nothing` | It read `ase_awarded`/`ekwan_awarded` = 0 from the card. The new card has no amount keys. Now: no amount key on the card, balance 40/0, no settle marks, no `settle_outcome` (all still checked). |
| `flow_transaction/dispatch_action_count_is_77` (renamed `..._is_78`) | New dispatch case `stage.retreat_return`. |

No assertion was weakened without a replacement. Tests that only call `encounter.retreat` for its side effects (`combat_roundtrip` encounter-id tests) are not changed.

## Filtered runs (own `ECHOES_TEST_SAVE_DIR`, deleted before each run). Compile check: zero errors.

| Filter | Result |
|---|---|
| `=econ_char,seam` | 123 of 123 pass |
| `objective` (objective, objective_combat) | 91 of 91 pass |
| `stage` (stage, stage_stop_ui, stage_camera) | 84 of 84 pass |
| `=pending_result,save_integrity` | pass (8, 22) |
| `=unified_resolve,foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity` | 52 of 52 pass |
| `=venture_char,flow_transaction,retreat,payout_ui,summon_price_ui,sanctum.summon` | 127 of 127 pass |

I ran each group as its own command to stay under 2 minutes. `snapshot_fingerprint` passes 2 of 2 in this tree.

## PREDICTED moved values

| Constant or baseline | Moves? | Why |
|---|---|---|
| `snapshot_fingerprint/*`, `fingerprint_*` (explore modes) | No | The explore snapshot is unchanged when `retreat_reoffer_id` is empty. No retreat card enters a fingerprint. `FlowSnapshotFingerprintTests` builds its own `scout_return` card with `ResolveSnapshotBuilder`, not through the retreat. |
| `fingerprint_determinism_*` | No | No combat or existing draw changed. |
| `combat_baseline` (retreat tick table, `snapshot_type` = `flow.resolve`) | Should not | The roll key and draw are unchanged. The success card is still `flow.resolve`. The transition reason string changed to `encounter.retreat.pulled_back`; I found no pin on the old string in `tests/` (grep). If it moves, it is that string. |
| `combat_roundtrip` | Should not | Two tests retreat at 100% only to free a second engage. They do not read the card. |
| `maturity_baseline` | No | No actor or emotion code changed. |
| `reward` | Should not | No payout code changed in 6.2. Not run (brief). |

## ui/ references that break or change for step 6.3 (not edited)

- `ui/screens/venture/ResolveScreen.gd:215-231`: `run_type == "retreat_return"` matches no branch. It falls to the combat renderer (VICTORY or DEFEAT banner, no keys). Needs a `_render_retreat_return` branch that reads `retreat_outcome`, `can_reenter`, and the action in `cta.continue`.
- `ui/screens/combat/CombatBoardScreen.gd:1219` (`carry_retreat_preview`, amounts always 0 since 6.1) and `:1212-1215` (labels `Escape guaranteed` / `Chance of failure`). D-107 addendum 2 says the button shows `Retreat (10 Ase)` only.
- `ui/screens/venture/StageExploreScreen.gd:607`: the turn label now shows one more after a retreat. Nothing breaks.
- `ui/components/PayoutCausePresentation.gd`, `CarriedHomePanel.gd`, `CarriedHomePresentation.gd`: `partial_retreat` is no longer produced by a retreat. (The scout-return builder still accepts the `partial_cause` argument; only old tests pass it.)
- `tests/ResolvePayoutUITests.gd` (lines 280, 297, 949, 989) keep old static fixtures. They pass. Step 6.3 rewrites them.
- `scripts/screenshot.gd`: old fixtures.

## Docs touched

`CONVENTIONS.md`: the `encounter.retreat` row and a new `stage.retreat_return` row.

## RUN REQUEST (main chat runs these; a subagent must not)

1. Command: `rm -rf /tmp/echoes-vnext-tests && /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =combat_baseline,combat_roundtrip,maturity_baseline` (a comma list needs the leading `=`; without it nothing runs) (tool `timeout: 3700000`).
2. Second command: same shape with the filters `fingerprint_seek` and `reward` (own run each), then `fingerprint` (covers all `fingerprint_*` and `fingerprint_determinism_*`).
3. Expected duration: several minutes per command (`reward` is the slowest suite).
4. Files edited by the runs: none.
5. Read back: the `Tests:` line and every failing test name. Expected: all pass. A failure in `combat_baseline` that names the transition reason or the retreat table is the one to attribute to this step.
