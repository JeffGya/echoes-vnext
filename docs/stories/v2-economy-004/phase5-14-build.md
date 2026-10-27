# Step 5.14 (backend): death record lifetime, stipend config reads, dead action

Decisions: D-103 (F4, F2, F6). No `ui/` file and no `data/` file changed.

## F4: stage death record lifetime
- Finding (READ-FROM-CODE): nothing clears `lost_echo_names` inside a run. `ActiveStageService.record_fight_deaths` is the only writer. `stage.return_home` rewrites the same stage dict and keeps the field.
- A replay does not inherit it: `RealmService.get_or_create` builds a new model with new stages from `RealmGenerator.generate` when the old model is `completed`. The generator never writes the field. `carried_ase` resets the same way.
- No code change. A clear would be dead code.
- New test `econ_char/death_record_survives_return_home_and_replay_starts_empty`: death in fight 1, `stage.return_home`, record and stipend row still hold the death; old model marked completed, `get_or_create` gives `run_count + 1` and no stage has the field.
- Limit: the test drives `stage.return_home` once. Either escape result keeps the record. It does not play a full second visit through the UI.

## F2: stipend keys through `RewardCalc.cfg_num`
- `StageSettlementService._echo_home` now takes `log` and `t` and reads `echo_home_ase`, `echo_home_cap`, `echo_home_cap_replay` with `cfg_num` (safe value 0.0). Result is `int(...)`, same as before for a present key.
- `econ_char/missing_rewards_key_logs_and_returns_safe_value` now also checks that an empty config logs `echo_home_ase` and `echo_home_cap_replay` (replay run) and returns rate 0, cap 0.

## F6: `stage.confirm_return_home` removed
- Removed: the `FlowRuntime.dispatch` arm, `VentureController.handle_confirm_return_home`, the venture_char test `_t_confirm_return_home`, and the comment counts (controller owns 9 actions; `VentureController` header 10).
- Test `scout_return_builder_is_pure...` used the action as a "non-scout dispatch". It now uses `stage.dismiss_overlay`.
- Guard count 78 to 77: `FlowTransactionTests.EXPECTED_ACTION_COUNT`, test name `dispatch_action_count_is_77`, `docs/integration-map.md`.
- Audit (core/, ui/, tests/, docs/, scripts/): no `ui/`, `scripts/` or `CONVENTIONS.md` reference. Remaining text hits are history only: `docs/stories/v2-payout-explanation/decisions.md`, `docs/stories/v2-infra-003/handoff.md`, `decisions.md` D-103.
- `FlowActionOutcome.transition_outcome` and `FlowStateIds.STAGE_MAP` have other users; kept.
- `return_failed`: no core writer exists. Readers: `ui/screens/venture/StageExploreScreen.gd:612` (ui, not edited), `tests/StageExploreTests.gd` test 10 (injects the flag by hand), stale lines in `CONVENTIONS.md` 1078 and 1245 and a comment in `FlowStageExploreState.gd:24`. Not removed here: the ui reader belongs to the other agent. The core `return_home_result.message` ("The way is blocked...") on a failed escape is reachable and stays.

## Verified (filtered, own save dir)
All pass: econ_char 72, objective 91, seam 44, stage 84, pending_result 8, save_integrity 22, unified_resolve 13, foundation_ui 17, snapshot_contract 8, snapshot_fingerprint 2, snapshot_purity 12, venture_char 15, flow_transaction 9, retreat 15, payout_ui 36, summon_price_ui 10, sanctum.summon 31. Compile check: zero errors.
Predicted moved values: none. Not yet measured: fingerprint, reward, baseline suites (RUN REQUEST).
