# V2-DIRECTIVE-002 phases B+C: backend plan (subtask 1)

Author: `mechanics-developer`, 2026-10-12. Branch `claude/v2-directive-002-phase-bc`. No code was changed. No test was run. Every line number below was read from the working tree on 2026-10-12.
Sources: `design.md` (D-43), `decisions.md` D-00 to D-45, `numbers.md`, `data/balance.json` (`stages.party_stance` at :3104, `stages.presentation` at :3228, `contact.bid` at :3524), ANSWERS #81 to #83, LESSONS #34 and #35, `docs/movement-model.md` section 11.

## 0. Findings that change the plan (read first)

| # | Finding | Effect |
|---|---|---|
| F1 | The pool rule (design 3.1, D-28) is missing from the six slices in the brief. It is design re-record step 2 and the biggest value move. | Added as slice S1c. |
| F2 | One `find_explore_target` call costs about 58 ms. One Advance with 7 calls costs about 420 ms (`docs/stories/v2-infra-010/evidence-2026-10-06.md:22`). Nine full counterfactual re-walks would add about 3.8 s per Advance. | Feasibility 1: full re-walk is NOT feasible. Use the first-plan-only fallback and share the reachable region (section 2). |
| F3 | `pause_cap_per_advance` is ambiguous. If a pause ends the Advance, at most one pause happens per Advance and a cap of 2 never matters. D-45 measured "pauses per Advance" with every situation ignored, so it counted pause points on a walk that did not stop. | BLOCKED question B1. Plan assumes a pause ends the Advance. |
| F4 | `data/balance.json:3195` (`pause_cap_per_advance`) now holds 2, as D-45 decided (the file changed while I worked; my first read showed the placeholder 3). `numbers.md` section 7 still says 3 and "set after probe". | Docs fix only: `numbers.md` is stale. Not a data fix. |
| F5 | The snapshot builder does not re-derive only the reactive threshold. It re-derives the WHOLE bid rule with its own role table (`StageExploreSnapshotBuilder.gd:187-201`) and ignores suppression and boost. The card and the simulation can already disagree. | S4a/S4b: the builder must read the bid from one shared function, not a second copy. |
| F6 | `MovementStyleService` is at `core/actors/behaviors/MovementStyleService.gd`, not `core/movement/`. `style_alignment_score` (:108) already adds Calling-family bias, fear and morale bias. The stance also leans on Calling family, fear and morale. Calling the full score counts those inputs twice. | S2b calls it with family "", fear 0, morale tier "", no bonds, no vow, no traits (vector term only). ASSUMED A2. |
| F7 | The Judgment inputs (`ctx_inputs`) for `derive_expression` are built inline in `ActorStateMachine.gd:166-207`. No shared reader exists. | S2a extracts one static reader. Combat hashes must not move. |
| F8 | `_reset_session_state` (`FlowStageExploreState.gd:55`) rebuilds `explore_map` from a fixed key list on EVERY `enter()`. A new key in `explore_map` is dropped on the next entry unless this function carries it. | S5 must carry the journey entry and `stop` through this function. |
| F9 | `docs/movement-model.md` 11.9 says the last Movement Result "must not replay after load". D-41 saves `stop` so the glyph returns. | Docs-pass note: only the sanitised `stop` and `travel_why` persist. The result itself is not replayed. |
| F10 | The stage fingerprint (`FlowSnapshotFingerprintTests.gd:326`) hashes the whole `data` dict at stage entry, with no Advance. Any new snapshot key moves it. Behaviour changes in S1 to S2 cannot move it. | Add every new snapshot key in ONE slice (S3), so the hash is re-recorded once. |
| F11 | The task brief and the design name three wrong paths: `core/realms/StagePartyMovementAdapter.gd` (real: `core/movement/StagePartyMovementAdapter.gd`), `core/movement/MovementStyleService.gd` (real: `core/actors/behaviors/`), and `data/balance.json:3384` for the resonance key (real: `:71`). | Fix in docs pass. |

## 1. Contract confirmation

Status: OK = matches the design. MISMATCH = the design or brief is wrong. GAP = the design assumes something the code does not give.

| # | Seam the design names | Verified file:line | Status |
|---|---|---|---|
| 1 | Turn service `advance_turn` | `core/realms/StageExploreTurnService.gd:110` | OK |
| 2 | Live loop re-plans each step and drops `build_result` | loop `:196-258`; `build_result` at `:218` and `:258`, return value unused | OK (design 13 row 4) |
| 3 | Escape-roll increment of `turn_count` | `:170`; read in `VentureController.gd:337` (threshold) and `:340-343` (draw `stage.escape.<stage>.<turn_count>`) | OK |
| 4 | Fog lift per step | `:190` (origin), `:251` (each step) via `ActiveStageService.lift_fog_at_cell` (`ActiveStageService.gd:212`, returns void) | OK |
| 5 | Reveal sweep after the walk | `StageExploreTurnService.gd:309` calls `FlowStageExploreState._reveal_explored_situations_static` (`FlowStageExploreState.gd:652`) | OK |
| 6 | Reveal RNG is order-independent | `_reveal_situation_static` draws `CampaignSeed.get_rng_from(realm_seed, "stage.reveal.<sit_id>")`. Key is per situation. | OK. Feasibility 2. |
| 7 | `shortest_path` call passes `{}` for costs | `StageExploreTurnService.gd:214` (`terrain_costs` `{}`, `bounds` `{}`, `edge_costs` omitted) | OK. Signature `MovementPathService.gd:16`. Costs must be int >= 1 (`_entry_cost` :269). |
| 8 | `find_explore_target` | `ActiveStageService.gd:401`; Tier 1 `:416-435`; Tier 2 `:437-460`; Tier 3 `:461-484`; Tier 4 `:486-507` | OK |
| 9 | Tiers 1 and 4 pass `{}` as weights | `ActiveStageService.gd:429-431` and `:500-502` | OK. `target_preference.objective` has no reader (design 13 row 6). |
| 10 | Weight is looked up by situation category only | `StagePartyMovementAdapter.gd:936-946` (`_target_weight`) | OK. An objective needs a new branch (S1c). |
| 11 | Slack envelope | `StagePartyMovementAdapter.gd:892` (`_slack_envelope`); constants `:262-263`; config via `ConfigService.get_movement_slack_cfg` (`ConfigService.gd:429`) | OK |
| 12 | Selection rank is a total order | `StagePartyMovementAdapter.gd:841-853`: weight, distance, id, col, row | OK. The bend becomes a second key (S2c). |
| 13 | Adapter location | `core/movement/StagePartyMovementAdapter.gd` (1060 lines). Header "DORMANT" `:2-4` is stale. | MISMATCH (brief path wrong, F11) |
| 14 | `build_profile` / `build_goal` / `build_intent` / `build_result` | `:294` / `:362` / `:472` / `:547` | OK |
| 15 | `TIER_PRESSURE_SOURCE` | `:197`. Tier constants `:177-180`. 15 test sites use `TIER_OBJECTIVE` (`StagePartyMovementTests.gd`). | OK. Feasibility 7. |
| 16 | `STOP_REASONS` | `core/movement/contracts/MovementResult.gd:9-21` and `MovementEvent.gd:9-21`. Both lack `arrived_at`, `spotted_ahead`, `paused_to_read`. | GAP (feasibility 3) |
| 17 | `MovementResult.validate` accepts a multi-cell result | `MovementResult.gd:100-205`. `planned_path` and `actual_traversed_cells` are validated apart. No "actual is inside planned" rule. | OK. S1a can build one result for a frontier chain. |
| 18 | Directive accessor and schema | `DirectiveService.gd:192` (`active_id`), `:201` (`resolve`), `:41` (`ENTRY_SCHEMA`, holds `exposure_tolerance`), `:52-55` (`CONTACT_EFFECT_KEYS`) | OK |
| 19 | Rename target `witness_resonance_bonus` | Guard key `DirectiveService.gd:54`; data `balance.json:71`; doc `CONVENTIONS.md:938`. No test and no other code read it. | OK. Design 12 cites `:3384`: MISMATCH. |
| 20 | `ConfigService` getter pattern | `get_movement_slack_cfg` `:429`; `get_directives_cfg` `:134`; `get_party_max_size` `:146`; load abort `:29` | OK |
| 21 | Party-stance data location | `data.stages.party_stance` (`balance.json:3104`). `directive_profile` keys are Directive ids, so no id literal in code. | OK (D-44). The `_comment` at `:3210` says "move later". It is stale after D-44. |
| 22 | `compute_bids` | `ConversationService.gd:458`; suppression `:475`; reactive `:483`; alignment `:489`; boost `:494`. Takes `(party_echoes, contact, dir_fx)`. No config, no Judgment. Callers: `ContactController.gd:201`, `:424`; `ContactConversationService.gd:93`. No test calls it. | OK |
| 23 | Turn score | `ConversationService.gd:162` (`compute_turn_score_from_virtue`); clamp `:184`; NPC fear gate `:287`; also `:292` literal `0.2`; `:297` morale `<= 20`, `:299` literal `0.1` | OK. Two more literals than design 10.1 lists (see section 3, S4a). |
| 24 | `generate_responses` calls the turn score | `ConversationService.gd:108`. The Echo dict is the save Echo. No Directive reaches this function. | GAP: the resonance bonus needs a new argument (S4c). |
| 25 | Contact turn-count literals | `ContactConversationService.gd:74` (fear `> 60`), `:76` (morale `< 30`) | OK |
| 26 | Snapshot builder second bid copy | `StageExploreSnapshotBuilder.gd:187-201`. It also ignores Directive suppression and boost. | MISMATCH (F5): bigger than "a second literal" |
| 27 | Snapshot party-size literals | `StageExploreSnapshotBuilder.gd:258` (`>= 5`), `:346` (`> 3`); `ContactController.gd:170-171`, `:422`; `ContactConversationService.gd:116` | OK. Classified in feasibility 8. |
| 28 | Snapshot directive fields | `StageExploreSnapshotBuilder.gd:414-421`; data keys `:469-471` (`directive`, `step_budget`), `:476-493` (path, bark) | OK |
| 29 | Shared Echo view | `SanctumService.get_party_actors_static(save_data)` (`SanctumService.gd:56`) returns `EchoActor.from_echo` views in `active_party_ids` order. `EchoActor.from_echo` at `EchoActor.gd:22`; top-level `fear`, `morale`, `fear_base`, `rank`, `vector_scores` (`:58-60`). | OK |
| 30 | Judgment source | `MaturityExpressionService.derive_expression(actor, ctx_inputs, expr_cfg)` at `MaturityExpressionService.gd:130`. `judgment` is subtracted by fear inside (`fear_pressure_weight`). `interpretation_width = clampf(judgment, 0, 1)` (`BehaviorArbiter.gd:349`). | OK |
| 31 | `ctx_inputs` has a shared reader | Built inline in `ActorStateMachine.gd:166-207`. Combat bonds come from `CombatTurnContextService.gd:129` (`sanctum.bonds`). | GAP (F7). Feasibility 6. |
| 32 | Calling family lookup | `ActorStateMachine.gd:166` (`data.calling.definitions.<id>.family`) | OK |
| 33 | Identity service | `core/actors/behaviors/MovementStyleService.gd`: `STYLES` `:26`, `style_alignment_score` `:108` | MISMATCH path (F11); behaviour OK |
| 34 | Stage save repair | `SaveService.gd:1210` (explore_map default), `:1260-1313` (per-key defaults, same style) | OK |
| 35 | Session reset | `FlowStageExploreState.gd:31` (`enter`), `:55` (`_reset_session_state`), key list `:96-123` | OK. F8. |
| 36 | `last_traveled_path` and `travel_bark` ride the same dict | `StageExploreTurnService.gd:275-283`, `:381-385`; projected by `StageExploreSnapshotBuilder.gd:479-493` | OK |
| 37 | Party max | `balance.json:172` (`party_max_size` 5.0); `ConfigService.get_party_max_size` returns `int` | OK |
| 38 | Existing party-fear readers | `FlowStageExploreState.gd:360` (`cautious_advance_fear_threshold`), `:474` (`party_return_fear_threshold`). Different meaning from readiness bands. | OK (do not touch) |
| 39 | Config validation of unknown keys | `DirectiveService.validate_entry_schema` rejects unknown keys in a Directive entry only. `data.stages.*` is not schema-checked. | OK. New blocks load without a validator change. |
| 40 | Test mocks of `ConfigService` | `tests/StageObjectiveTests.gd:40` `MockStageConfig extends ConfigService` (fixed in PR #106). `tests/SkillLoadoutTests.gd:33` defines `get_balance()` but is not passed to any stage getter. | OK. LESSONS #35 check done for the getter signature. |

## 2. Feasibility checks (design section 12, end)

| # | Question | Answer | Evidence |
|---|---|---|---|
| 1 | Cost of counterfactual dry runs | **Full re-walk: not feasible. Use first-plan-only.** | `evidence-2026-10-06.md:22`: 7 `find_explore_target` calls = 417 ms; `reachable_region` x14 = 389 ms. Each call builds the full-map region twice (`ActiveStageService.gd:414` via `stage_reachable_costs` `:259`, and `StagePartyMovementAdapter.select_frontier` `:661`). The region depends only on `party_pos` and `walkable`, never on the Echo. Plan: a dry run for one candidate does one target pick, one priced path and one stop prediction at the ORIGIN, with the region computed once per Advance and shared (optional argument on `find_explore_target`). Cost per dry run: tens of microseconds to a few ms (`shortest_path` x6 = 2.4 ms in the same evidence). Nine dry runs stay near the cost of one `shortest_path` each. Compared fields: target, ordered path cut at effective steps, effective steps, commitment depth, predicted stop kind. A frontier chain beyond the first leg is NOT compared. This is the fallback the design allows. |
| 2 | Per-step reveal without moving the sweep order | **Yes, with a read-only peek.** | The sweep at `StageExploreTurnService.gd:309` stays where it is. Its RNG is keyed by situation id (finding 6 in section 1), so order cannot change a draw. Do NOT reveal per step: that would make a new find targetable inside the same walk and change routes (a second cause). Instead `lift_fog_at_cell` returns the keys it added; a pure `peek` lists unresolved, unrevealed situations on those keys and classifies them. The loop may then stop. Reading `type` and `is_objective` of a situation the fog lift just exposed is not concealed-content leakage: the sweep reveals it a few lines later. |
| 3 | Do stop kinds fit `STOP_REASONS`? | **Partly. Do not extend the shared contract.** | `STOP_REASONS` is shared by combat and checked in `MovementResult.gd:128` and `MovementEvent.gd:108`. Map: `arrived_at` = `reached_destination`; `capacity_spent` = `capacity_spent` (also `commitment_spent` when the commitment ends first); `interrupted` = `interrupted`; `no_route` = `no_route`. `spotted_ahead` and `paused_to_read` both use result reason `interrupted`. The six player kinds live in a stage-owned field `stop.kind`, set by `StageStopPolicy`. No contract file changes. |
| 4 | Maximum party size | **5.** | `balance.json:172`, `ConfigService.get_party_max_size`. Candidate cap = 5 + 4 reason classes = 9 (matches `numbers.md` section 8). Read the cap from config, never from a literal. |
| 5 | Lowest-id tie-break can pin one Echo | **The pin can happen. It needs two Echoes with equal dial contributions and equal removal effects.** | That needs the same Calling family, same vector profile, same fear and morale band, same Standing and same bonds. It is rare on real parties. Fix without RNG, if Jeff wants one: among tied Echoes in id order, name index `turn_count % tied_count`. `turn_count` is saved state and the party-order shuffle test (N4) still holds because the list is id-sorted first. Default: ship as designed (lowest id). See Jeff item J3. |
| 6 | Bond edges reach stage Judgment through the combat path | **Yes, once S2a extracts the reader.** | Combat: `bonds` = `sanctum.bonds` (`CombatTurnContextService.gd:129`), filtered to the actor and to living party members (`ActorStateMachine.gd:177-191`), thresholds from `sanctum.bond_thresholds` (`ConfigService.get_bond_thresholds_cfg` `:121`). S2a moves that assembly into `MaturityExpressionService.build_ctx_inputs(...)`. `ActorStateMachine` calls it. Stage calls it. A parity test proves both give the same `judgment`. |
| 7 | Keep `TIER_PRESSURE_SOURCE` `state.tier_objective`? | **Keep.** | After S1c the pool pick returns tier `TIER_OBJECTIVE` when the chosen candidate is the objective and `TIER_WEIGHTED` otherwise. The token then still names a true selection state. 15 test sites use the constants. Retiring it gains nothing. |
| 8 | Party-size literals | **`StageExploreSnapshotBuilder.gd:258` (`>= 5`): tunable, duplicates `party_max_size`: read `ConfigService.get_party_max_size` (same value). `ContactController.gd:171` (slice to 3), `:422` and `ContactConversationService.gd:116` (auto-respond when party <= 3), `StageExploreSnapshotBuilder.gd:346` (`> 3`): one meaning, "voices per contact turn": tunable.** | Move to ONE new key `data.contact.max_voices_per_turn` = 3 (same value). A new config key is a design-number placement. The value does not change. Needs `mid-game-designer` to author it (J5). Until then they stay and are listed in the report. |

## 3. Sliced backend plan

Order is serial. Each slice ends with the compile check and its filtered suites. No slice runs the full suite. `qa-verifier` verifies each slice; the builder never does.
Re-record order follows design 11: (1) exposure map and one result, (2) pool, (3) bends, (4) stop kinds, (5) bid scaling and threshold move, (6) resonance.

Global rules for every slice:
- No new RNG draw. No `EchoFactory` change. No new `CampaignSeed` path.
- New config reads go through `ConfigService` static getters (pattern `get_movement_slack_cfg`). An absent block gives neutral behaviour, so old test fixtures keep passing.
- A new typed parameter: grep `tests/` for duck-typed fakes first (LESSONS #35). Result of the grep is in each slice.
- Stage code never names a Directive id (ANSWERS #81). `directive_char` scan must stay green.
- Slice order table:

| Slice | Subject | Moves recorded values | Builder tier |
|---|---|---|---|
| S0 | Config getters and integrity test (DONE 2026-10-12, uncommitted) | No | sonnet |
| S1a | One result per Advance | No | sonnet |
| S1b | Exposure map live | Yes (small) | sonnet; opus attributes |
| S1c | Objective joins the pool | Yes (largest) | sonnet; opus attributes |
| S2a | Shared Judgment input reader | No (combat must not move) | opus |
| S2b | Party stance: dials, readiness, capacity, commitment | Yes | sonnet |
| S2c | Category-weight bend and frontier ranking | Yes (small) | sonnet |
| S2d | Return-safety bend | Yes (escape tests) | sonnet |
| S2e | Counterfactual naming | No (adds data only) | opus |
| S3 | Stop kinds, reveal peek, snapshot fields | Yes, and the stage fingerprint | sonnet; opus attributes |
| S3b | D-52 fixes F1, F2, F5, F6 | Yes (gen100_scout, stage fingerprint) | opus |
| S4a | Contact literals to config | No | sonnet |
| S4b | Bid scaling, one shared bid function | Yes (contact tests) | sonnet |
| S4c | Resonance bonus and rename | Yes (score tests) | sonnet |
| S5 | Saved journey entry and `stop` | Save schema | opus |

### S0. Config getters and integrity test

**Status: DONE (2026-10-12).** Getters are in `ConfigService.gd` (`get_party_stance_cfg`, `get_party_stance_profile`, `get_stage_presentation_cfg`, `get_contact_bid_cfg`, `get_contact_turn_count_cfg`, `get_contact_emotional_fit_cfg`, `get_contact_max_voices_per_turn`). Seven tests are in suite `movement`, group `movement/stage_party/`. No reader exists yet. Test names differ from the table below: `party_stance_covers_every_directive`, `party_stance_missing_entry_is_neutral`, `party_stance_bounds_under_half_gap`, `party_stance_reason_classes_count`, `stage_presentation_keys_numeric`, `contact_cfg_getters_match_shipped_values`, `stance_cfg_getters_null_service_empty`.

| Item | Plan |
|---|---|
| Files | `core/config/ConfigService.gd`; `tests/StagePartyMovementTests.gd` (suite `movement`) |
| New functions | `static func get_party_stance_cfg(config_service: ConfigService) -> Dictionary` (reads `data.stages.party_stance`); `static func get_stage_presentation_cfg(config_service: ConfigService) -> Dictionary` (`data.stages.presentation`); `static func get_contact_bid_cfg(config_service: ConfigService) -> Dictionary` (`data.contact.bid`); `static func get_contact_turn_count_cfg(config_service: ConfigService) -> Dictionary` (`data.contact.turn_count_modifiers`). All return `{}` for a null service or a non-Dictionary value. |
| Config keys read | none yet (readers only) |
| Tests | Suite `movement`: `movement/party_stance_bounds_under_half_gap` (each bound in `bounds` is below half the gap between the two Directive baselines, read from `data.directives`; `category_weight` below half of 0.2); `movement/party_stance_covers_every_directive` (every id from `DirectiveService.available_ids` has a `directive_profile` entry with the three keys); `movement/party_stance_reason_classes_count` (4); `movement/stage_presentation_keys_numeric`; null-config getters return `{}`. |
| Fingerprints that move | None. |
| Tier | sonnet. Pure reads. |
| Risk | Low. A wrong key path returns `{}` and later slices fall back to neutral. The tests catch a wrong path. |
| Rollback | Revert the commit. Nothing reads these yet. |
| LESSONS #35 grep | Getter takes `ConfigService`. `MockStageConfig` extends it. No other fake reaches a stage getter. |

### S1a. One result per Advance (refactor, no value moves)

Status: BUILT 2026-10-12, not committed, not verified by qa-verifier. Filters traversal, movement, seam run; only the known red failed. Tests renamed: `result_cleared_without_move` replaces `no_route_result_kept` (a real no_route is not reachable from the fixtures).

| Item | Plan |
|---|---|
| Files | `core/realms/StageExploreTurnService.gd` |
| Change | Keep the loop, the target pick, the path and the stop test exactly as they are. Remove the per-step `build_profile`/`build_goal`/`build_intent`/`build_result` calls (`:212-258`) from inside the step except what the loop still needs. Build the profile once before the loop. Keep the FIRST leg's goal and intent. After the loop, call `build_result` ONCE with the origin, all `stepped` cells and the final reason. Store it as `var last_result: Dictionary` on the service and return it through a new getter. `advance_turn` keeps its `String` return. |
| New functions | `func get_last_result() -> Dictionary` on `StageExploreTurnService`. No other new function. |
| Stop reason in S1a | Unchanged vocabulary: `capacity_spent`, `interrupted`, `reached_destination`, `no_route`. Stage kinds come in S3. |
| Config keys | none |
| Tests | Suite `traversal`: `traversal/one_result_per_advance_validates` (the stored result passes `MovementResult.validate`; `actual_traversed_cells` equals `last_traveled_path`; for a frontier chain too); `traversal/no_route_result_kept`; `traversal/advance_state_identical` (compare `explore_map` after an Advance on three fixtures against the pre-change values captured by the test). |
| Fingerprints that move | **None expected.** The change must be state-neutral. A moved value here is a defect. |
| Tier | sonnet. |
| Risk | Medium-low. The escape pair (`turn_count` at `:170`) and the reveal sweep (`:309`) must keep their order. |
| Rollback | Revert the commit. |
| LESSONS #35 grep | `build_result` is called by 5 test sites (`StagePartyMovementTests.gd:399,430,1021,1265,1280`). The adapter signature does not change. |

### S1b. Exposure map live (Directive baseline tolerance)

Status: BUILT 2026-10-12, not committed, not verified by qa-verifier. Filters traversal, movement, seam, explore, snapshot_fingerprint run; only the known red failed. No recorded value moved. Tests live in group `movement/stage_party/exposure_*` and `traversal/exposure_two_route_board_scout_vs_seek`.

| Item | Plan |
|---|---|
| Files | new `core/movement/StageExposureMap.gd`; `core/realms/StageExploreTurnService.gd` (`:214` call); `core/realms/ActiveStageService.gd` (none); `data` read only |
| New functions | `static func build(explore_map: Dictionary, category_map: Dictionary, exposure_cfg: Dictionary) -> Dictionary` (cell key to exposure 0..1; sources: known hostile, revealed, unresolved, not passed; plus `known_hazards` read, empty today; bridges NOT counted, D-31). `static func to_terrain_costs(exposure: Dictionary, tolerance: float, price_scale: int) -> Dictionary` (cost = `1 + roundi(exposure * (1 - tolerance) * price_scale)`; integers >= 1, omit cells with cost 1). `static func detour_within_slack(priced_len: int, plain_len: int, slack_config: Dictionary) -> bool` (rejects a priced route longer than the slack envelope; the loop then uses the plain route). Const `HOSTILE_CATEGORY := "combat"` (vocabulary token, not a Directive id). |
| Wiring | In the step loop: `terrain_costs = StageExposureMap.to_terrain_costs(map, directive.exposure_tolerance, price_scale)`; second `shortest_path` without costs is run only when `terrain_costs` is non-empty. In S1b the tolerance is the Directive's authored value (0.3 / 0.8), revived by D-05. The party bend comes in S2b. |
| Config keys | `stages.party_stance.exposure.hostile_radius` (2), `.hostile_peak` (1.0), `.price_scale` (4); `directives.<id>.exposure_tolerance`; `situation_category` map (`ConfigService.get_situation_category_cfg`); movement slack. `pause_trigger` is read in S3. |
| Tests | Suite `movement`: `movement/exposure_empty_map_plain_route` (N6: no hostile known, route equals the plain shortest path); `movement/exposure_hidden_never_counts` (a hidden hostile changes nothing; N5 part); `movement/exposure_scout_detours_seek_direct`; `movement/exposure_never_a_wall` (target stays reachable; priced route never longer than the slack envelope); `movement/exposure_costs_are_int_ge_1`. Suite `traversal`: `traversal/exposure_two_route_board_scout_vs_seek`. |
| Fingerprints that move | Route cells on boards with a revealed, unresolved, unpassed combat situation near the path. Candidates: `traversal` and `seam` tests that walk past a combat situation. `snapshot_fingerprint/stage_explore` does NOT move (no Advance). Combat hashes do not move. |
| Tier | sonnet builds. Moved values: `opus` attributes (design 11 rule 2). |
| Risk | Medium. A priced route can change which cell the party enters first and so what the fog lift reveals. |
| Rollback | Revert the commit. The loop falls back to `{}` costs. |
| LESSONS #35 grep | `MovementPathService.shortest_path` signature unchanged. |

### S1c. Objective joins the weighted pool (D-28)

Status: BUILT 2026-10-12, not committed, not attributed, not verified by qa-verifier. `find_explore_target` merges Tier 1 and Tier 2 into one pool. `_target_weight` reads `weights["objective"]` for `is_objective` situations. Moved by this slice: `traversal/exposure_two_route_board_scout_vs_seek` only (waits for opus attribution; no expectation edited). New tests: `traversal/pool_o1_scout_find_first`, `pool_o2_seek_objective_first`, `pool_o3_seek_close_find_then_objective`, `pool_only_objective_revealed`; `movement/stage_party/select_target_objective_weight`, `select_target_missing_objective_key_neutral`. Not built: `pool_objective_never_starved`, `pool_tier4_unchanged` (O3 covers the reach; Tier 4 code is unchanged).

| Item | Plan |
|---|---|
| Files | `core/realms/ActiveStageService.gd` (`find_explore_target`, merge Tier 1 and Tier 2 into one pool); `core/movement/StagePartyMovementAdapter.gd` (`_target_weight`, header comment) |
| Change | Pool = revealed, unresolved, unpassed situations, objective or not. Weights = `directive.target_preference`. `_target_weight` returns `weights["objective"]` for `is_objective` situations. The returned tier is `TIER_OBJECTIVE` if the pick is an objective, else `TIER_WEIGHTED`. Tier 3 and Tier 4 stay as they are. Tier 4 still passes `{}` weights. |
| New functions | none. `_target_weight(situation: Dictionary, weights: Dictionary, category_map: Dictionary) -> float` gains an `is_objective` branch. Missing `objective` key falls back to `DEFAULT_TARGET_WEIGHT` (neutral, so a Directive with no `objective` weight acts as today). |
| Config keys | `directives.<id>.target_preference.objective` (1.2 / 1.6, already authored). |
| Tests | Suite `traversal`: `traversal/pool_o1_scout_find_first`, `pool_o2_seek_objective_first`, `pool_o3_seek_close_find_then_objective`, `pool_objective_never_starved` (finds are finite, objective is reached); `pool_only_objective_revealed` (one candidate, as today); `pool_tier4_unchanged`. Suite `movement`: `movement/select_target_objective_weight`, `movement/select_target_missing_objective_key_neutral`. |
| Fingerprints that move | The largest set. Expected: tests that fix a destination with a revealed objective and a find on one board. Named by the design: `tests/StagePartyMovementTests.gd`, `tests/TraversalModelTests.gd` (`p5_tier1_hard_stops_on_arrival`, `scout_vs_seek_diverge`, `pass_fix_*`), `Stage004SeamTests.gd` (`seam`). `snapshot_fingerprint/stage_explore` does not move. This slice is the sole cause of every move in its run. |
| Tier | sonnet builds. `opus` attributes every moved value. |
| Risk | High for tests, medium for the game. Stage-wide behaviour change. |
| Rollback | Revert the commit. Tier 1 returns. |
| LESSONS #35 grep | `select_objective_target` has about 25 test call sites with the 4 or 5 argument form. The signature stays. No duck-typed fake. |

### S2a. Shared Judgment input reader (combat must not move)

**Status:** code and test written (uncommitted). `expr` 39/39, `behavior` 18/18, `combat_roundtrip` 47/47 pass. Combat hash suites (`combat_baseline`, `fingerprint_*`) await the RUN REQUEST gate.

| Item | Plan |
|---|---|
| Files | `core/actors/MaturityExpressionService.gd` (new static); `core/actors/ActorStateMachine.gd` (`:166-207` calls it) |
| New functions | `static func build_ctx_inputs(actor: Dictionary, bonds: Array, living_party_ids: Dictionary, cfg_data: Dictionary, bond_thresholds: Dictionary, active_vow: Dictionary, instability: float) -> Dictionary`. It holds the family lookup, the bond filter (actor, living members), `level_thresholds` and `fear_base_max` exactly as `ActorStateMachine.gd:166-207`. |
| Config keys | none new |
| Tests | Suite `expr`: `expr/build_ctx_inputs_matches_actor_state_machine` (same `judgment` through both paths on three Echoes with and without bonds). Suite `fingerprint` (combat rounds): no change expected. |
| Fingerprints that move | **None.** `COMBAT_ROUNDS_HASH` and the six other round hashes in `FlowFingerprintTests.gd` must stay. A moved combat hash is a defect (design 11). |
| Tier | **opus.** It edits the combat Judgment source. A wrong move shifts every combat hash silently. |
| Risk | Medium. Behaviour-neutral by intent; proof is the unchanged combat hashes and the parity test. |
| Rollback | Revert the commit. |
| LESSONS #35 grep | `derive_expression` signature is unchanged. Grep `tests/` for callers that build `ctx_inputs` by hand (`MaturityExpressionTests.gd`): they keep working because `derive_expression` is untouched. |

### S2b. Party stance: dials, readiness, capacity, commitment

**Status:** DONE (D-50). Scout commitment_fraction 0.6; 5 `traversal` tests re-recorded to commitment depth (Scout 2, Seek 5). Uncommitted.

| Item | Plan |
|---|---|
| Files | new `core/movement/StagePartyStance.gd` (pure static); `core/realms/StageExploreTurnService.gd` (build one stance at the start of the Advance; effective steps; commitment depth; tolerance into S1b); `core/movement/StagePartyMovementAdapter.gd` (`build_profile` gains an optional `effective_steps` argument) |
| New functions | `static func read_echo(actor: Dictionary, bonds: Array, living_ids: Dictionary, cfg_data: Dictionary) -> Dictionary` (per-Echo lean inputs: `family`, `width` from S2a, `fear`, `morale`, `best_style`). `static func build(echoes: Array, directive: Dictionary, stance_cfg: Dictionary) -> Dictionary` returning `{dials: {exposure_tolerance, stop_willingness, commitment_fraction, escape_bonus}, effective_steps: int, commitment_depth: int, leans: {echo_id: {dial: float}}, candidates: Array}`. `static func echo_lean(echo: Dictionary, dial: String, stance_cfg: Dictionary) -> float` (coefficient x bound x strength; strength = `floor + (1 - floor) * width` for Calling and identity; 1.0 for fear and morale; fear ramp `fear_start` to `fear_full`; morale signed around `morale_neutral`). `static func readiness_steps_lost(echoes: Array, stance_cfg: Dictionary) -> int` (party mean fear and mean morale bands; lower only; cap `bounds.readiness_steps`). `static func best_style(actor: Dictionary, cfg_data: Dictionary) -> String` (loops `MovementStyleService.eligible_styles("reposition")`, scores with `style_alignment_score(route_style, "reposition", vector_scores, "", {}, 0.0, "", 0.0, 0.0, cfg)` (vector term only, ASSUMED A2), picks the highest, ties by `STYLES` order). Aggregation: `dial = clamp(baseline + sum(lean) / party_size, baseline - bound, baseline + bound)`, with baseline from the Directive entry. |
| Echo source | `SanctumService.get_party_actors_static(flow_ctx.save_data)` (S2a reader for Judgment); bonds `sanctum.bonds`. Party order is irrelevant: sort Echoes by id string before summing. |
| Config keys | `stages.party_stance.bounds.*`, `.lean_strength.dispositional_floor`, `.leans.*`, `.state_ramps.*`, `.identity.*`, `.readiness.*`, `.directive_profile.<id>.commitment_fraction`; `directives.<id>.step_budget`, `.exposure_tolerance`, `.escape_bonus`. |
| Rounding | `commitment_depth = clampi(roundi(effective_steps * commitment_fraction), 1, effective_steps)`; `effective_steps = clampi(step_budget - lost, 1, 6)`. `roundi` is deterministic. ASSUMED A3. |
| Tests | Suite `movement`: ordering invariants per dial for both Directives (Seek >= Scout on tolerance, steps, commitment; Scout >= Seek on stop willingness and escape), from config bounds; `party_order_shuffle_identical` (N4 part); `one_stance_per_advance`; `standing_floor_leans_at_standing_1` (D-08); `judgment_never_adds_steps`; `readiness_lower_only`; `all_shaken_party_still_moves_or_names_stop` (both Directives); `bond_rule` (same Echoes with and without bonds change `width`). Suite `traversal`: S1, S2, S3, K1, K3, K4, P1, P2 contrasts built from real Echo dicts through `get_party_actors_static` with real bonds; `commitment_never_exceeds_effective_steps`. A synthetic third Directive passes (D-14). |
| Fingerprints that move | Steps per Advance (effective steps, commitment depth), routes under bent tolerance, `traversal/scout_vs_seek_diverge`-style tests. `snapshot_fingerprint/stage_explore` does not move (nothing new in the snapshot yet). |
| Tier | sonnet. The math is bounded and tested against config. `opus` attributes moved values. |
| Risk | Medium-high. Commitment depth shortens a Scout Advance from 3 to about 2 steps. This changes pace on every recorded stage walk. |
| Rollback | Revert the commit. S1c stays valid. |
| LESSONS #35 grep | `build_profile(directive)` gains an optional second parameter `effective_steps: int = -1`. 12 test sites pass one argument: still valid. No fake. |

### S2c. Category-weight bend. Frontier `route_character` deferred (D-51).

**Status:** DONE for the bend (uncommitted). Frontier `route_character` NOT built: no config keys or definition exist (see report OPEN).

| Item | Plan |
|---|---|
| Files | `core/movement/StagePartyMovementAdapter.gd` (`select_objective_target`, `select_frontier`); `core/realms/ActiveStageService.gd` (pass the bend) |
| Change | `select_objective_target` gains an optional trailing `bend: Dictionary = {}` (category to delta, already clamped to `bounds.category_weight`). Rank becomes `[-authored_weight, -bend_delta, distance, id, col, row]`. The bend can only break a tie of the authored weight (D-44, K2). Frontier `route_character` key deferred (D-51): `select_frontier` gets no new argument in this slice. Heading continuation stays as existing shared code. |
| New functions | `static func category_bend(echoes_leans: Dictionary, stance_cfg: Dictionary) -> Dictionary` in `StagePartyStance`. |
| Config keys | `stages.party_stance.leans.category_weight.*`, `bounds.category_weight`. |
| Tests | Suite `movement`: `movement/bend_never_inverts_ranking`; `movement/bend_breaks_tie_only`; `movement/frontier_tie_break_salt_unchanged`; `movement/select_signature_backward_compatible`. Suite `traversal`: K2 (tie case, Seek, reward 0.9 vs intel 0.9, Sight picks intel, Edge picks nearest), O1 to O3 re-run. |
| Fingerprints that move | Small. Only boards with a tie. The frontier hash order is unchanged for an empty `route_character`. |
| Tier | sonnet. |
| Risk | Low-medium. The existing total-order test (`StagePartyMovementTests.gd:1390-1441`) must stay green. |
| Rollback | Revert the commit. |
| LESSONS #35 grep | New parameters are optional and trailing. The 25 call sites for `select_objective_target` and the `select_frontier` sites compile unchanged. |

### S2d. Return-safety bend

Status: BUILT 2026-10-12, not committed, not verified by qa-verifier. Filters seam, venture_char, traversal, movement, explore, snapshot_fingerprint, pending, directive run; only the known red failed. No recorded value moved. Tests `seam/escape_draw_path_unchanged`, `escape_never_certain_never_impossible`, `escape_scout_ge_seek`.

| Item | Plan |
|---|---|
| Files | `core/runtime/controllers/VentureController.gd` (`:337`) |
| Change | The threshold reads the bent `escape_bonus` from a fresh `StagePartyStance.build` over the current party. The draw path `stage.escape.<stage>.<turn_count>` and the `turn_count` order do not change. `intel_retention` and `intel_retention_bonus` stay Directive-owned (`:374`). Bend is bounded by `bounds.escape_bonus` (6). |
| New functions | `static func escape_bonus(echoes: Array, directive: Dictionary, stance_cfg: Dictionary) -> int` in `StagePartyStance`. |
| Config keys | `stages.party_stance.leans.escape_bonus`, `bounds.escape_bonus`. |
| Tests | Suite `seam`: `seam/escape_draw_path_unchanged` (same key string, same RNG sequence); `seam/escape_never_certain_never_impossible`; `seam/escape_scout_ge_seek`. Check existing tests that fix an escape result (grep `stage.escape`). |
| Fingerprints that move | Escape outcomes in tests that use a party with non-zero leans. |
| Tier | sonnet. |
| Risk | Low. One integer. |
| Rollback | Revert the commit. |
| LESSONS #35 grep | No signature change. |

### S2e. Counterfactual naming

Status: BUILT 2026-10-13, not committed, not verified by qa-verifier. Not wired into `advance_turn` (S3 wires it). Filters traversal, movement, seam, explore, objective, snapshot_fingerprint, directive, venture_char run; only the known red failed. No recorded value moved. Cost smoke on real stages (5-Echo party): 63 to 122 ms mean per naming call, 334 ms max, about 6 dry runs.

| Item | Plan |
|---|---|
| Files | new `core/realms/StageCounterfactualService.gd` (RefCounted, same constructor family as the siblings: `(flow_ctx, config_service, logger)`); `core/realms/ActiveStageService.gd` (optional shared `region_costs` argument on `find_explore_target`) |
| New functions | `func plan_first_leg(explore_map: Dictionary, directive: Dictionary, stance: Dictionary, walkable: Dictionary, explored: Dictionary, stage: Dictionary, region: Dictionary) -> Dictionary` (`{target_id, path, effective_steps, commitment_depth, stop_kind}`; no writes; works on a deep copy). `func plans_differ(a: Dictionary, b: Dictionary) -> bool` (materially changes, design 4 rule 8). `func name_deciders(real_plan: Dictionary, echoes: Array, ctx: Dictionary) -> Dictionary` returning `{contributor_ids: Array, decisive_contributor_id: String, reason_class: String, cause: String}`. Counterfactual removes the Echo AND the bond edges that Echo supplies to the others (D-26). Reason class by zeroing one lean class at a time, in config order. Cause order when no Echo is named: `terrain`, `objective`, `situation`, `directive`, `party` (N1 to N3). |
| `find_explore_target` change | `func find_explore_target(explore_map, directive, walkable, explored_cells, stage, region_costs: Dictionary = {})`. When given, both Tier 2 and Tier 3 reuse it. Default `{}` = compute as today. |
| Config keys | `stages.party_stance.counterfactual.*` (cap = party size + 1 x 4 classes; replan cap 3 x effective steps). |
| Tests | Suite `traversal`: N1 to N7; S3 names the frightened Echo with class `fear`; P1 names an Echo whose removal changes the plan; `counterfactual_cap_respected` (<= 9 dry runs, count asserted); `counterfactual_no_state_written` (deep-compare `explore_map` and save before and after); `name_matches_removal` (N7: for each named Echo, removal changes the plan); `tie_pin_documented` (two identical Echoes: lowest id, no crash). Suite `movement`: `find_explore_target_region_arg_same_result`. |
| Fingerprints that move | None (adds data, writes nothing). |
| Tier | **opus.** Determinism (tie-breaks, ordering), cost, and a wrong-reason risk that the fingerprint cannot see. |
| Risk | High for correctness (a true path with a false reason). Cost is bounded by the first-plan-only design. |
| Rollback | Revert the commit. The journey entry (S3) then shows cause `party` or `directive` only. |
| LESSONS #35 grep | `find_explore_target` gets an optional trailing parameter. Test files call it only in comments. |

### S3. Stop kinds, reveal peek, pause cap, snapshot fields

**Status:** BUILT 2026-10-13, not committed, not verified by qa-verifier. Two recorded values moved and wait for opus attribution: `traversal/advance_state_identical` (gen100_scout, gen100_seek) and `snapshot_fingerprint/stage_explore`. Neither is re-recorded.

| Item | Plan |
|---|---|
| Files | new `core/movement/StageStopPolicy.gd`; `core/realms/ActiveStageService.gd` (`lift_fog_at_cell` returns the keys it added: `-> Array`); `core/realms/StageExploreTurnService.gd` (stop test in the loop; writes `explore_map["last_stop"]` and `["travel_why"]`); `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd` (new keys); `core/config/ConfigService.gd` (none new) |
| New functions | `static func classify_reveals(explore_map: Dictionary, new_cell_keys: Array, category_map: Dictionary, profile: Dictionary, stop_cfg: Dictionary, width: float) -> Dictionary` (read-only peek; returns `{kind: "", cell: {}}`; `spotted_ahead` for an objective or a combat-category situation; `paused_to_read` for other finds only when `reveal_stop_kinds` lists it; noise filter by `noise_width_min` and `noise_weight_max`). `static func exposure_pause(exposure: float, tolerance: float, stop_willingness: float, pause_trigger: float) -> bool`. `static func kind_for(reason: String, revealed_kind: String) -> String` (the mapping in feasibility 3). `static func sanitise_why(why: Dictionary) -> Dictionary` (drops ids and numbers; allowed slots only). |
| Loop change | After each step: if `classify_reveals` returns a kind, set the stop and end the walk (ASSUMED A1: a pause ends the Advance). `commitment_spent` ends the walk when `steps == commitment_depth`. The post-loop sweep at `:309` is untouched. |
| Snapshot keys (all new keys land here) | `stop` `{kind, col, row, echo_id}` (the `echo_id` is internal, never displayed; ASSUMED A4); `travel_why` `{cause, purpose_family, route_character, stop_kind, named_echo_name, echo_reason_class}`; `effective_steps: int`; `presentation: Dictionary` (copy of `stages.presentation`, for the UI timing path J4). `step_budget` already exists (`:471`). |
| Config keys | `stages.party_stance.stop.*`, `.exposure.pause_trigger`, `.directive_profile.<id>.reveal_stop_kinds`, `.stop_willingness`; `stages.presentation.*`. |
| D-48 (A2) | Terrain cause: when the exposure price makes the stage refuse a detour, `travel_why.cause` gets a terrain value (name set here, wording is Jeff's) so the why never shows a false Directive reason. S5 saves it. |
| Pause cap | `stop.pause_cap_per_advance` is read and asserted, but under A1 it cannot bind (B1). |
| Tests | Suite `seam`: `seam/stop_kind_arrived`, `capacity_spent`, `interrupted`, `spotted_ahead`, `paused_to_read`, `no_route`; `seam/stop_kinds_not_in_shared_contract` (`STOP_REASONS` unchanged); `seam/return_safety_draw_unchanged`. Suite `explore` and `explore_p5`: `stop` and `travel_why` fields present and typed; N7; sanitiser (no id, no number in any `travel_why` slot); Scout stops for a new find, Seek passes through (D-29); noise filter drops a low-weight find at high width but never an objective; `peek_does_not_reveal` (a find revealed by the sweep, not before); `reveal_sweep_order_unchanged` (same `intel_quality` roll per situation as before). Suite `traversal`: S2, `all_shaken_party_progress`. |
| Fingerprints that move | **`snapshot_fingerprint/stage_explore` (`STAGE_EXPLORE_FINGERPRINT_HASH`)** because `data` gains 4 keys. This is the only slice that moves it. Plus stop-dependent Advance expectations in `traversal`/`seam`/`explore_p5` (Scout now stops at new finds). Combat hashes must not move. |
| Tier | sonnet builds. `opus` attributes the moved values. |
| Risk | Medium-high. New stop points change Advance counts on recorded walks. |
| Rollback | Revert the commit. The fingerprint returns to its S2e value. |
| LESSONS #35 grep | `lift_fog_at_cell` return type changes `void` to `Array`. `grep` of `tests/` finds no caller. `StageExploreTurnService.gd:190,251` ignore the result today. |

### S3b. D-52 fixes to S3 (F1, F2, F5, F6)

**Status:** BUILT 2026-10-13, not committed, not verified by qa-verifier. F1 moved `traversal/advance_state_identical` gen100_scout Advances 2 and 3; F6 moved `STAGE_EXPLORE_FINGERPRINT_HASH`. F2 and F5 moved no recorded value. Each re-record has a `D-52 F<n>` comment. Filters traversal, seam, explore, snapshot_fingerprint, movement, objective, directive, venture_char run; only the known red failed.

### S4a. Contact literals to config (same values, no behaviour change)

**Status:** BUILT 2026-10-13, not committed, not verified by qa-verifier. No recorded value moved. Tests: suite `contact_cfg` (6 tests, `tests/ContactConfigLiteralTests.gd`).

| Item | Plan |
|---|---|
| Files | `core/realms/ConversationService.gd` (`:287` reads `contact.emotional_fit_modifiers.high_fear_npc_min`; the reactive `:483` reads `contact.bid.reactive_fear_min`); `core/realms/ContactConversationService.gd` (`:74,:76` read `contact.turn_count_modifiers`); `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd` (`:187-201`: replace the second bid rule with the output of the one shared bid function from S4b, or in S4a read the same key) |
| New functions | `ConversationService.compute_bids` gains an optional trailing `bid_cfg: Dictionary = {}`; the turn-score literals `0.2` (`:292`) and `0.1` (`:299`) and the morale limit `20` (`:297`) move to `contact.emotional_fit_modifiers` (`high_fear_broken_charge_bonus`, `low_morale_broken_bonus`, `low_morale_npc_max`), same values (D-47 J6). The three "3" voice literals move to `contact.max_voices_per_turn` (D-47 J5). |
| Config keys | `contact.bid.reactive_fear_min` (60, `>=`), `contact.emotional_fit_modifiers.high_fear_npc_min` (60, `>=`), `contact.turn_count_modifiers.npc_fear_above` (60, `>`), `.npc_morale_below` (30, `<`). A missing key falls back to the old value, so old fixtures pass. |
| Tests | Suite `conversation_repair`: `conversation_repair/reactive_threshold_from_config` (both copies agree; change the key in a fixture and both move); `conversation_repair/turn_count_modifiers_from_config`; `conversation_repair/literals_same_result` (default config gives the old result on 6 Echoes). |
| Fingerprints that move | None. |
| Tier | sonnet. |
| Risk | Low. Compare operators are kept (`>=` and `>`). |
| Rollback | Revert the commit. |
| LESSONS #35 grep | `compute_bids` has no test caller. Three production callers pass three arguments: still valid. |

### S4b. Bid scaling by Judgment and fear, one shared bid function

**Status:** BUILT 2026-10-13, not committed, not verified by qa-verifier. No recorded value moved. Tests: 6 in `tests/ContactBidScalingTests.gd` (names `conversation_repair/bid_*`).

| Item | Plan |
|---|---|
| Files | `core/realms/ConversationService.gd`; `core/runtime/controllers/ContactController.gd` (`:201`, `:424`); `core/realms/ContactConversationService.gd` (`:93`); `StageExploreSnapshotBuilder.gd` (`:187-201`) |
| Change | New order per Echo: fear (reactive) before suppression when the scaled suppression is weak; then suppression with strength; then alignment; then boost with strength. `strength = 1 - judgment_weight * width - fear_weight * fear / 100`; the effect applies only if `strength >= apply_threshold`. `width` from S2a. The snapshot builder calls the same function, so the card equals the simulation (F5). |
| New functions | `static func compute_bids(party_echoes: Array, contact: Dictionary, dir_fx: Dictionary, bid_cfg: Dictionary = {}, width_by_id: Dictionary = {}) -> Dictionary` (width missing = 0.0, neutral); `static func bid_strength(width: float, fear: int, judgment_weight: float, fear_weight: float) -> float`; `static func party_widths(save_data: Dictionary, cfg_data: Dictionary) -> Dictionary` (id to width, via S2a). |
| Config keys | `contact.bid.suppression.*`, `contact.bid.boost.*`, `contact.bid.reactive_fear_min`. |
| Tests | Suite `conversation_repair`: `bid_suppression_weakens_with_judgment`, `bid_suppression_weakens_with_fear`, `bid_boost_refused_when_frightened`, `bid_seek_unchanged` (no lists), `bid_s4_standing_contrast` (width 0.3 silent, width 0.6 bids; real widths computed from real Echoes with bonds, and the same Echo without bonds shows the Standing effect), `bid_snapshot_matches_simulation`. |
| Fingerprints that move | Conversation tests that fix a `bid_type` or a card badge; `ContactModelTests` (`contact`) cases that depend on suppression. Not stage fingerprints (the stage entry has no contact). |
| Tier | sonnet. The numbers are authored. |
| Risk | Medium. Behaviour change in contacts. Reactive-before-suppression changes who may bid when frightened (design 6a, row 11). |
| Rollback | Revert the commit. |
| LESSONS #35 grep | New parameters are optional and trailing. No duck-typed fake of `compute_bids` exists. |

### S4c. Resonance bonus and rename (one change, D-24)

| Item | Plan |
|---|---|
| Files | `core/directives/DirectiveService.gd` (`:54` key list); `data/balance.json` (`:71`, edited by `mid-game-designer` or by me only with explicit approval; the plan lists it so the rename is ONE change); `core/realms/ConversationService.gd` (`:162`, `:108`); `CONVENTIONS.md:938` |
| Change | Rename `witness_resonance_bonus` to `conversation_resonance_bonus` in the guard key list, the data entry, the doc and any test. Add a trailing optional `resonance_bonus: float = 0.0` to `compute_turn_score_from_virtue` and `generate_responses`; add it to the sum BEFORE the clamp (D-30). The caller reads the value from the active Directive's `contact_effects`. |
| New functions | none. `compute_turn_score_from_virtue(..., contact_role: String = "", resonance_bonus: float = 0.0) -> float`. |
| Config keys | `directives.<seek>.contact_effects.conversation_resonance_bonus` (0.1). |
| Tests | Suite `directive_cfg`: old key rejected, new key accepted; `directive_char` scan unchanged. Suite `conversation_repair`: `resonance_bonus_before_clamp_range_0_to_1_2`, `resonance_bonus_applies_to_every_echo_equally`, `resonance_bonus_zero_for_scout`. |
| Fingerprints that move | Turn scores in contact tests under Seek; any fixture that carries the old key name fails the load (D-15). |
| Tier | sonnet. |
| Risk | Medium. A config key rename aborts the load if the data and the guard list disagree. They change in the same commit. |
| Rollback | Revert the commit (data and guard together). |
| LESSONS #35 grep | New parameters optional and trailing. |

### S5. Saved journey entry and `stop` (old-save repair)

| Item | Plan |
|---|---|
| Files | `core/state/flow/states/venture/FlowStageExploreState.gd` (`_reset_session_state` key list `:96-123`); `core/save/SaveService.gd` (`:1306-1313` region: default `last_stop` `{}` and `travel_why` `{}`); `core/realms/StageExploreModel.gd` (`make_default` optional) |
| Change | Two additive `explore_map` keys: `last_stop` and `travel_why`. `_reset_session_state` carries both ONLY when `locked` is true (a re-entry, same rule as `party_pos`). On the first entry of a stage they start empty. The next Advance replaces them (`advance_turn` writes them in S3). A load of an old save repairs a missing key to `{}`: no glyph, no chip, no error. No key is removed or renamed. `flow_ctx.request_save` stays one flush per dispatch. |
| D-48 (A1, A2) | Same opus save pass also saves (a) the terrain cause field and (b) for the later C1 rule, the plain route length at leg start (one number per leg). Both additive, safe defaults on old saves. C1 itself is not built here (D-48 A1: per-step rule stays). |
| New functions | `static func carry_journey(old_map: Dictionary, locked: bool) -> Dictionary` in `FlowStageExploreState` (returns `{last_stop, travel_why}` or empties). |
| Tests | Save suite (`save_integrity`): `save_integrity/journey_round_trip` (save, load, same entry, same `stop`); `save_integrity/old_save_loads_empty` (a save with neither key); `save_integrity/no_field_removed_or_renamed` (key list diff); `save_integrity/journey_cleared_on_first_entry`; `save_integrity/journey_kept_on_reentry`. Suite `explore`: sanitiser on the saved entry (no id, no number). |
| Fingerprints that move | None. `stage_explore` already moved in S3 (empty keys on a fresh save were included there). |
| Tier | **opus** (save schema, design 8a requires an opus pass before merge). |
| Risk | Medium. `_reset_session_state` runs on every entry, so a missed carry loses the glyph after combat. |
| Rollback | Revert the commit. Saved extra keys are ignored by older code. |
| LESSONS #35 grep | No signature change. |

### Docs and commit step (every story ends with it)

After S5: update `CONVENTIONS.md:938` (key name), `ANSWERS.md` #82 (dated amendment: bonds enter stage through Judgment, D-26), `docs/movement-model.md` 11.9 and 11.12 (dated notes, F9 and D-12), `docs/MEMORY.md` rows for the new files, stale comments (`StagePartyMovementAdapter.gd:2-4` "DORMANT"; `balance.json:1728,1735` "STILL DORMANT"; `balance.json:3210` "move later"), and the `_REGISTRY` fallback text in `DirectiveService.gd:61,81` (still the old picker text; `numbers.md` section 2). Commit only when Jeff asks.

## 4. RUN REQUESTs the main chat will need

Each request follows root `AGENTS.md` (command, timeout, alarm, duration, edited files and `trap`, restore check, output to read). I give the shape. The builder writes the exact text when it hands over.

| # | When | Command (shape) | Edits | Read back |
|---|---|---|---|---|
| R1 | After S1a | Filtered: `-- tests traversal`, `-- tests movement`, `-- tests seam` (each under 200 s alarm). Short. The main chat may run these in the foreground. | none | `Tests:` line per filter, raw failing names. Expect zero failures. |
| R2 | After S1b | Same three filters plus `-- tests explore`. | none | Failing names = the moved set. Send the raw list to `opus` for attribution. |
| R3 | After S1c | Same four filters plus `-- tests objective` and `-- tests snapshot_fingerprint`. | none | Moved set. `snapshot_fingerprint/stage_explore` must still pass. Attribution by `opus`. |
| R4 | After S2a | Combat gate: `-- tests fingerprint`, `-- tests expr`, `-- tests behavior`. These replay combat rounds and may exceed 2 minutes: background with alarm 900. | none | All seven combat round hashes unchanged. |
| R5 | After S2b to S2e | Filters `traversal`, `movement`, `seam`, `explore`, `explore_p5`, `directive`, `identity`. Per slice. | none | Moved set per slice. |
| R6 | After S3, **re-record 1** | `-- tests snapshot_fingerprint` fails once with the new hash. Read the actual hash from the failure text. Builder edits `STAGE_EXPLORE_FINGERPRINT_HASH` in `tests/FlowSnapshotFingerprintTests.gd:326` after `opus` confirms the only payload delta is the four new keys (dump the payload diff). | the test constant | `Tests:` line; `cmp` of the test file against a saved copy before the edit; diff shows one line. |
| R7 | After S4a to S4c | Filters `conversation`, `conversation_repair`, `contact`, `directive_cfg`, `directive_char`. | none | Moved set per slice (S4a must be zero). |
| R8 | After S5 | Filters `save_integrity`, `bridge`, `explore`. | none | Round trip and old-save cases pass. |
| R9 | Phase gate | **ONE full serial run** (D-20, LESSONS #34): `/usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests` with Bash `timeout: 3700000`, in the background. About 53 minutes at phase A. No sharded run on top. If exit is 142 (alarm), raise the alarm and run the same command again. | none (fixtures live in `/tmp/echoes-vnext-tests/`; clear stale `.bak1` first) | The `Tests:` line, exit code, raw failing names. Known red: `movement_arbiter/avoid_overcommit_stays_proportionate`. |
| R10 | After R9 | Pause re-measure (D-45): the `game-feel-developer` probe again, now with party bends. Long run: background. | none, or restore by `trap` | Pauses per Advance and why frequency per shipped board, both Directives. |

No agent runs R4, R9 or R10. The main chat runs them and checks that every edited file is back to its original.

## 5. Items that need Jeff's decision (short)

| # | Item | Default if no answer |
|---|---|---|
| J1 | Counterfactual is first-plan-only, not a full re-walk (F2). A frontier chain after the first leg is not compared. | Proceed with first-plan-only. |
| J2 | Does a pause end the Advance? (BLOCKED B1) If yes, the cap of 2 never binds. If no, a pause is a beat inside a longer walk and the loop needs a different design. | Pause ends the Advance (A1). |
| J3 | Fix the lowest-id pin? (feasibility 5) Option: name index `turn_count % tied_count`. | Ship the lowest id as designed. |
| J4 | Timing path to the UI: copy of `stages.presentation` in the snapshot (`data.presentation`). | Use the snapshot copy; no UI file reads config. |
| J5 | New config key `data.contact.max_voices_per_turn` = 3 for the three "3" literals and the snapshot `>= 5` read of `party_max_size` (feasibility 8). `mid-game-designer` authors it. | DECIDED (D-47): move them to config, same values. |
| J6 | The turn-score literals `0.2` (`ConversationService.gd:292`) and `0.1` (`:299`) are outside design 10.1. Move to config? | DECIDED (D-47): move to config, same values (`:292`, `:297`, `:299`). |
| J7 | Scope: share the reachable region inside `find_explore_target` (S2e) overlaps V2-INFRA-010. Keep it in B+C as a minimal optional argument, or wait for INFRA-010? | Minimal optional argument in S2e. |

Not Jeff's: F4 (`numbers.md` section 7 still says 3; data says 2) is a doc fix for `mid-game-designer`.

## OPEN — questions and assumptions

ASSUMED: A1. A `paused_to_read` or `spotted_ahead` stop ends the Advance. | WHY: D-29 says "stops"; movement model 11.7 says such a find "stops movement and returns control". | WRONG IF: Jeff wants the party to pause, read and walk on inside one Advance. Then S3 needs a second loop mode and the cap of 2 becomes real.
ASSUMED: A2. The stage identity lean calls `MovementStyleService.style_alignment_score` with Calling family "", fear 0, morale tier "", no bond pressure, no vow, no traits, so only the vector term counts. | WHY: the stance already leans on Calling family, fear and morale. The full score counts them twice (design 2, rule 1; F6). The vector term carries most of the ~50 raw units, so `alignment_gain` 0.33 still scales it. | WRONG IF: the designer meant the full score and accepts the double count. Then `alignment_gain` needs re-tuning.
ASSUMED: A3. `commitment_depth = clampi(roundi(effective_steps * commitment_fraction), 1, effective_steps)`. | WHY: the config comment says "rounding is a code choice" and the depth must be at least one step. | WRONG IF: Jeff wants floor or ceil. A tied value (for example 3 x 0.5 = 1.5) rounds to 2 under `roundi`.
ASSUMED: A4. `stop` in the snapshot carries an internal `echo_id` so the shell can place the glyph on the right Echo card. The id is never displayed. | WHY: the design says "which Echo the glyph sits on, taken from the saved named Echo", and the Echo bar is keyed by id. The "no IDs" rule is about player-facing text. | WRONG IF: the UI can match by display name. Then drop `echo_id` and save the name only.
ASSUMED: A5. A Directive with no `directive_profile` entry gets neutral stance behaviour (no bend, no reveal stops, commitment 1.0), and a S0 test fails loudly when a shipped Directive lacks an entry. | WHY: D-44 says a new Directive needs an entry; ANSWERS #81 says no logic change for a new Directive. | WRONG IF: Jeff prefers a load abort for a missing entry (like D-15).
ASSUMED: A6. Hostile means situation category `combat` from `data.stages.situation_category`. The word `combat` becomes a constant in `StageExposureMap`. | WHY: design 3b says "combat type"; `target_preference.combat` already uses the same token. | WRONG IF: hostile must also include other types (for example an ambush ritual).
ASSUMED: A7. Under S5 the journey entry is carried only on re-entry of an already locked stage and starts empty on first entry ("cleared on a new stage entry" read as first entry of that stage). | WHY: `_reset_session_state` runs on every entry, including return from combat, and `locked` already marks a re-entry. | WRONG IF: Jeff wants the entry to clear on every stage entry, or to survive across stages.
BLOCKED: B1. What does `pause_cap_per_advance` bound if a pause ends the Advance? | CHECKED: `design.md` 3a, 12a (D-29), D-45, `numbers.md` section 7, `data/balance.json:3191-3196`, `docs/movement-model.md` 11.7. | NEED: `sr-game-designer` or Jeff states the intended meaning (J2).
BLOCKED: B2. Final exact test counts and the exact list of moved recorded values per slice. | CHECKED: test names in `tests/TraversalModelTests.gd`, `StagePartyMovementTests.gd`, `Stage004SeamTests.gd` (no stop-reason or destination hash is pinned; behaviour is asserted from state). | NEED: the filtered runs R2, R3, R5 (the main chat runs them). I did not run any test.

Skipped (ponytail): no new suite (`party_stance` is a Jeff option; cases go in `movement`); no new files beyond four pure statics and one service; no change to the shared `STOP_REASONS` contract; no refactor of `find_explore_target`'s double region search beyond one optional argument; no UI, scene or data file touched. Not checked: real runtime of the counterfactual (estimated from the INFRA-010 evidence, not measured); whether any `traversal` fixture already puts a combat situation near a path (R2 shows it).
