# V2-ECONOMY-004 step 7.S build: the standoff and the "packs lost" signal (backend)

Rules: D-116 and its addendum, D-109, D-110, D-113 to D-115, D-117. Copy: `phase7-copy-final.md`. Nothing is committed. `ui/` and Notion are untouched.
Written in STE. Tags: READ = from code I opened. TESTED = a test or probe I ran. ASSUMED = see the OPEN block.

## 1. What the code does now

| Event | Old behaviour | New behaviour |
|---|---|---|
| A fight makes no progress for 15 rounds | Sanctum card `forced_retreat`, no turn, nothing marked, path still open | `standoff` card; the party steps back onto the path |
| Turn | none | +1 (`apply_retreat_return` with `standoff`) |
| Ase, withdrawal bonus, vow release | none | none (not called) |
| Packs | untouched | untouched: no row written, no row marked lost or settled (TESTED) |
| The fight | open and offered again at once (objective) or never marked (normal) | `passed` + `retreat_pass_turn` on BOTH kinds; Tier 4 offers it on a later turn only |
| Deaths in the fight | not recorded | recorded by `record_fight_deaths` before the teardown, like a fight that ends |
| Fear | none | the fight's final fear and morale are written to the roster (D-118); first standoff on a fight: each party Echo that refused then loses `standoff_fear_drop` |
| Warning | none | round snapshot `stall_level` 0/1/2 and `stall_froze_name` |
| Prebattle | none | round snapshot `stalled_before` |
| Defeat card | no loss signal | conditional ledger row `packs_lost` |

## 2. Contracts (new or changed)

### Card (producer H2, `VentureResolveSnapshotBuilder.build_standoff_snapshot`)

```
type: flow.resolve
data: { run_type: "standoff", standoff_outcome: "nobody_moved", standoff_count: int, can_go_sanctum: bool,
        cause: "froze"|"blocked"|"unknown", froze_names: [0..2 names], calmed_names: [0..2 names] }
actions: { "cta.continue": { type: "stage.standoff_return", label: "Back to the path" },
           "cta.sanctum":  { type: "stage.standoff_return", label: "To the Sanctum", to_sanctum: true } }  # second standoff on
```
The card has no `surface`, no amount key, no percent, no odds (TESTED: no `ase_awarded`, `ekwan_awarded`, `reward_breakdown`, `%`, `odds`). Labels are the final lines of `phase7-copy-final.md`; the UI may read its own constants instead.
Block `ResolveSnapshotBuilder.add_standoff` writes the six keys. The durable replay (producer G) calls it when the stored card has `standoff_outcome`.

### Action `stage.standoff_return` (owner `VentureController.handle_standoff_return`)

- Works only while the live card has `run_type == "standoff"`. Anything else does nothing.
- Goes to `flow.stage_explore` with a dedicated action, so the vow stage-entry check does not run (same reason as 6.2).
- `to_sanctum: true` counts only when the card has `can_go_sanctum`. It sets the volatile `FlowContext.pending_return_confirm`. The explore snapshot then carries `data.return_confirm_requested: true` (the key exists only when true, so no fingerprint moves). The end of `dispatch()` clears the flag after that snapshot. The escape check and the settle roll stay in `stage.return_home`.
- Dispatch action guard count: 78 to 79 (`flow_transaction/dispatch_action_count_is_79`).

### Round snapshot (`EncounterSnapshotBuilder.build_round_snapshot`, always present)

| Key | Value |
|---|---|
| `stall_level` | 0, 1 or 2 from `no_progress_streak` against `no_progress_round_limit` and the two fractions. No streak and no limit in the snapshot (TESTED: no key contains "streak", "limit" or "no_progress"). |
| `stall_froze_name` | Name of the party Echo that refused most recently in the current quiet run, or "". |
| `stalled_before` | True when the engaged situation (`explore_map.last_situation_id`) has `standoff_count` > 0. |

`stall_level` is derived on every build, so it clears when the streak resets. `stall_froze_name` clears when the streak resets because the stall record clears. The builders stay pure (TESTED: two builds are equal).

### Config (new keys, PROPOSED DEFAULTS, `mid-game-designer` tunes them)

| Key | Default | Meaning |
|---|---|---|
| `data.combat.stalemate.warn_level1_fraction` | 0.5 | Level 1 from streak 8 (limit 15). A value at or below 0 switches the level off. |
| `data.combat.stalemate.warn_level2_fraction` | 0.8 | Level 2 from streak 12. |
| `data.combat.stalemate.standoff_fear_drop` | 10 | Points of saved fear removed once, on the first standoff. |

The brief wrote `data.stalemate.*`. The stalemate section already lives at `data.combat.stalemate` and `ectx.stalemate_cfg` already carries it, so the keys sit beside `no_progress_round_limit` (ASSUMED, see OPEN).

### Saved fields (additive only)

- Situation: `standoff_count` (int). `passed` and `retreat_pass_turn` are existing fields.
- Durable result: new `outcome` value `"standoff"`, `source` `"standoff"`. The old `forced_retreat` run type is gone from core.
- No save field is removed or renamed.

### Stall record (not saved)

`EncounterContext.stall_record = { refused: [{id, name, round}], guards }` is written by `StandoffService.record_round` at the end of each round (called from `_end_round`, after the streak update). It starts again when a round makes progress. It never changes a combat decision. Only party Echoes count as "froze". `EncounterContext.packs_lost` holds the amounts a defeat just lost, so a rebuilt defeat card shows the same row.

### Cause rule (D-116 b, TESTED)

| Recorded event in the current quiet run | `cause` |
|---|---|
| A party Echo refused (`actor.refuse`) | `froze`; names newest first, two at most |
| No refusal, at least one `actor.guard` (either side) | `blocked` |
| Anything else | `unknown` |

An enemy refusal does not count. No recorded event marks a position block, so a position block reads as `unknown`. The card never guesses.

### Defeat card (`packs_lost`)

Row: `{ label: "Packs lost", delta: 0, currency: "ase", cause: "packs_lost", params: { lost_ase, lost_ekwan } }`. It exists only when a defeat marked at least one row lost AND the scaled amount is above 0. The amounts use the same realm scale and replay factor as the leave panel's gathered line, rounded once on the sum. `delta` is 0 because nothing reaches the balance. A rebuilt card shows the same row (TESTED; the rebuilt card adds its own "Repeat defeat" row, which is old behaviour). A settled row and a kept row are not counted. A win or a defeat that lost nothing has no row.

## 3. Facts asked for in item 9

| Question | Answer | Evidence |
|---|---|---|
| Does a path have a turn limit? | No. | READ: no `turn_limit`, `max_turns` or `turn_cap` in `core/` or `data/`. The only readers of `turn_count` are: the escape roll key `stage.escape.<stage_id>.<turn_count>` (`VentureController.handle_return_home`), the retreat roll key, `retreat_pass_turn`, situation `turn_cost`, the turn label, and `turns_taken` (nothing reads it). TESTED: `retreat/path_has_no_turn_limit` (turn 100000 still advances). |
| Does passive income (`economy.settle_time`) depend on turns? | No. It depends on clock seconds since `last_settle_unix`, capped at 3600 s per settle, and on the Ase Flame being awake. | READ: `EconomySettlementService.settle`. TESTED: `retreat/passive_income_ignores_turns` (600 s pays the same at turn 0 and turn 500, and above 0). |
| Is a stalled fight deterministic when rerun with unchanged inputs? | Yes. A rerun gives the same trace, round by round, although the dispatch tick, the stage turn (3 to 4) and the retreat attempts all moved. | TESTED: `retreat/stalled_fight_rerun_is_deterministic` compares the per-round streak, round counter, cell, hit points, fear and morale of both actors. Limit of this proof: `_trim_to_stalled_pair` pins fear and morale, so it proves independence from tick, turn and attempt counters, not from fear. |

Design consequences:
1. The extra turn of a standoff has no value cost on the path (no limit, no income). The real cost is the player's time in the quiet rounds. The turn does change the next escape roll key (`stage.escape.<id>.<turn_count>`), so a standoff also re-rolls a failed escape, as a chosen retreat does (6.2 finding).
2. A rerun stalls again unless an input changes. The inputs a player controls are the party, the directive, and the saved fear of the Echoes. The first-standoff fear drop is the only automatic input change. Without it the S1 loop warning of the design file is real; with it, the rerun can differ only when an Echo that froze had saved fear above 0.

## 4. Write-back of the fight's fear (D-118, orchestrator default for Jeff's play test)

Before D-118 a standoff left the roster fear as it was before the fight, so the fear drop was weak (an Echo at saved fear 0 lost nothing). Now `_resolve_forced_retreat` calls `FlowEncounterState.sync_emotion_to_roster` (extracted from `build_final_snapshot`; one helper, both callers) BEFORE `StandoffService.resolve`. The roster then holds the fight's final fear and morale of each party Echo, and the first-standoff drop acts on that value. Exactly once per fight: `standoff_count == 1` is the stamp (TESTED: a rerun writes the new fight's fear back and applies no second drop). Example (TESTED): an Echo ends the stall at fear 100; the roster holds 90 after the standoff. Morale is written back too. No combat rule and no RNG draw changed.
Side effect: a rerun now starts from the written-back fear (an Echo that froze starts high). The drop of 10 gives it a chance to differ; its size is `mid-game-designer`'s tuning choice.

## 5. Tests

New (all pass):

| Test (suite) | Pins |
|---|---|
| `retreat/standoff_steps_back_and_costs_one_turn` | Card type and keys, one button, no amount or percent, +1 turn, Ase unchanged, fight marked (`passed`, `retreat_pass_turn`, `standoff_count`), pack rows byte-equal, no settle fields, encounter dropped |
| `retreat/standoff_objective_fight_returns_later` | Objective fight: not offered at once after the card; Tier 4 offers normal and objective fights only on a later turn |
| `retreat/standoff_sanctum_button_from_second` | A real second standoff; two buttons; `to_sanctum` ignored on the first card; flag set once and cleared after the dispatch |
| `retreat/standoff_records_deaths_before_the_stall` | This fight's dead Echo joins the earlier names; `lost_echo_names_with` returns the record |
| `retreat/standoff_cause_only_from_recorded_events` | Cause rule, name order, enemy refusal ignored, progress clears the record |
| `retreat/standoff_fear_drop_first_standoff_only` (rewritten, D-118) | Written-back fear 95 to 85, 5 to 0, 0 cannot fall, second standoff written back with no drop, bystander keeps its written-back fear |
| `retreat/standoff_rerun_applies_no_second_drop` (new) | First standoff 95 to 85 and named calmed; a second real standoff writes 90 back with no drop and no calmed name |
| `retreat/stall_level_from_streak_no_numbers` | Levels for streak 0 to 15, missing config switches off, snapshot keys, purity, clears on progress |
| `retreat/prebattle_stalled_before` | False then true |
| `retreat/stalled_fight_rerun_is_deterministic`, `retreat/path_has_no_turn_limit`, `retreat/passive_income_ignores_turns` | Item 9 |
| `pending_result/standoff_card_survives_a_quit` | Real stall, durable result, real reboot, `flow.continue` lands on the same card (data and actions byte-equal), the written-back fear minus the drop is on disk, the button reaches the path, the result is consumed |
| `pending_result/standoff_second_card_replays_both_buttons` | The second card replays byte for byte |
| `econ_char/packs_defeat_card_names_the_loss` | `packs_lost` row, amounts, no row when nothing lost or on a win, rebuilt card |

Rewritten or changed (each with its reason):

| Test | Change | Reason |
|---|---|---|
| `retreat/forced_retreat_still_ends_at_sanctum` (removed) | Replaced by `standoff_steps_back_and_costs_one_turn` | It pinned the Sanctum exit with no turn and no mark. D-116 replaces that route. |
| `combat_roundtrip/no_progress_stalemate_ends_as_forced_retreat` | `run_type` is `standoff` | The card changed. NOT RUN by me (RUN REQUEST). |
| `combat_roundtrip/forced_retreat_grants_nothing` | Asserts the three amount keys are absent (was: equal 0). Ase, Ekwan and Storyweight checks kept | The standoff card has no amount key. NOT RUN by me. |
| `combat_roundtrip/guide_spirit_escort_blocked_still_force_retreats` | `run_type` is `standoff` | A third pin of the old run type, found by grep. NOT RUN by me. |
| `retreat/standoff_fear_drop_first_standoff_only` | Rewritten: sets the actor's fear, not the saved fear | The saved fear is now overwritten by the write-back. |
| `pending_result/standoff_card_survives_a_quit` | Expects the actor's final fear minus 10 on disk (was 30 minus 10) | Same reason. |
| `combat_roundtrip` helper `_setup_no_progress` | Split into `_setup_no_progress` + `_trim_to_stalled_pair` | My rerun test needs the trim on a re-entered fight. Same code, new function. Used by my new tests, which pass. |
| `econ_char` test with `build_scout_return_snapshot(..., "forced_retreat")` | The `forced_retreat` arm removed | The producer arm and its parameter are gone. The same promise (no amount on a stalemate card) is now pinned on the standoff card. |
| `flow_transaction/dispatch_action_count_is_78` | Renamed `..._is_79`, count 79 | New dispatch arm. |
| `pending_result/classify_covers_four_outcomes` | Added a `standoff` row (name unchanged) | New outcome. |

Not changed: `econ_char/packs_retreat_and_standoff_write_no_row` (calls `_resolve_forced_retreat(4)`, still passes: packs and balance untouched). `ResolvePayoutUITests` ~774 builds its own `forced_retreat` dict for the UI; it still passes because `ui/` still has that branch.

Probes that the tests can fail (three runs, files restored, `cmp` clean each time):
1. Objective standoff uses the chosen-retreat route; fear drop on every standoff; `record_fight_deaths` removed; `can_go_sanctum` check removed. Failed: `standoff_objective_fight_returns_later`, `standoff_sanctum_button_from_second`, `standoff_records_deaths_before_the_stall`, `standoff_fear_drop_first_standoff_only`.
2. Tier 4 due check removed; record not cleared on progress; clear of `pending_return_confirm` removed. Failed: six tests in `retreat`, including the old `retreat_passed_fight_returns_later`.
3. Standoff block removed from producer G; `packs_lost` row removed. Failed: both `pending_result/standoff_*` tests and `econ_char/packs_defeat_card_names_the_loss`.

Filtered runs (own `ECHOES_TEST_SAVE_DIR`, deleted before each run, each under 2 minutes). Compile check: zero errors.

| Filter | Result |
|---|---|
| `=econ_char,seam` | 145 of 145 |
| `=objective,objective_combat` | 91 of 91 |
| `=stage,stage_stop_ui,stage_camera` | 84 of 84 |
| `=pending_result,save_integrity,retreat` | 71 of 71 |
| `=unified_resolve,foundation_ui,snapshot_contract,snapshot_fingerprint,snapshot_purity,realm_ui` | 72 of 72 |
| `=venture_char,flow_transaction,retreat,payout_ui,summon_price_ui,sanctum.summon` | 149 of 149 |
| `=realm,realm_prog,realm_reward,bridge,onboarding` | 59 of 59 |
| `=sit_res,contact,contact_cfg,combat_ui` | 93 of 93 |
| `=combat` | 42 of 42 |
| `=explore,explore_p5,economy,consequence,sanctum_pulse` | 86 of 86 |
| `=snapshot,voice,combat_camera,combat_terrain,combat_initiative` | 116 of 116 |
| `=retreat,pending_result,flow_transaction,econ_char` (before D-118) | 159 of 159 |
| After D-118: `=retreat,pending_result,save_integrity` 72; `=econ_char,seam` 145; `=venture_char,flow_transaction,retreat,payout_ui,summon_price_ui,sanctum.summon` 150; the other groups above unchanged | all pass |

## 6. PREDICTED moved values (nothing re-recorded)

| Constant or baseline | Prediction | Why |
|---|---|---|
| `snapshot_fingerprint/*` (sanctum, stage_explore) | No move (TESTED: passes) | `return_confirm_requested` exists only when true. |
| `fingerprint_*` FINAL (`FlowFingerprintTests._final_fingerprint`) | Should NOT move | It hashes `data` key names of the FINAL (resolve) snapshot. I added no key to the victory or defeat combat card. The defeat card gets one ROW inside `reward_breakdown`, not a key. The round-snapshot keys `stall_level`, `stall_froze_name`, `stalled_before` are not in any hashed payload (READ: the hashed projections read the final card, `snapshot_type` and transition lists, never round `data` keys). |
| `fingerprint_determinism_*`, `fingerprint_seek` | Should NOT move | No combat rule, RNG draw or `EchoFactory` change. `record_round` only reads. |
| `combat_baseline`, `maturity_baseline` | Should NOT move | Same reason. READ: no baseline fixture reaches a stalemate (grep `no_progress` in `CombatBaselineTests` finds nothing). The save reason `combat.no_progress_forced_retreat` is unchanged. |
| `combat_roundtrip` | The three rewritten tests should pass; others should not move | Predicted pass is by reading: the same `_setup_no_progress` path passes in my new tests. |
| `reward` | Should NOT move | It reads labels, not row counts, on defeat cards (READ). `packs_lost` has `delta` 0. |
| `RetreatTests/forced_retreat_still_ends_at_sanctum` | Removed (see section 5) | |
| `CombatRoundtrip` two forced-retreat tests (+ a third found by grep) | Rewritten (see section 5) | |
| `EconomyCharacterizationTests` ~1293 | Rewritten (arm removed) | |
| `ResolvePayoutUITests` ~774 | Does NOT move | Static dict; `ui/` untouched. It becomes a dead pin when `ui/` retires the branch. |

Write-back (D-118): it runs only inside `_resolve_forced_retreat`, so it can move a recorded value only in a fixture that reaches a stalemate and then reads roster fear or morale. READ: no `combat_baseline`, fingerprint or `maturity_baseline` fixture reaches a stalemate (no `no_progress` in them). It writes the same two fields the ending-fight path already writes. So it should move nothing. The `combat_roundtrip` stalemate tests read Ase, Ekwan and Storyweight, not fear.

If a FINAL constant moves: it cannot be one of my keys (I added none). Stop and attribute: print `data_keys` old and new and diff them.

## 7. `ui/` references that break or need work (not edited)

| File | Problem |
|---|---|
| `ui/screens/venture/ResolveScreen.gd:224-237` | `run_type == "standoff"` matches no branch. It falls to the combat renderer (VICTORY or DEFEAT banner, wrong). Needs a `_render_standoff` branch: title, body line chosen by `cause` + `froze_names`, `calmed_names` line, packs line, open-fight line (the card does not say objective or normal: the UI line `The task is still there.` is generic), repeat hint from `standoff_count`, two buttons from `cta.continue` and `cta.sanctum`. Send the slot's action dict whole (it carries `to_sanctum`). |
| `ResolveScreen.gd:224-226, 887-893` | The `forced_retreat` branch and banner `Forced Retreat` are dead code now. |
| `ui/screens/combat/CombatBoardScreen.gd` | Does not read `stall_level` or `stall_froze_name` (the quiet-fight line, vignette, bark). |
| `ui/overlays/realm/PrebattleModal` | Does not read `stalled_before`. |
| `ui/screens/venture/StageExploreScreen.gd` | Does not read `return_confirm_requested` (open the return confirmation once). |
| `ui/components/PayoutCausePresentation.gd` | No entry for the cause `packs_lost` (copy slot `defeat.packs_lost`); params `lost_ase`, `lost_ekwan`. |
| `tests/ResolvePayoutUITests.gd:774` | Uses a `forced_retreat` dict; delete with the dead branch. |

## 8. Docs not updated (docs step)

`CONVENTIONS.md` has the new action row (done). Still open: `docs/MEMORY.md` (~402-404: forced retreat, dispatch count 79, new fields), `docs/integration-map.md:37`, `docs/resolve-snapshot-block-spec.md` (block 17 `add_standoff`; 14f still missing from 7.B), `phase6-2-build.md` finding 3 and follow-up 46 (closed by this step), D-106 item 2 addendum, `PendingResultService` header (now five outcomes, done in code), GDD line for "standoff" (the GDD has none).

## 9. Ponytail: skipped

- No separate fear-drop stamp. `standoff_count` is the stamp; a second call cannot happen because the encounter is dropped.
- No write-back of combat fear and morale (section 4). Jeff decides.
- No fix of the stale `retreat_pass_turn` after `stage.ignore_situation` (F-C of D-112, old).
- No new test suite (shard map unchanged); new tests live in `retreat`, `pending_result`, `econ_char`.
- No per-round stall log lines.
- No position-block detection (no recorded event exists).
- No `ui/`, no Notion, no GDD edit, no commit.

## RUN REQUEST (main chat runs; a subagent must not)

1. Command A: `rm -rf /tmp/echoes-vnext-tests && /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =fingerprint_seek,reward,combat_baseline,combat_roundtrip,maturity_baseline` (tool `timeout: 3700000`). Expected: several minutes (`reward` is the longest suite).
2. Command B: same shape with `fingerprint` (substring: all `fingerprint_*`, `fingerprint_determinism_*` and `snapshot_fingerprint`).
3. The stalemate suites are inside A (`combat_roundtrip` holds the three rewritten tests; `combat_baseline` has no stalemate fixture). `combat` and `snapshot_*` already pass in my filtered runs.
4. Files edited by the runs: none. Verify: `git status --short` shows only the 22 entries of this step (20 modified files, `core/realms/StandoffService.gd` and its `.uid`) plus this document.
5. Read back: the `Tests:` line and every failing line with expected and actual values. Expected: all pass. Report old and new for any moved value.

## OPEN — questions and assumptions

ASSUMED: The three new config keys sit in `data.combat.stalemate`, not `data.stalemate` | WHY: the section already exists there, `ectx.stalemate_cfg` already carries it to both readers, and AGENTS common mistake 4 says to put a key where the runtime reads it | WRONG IF: Jeff or `mid-game-designer` wants a new top-level `data.stalemate` section (then the keys, `EncounterSetupService`, `KeeperIntroService` and the comment move).
ASSUMED: The fear drop acts on the fight's written-back fear (D-118), and "froze" means a party Echo with a recorded `actor.refuse` in the current quiet run | WHY: orchestrator decision D-118 | WRONG IF: Jeff dislikes, after the play test, that an Echo that froze starts the rerun with high fear
ASSUMED: The fear drop applies to every party Echo that refused, not only the two named on the card; `froze_names` and `calmed_names` show at most two names | WHY: the copy lines take one or two names; "each Echo that froze" in the brief | WRONG IF: Jeff wants the drop limited to the two named, or three names on the card.
ASSUMED: "The last rounds" means the current no-progress streak | WHY: the streak is the stall by definition and needs no new config | WRONG IF: Jeff wants a shorter window (an Echo that froze in round 1 of 15 and then recovered still counts).
ASSUMED: A defeat's lost amounts use the realm scale and replay factor, rounded once on the sum, like the leave panel's gathered line | WHY: the player saw that number in the panel | WRONG IF: the card should show the base amounts (the event cards show base amounts, 7.C).
ASSUMED: The card labels in core are the final copy lines, and `packs_lost` has the label "Packs lost" | WHY: `phase7-copy-final.md` has no label for the ledger row; the UI uses its own constant (`PACKS_LOST_LINE`) | WRONG IF: the UI step wants core to carry no label.
ASSUMED: A fight with no situation record on the stage (a harness or debug fight) counts as the first standoff | WHY: it cannot be saved or counted, and the first standoff is the safe default | WRONG IF: such a fight can happen in play (none found: every stage fight sets `last_situation_id` on arrival).
BLOCKED: Can the three `combat_roundtrip` rewrites pass? | CHECKED: they use the same setup path as my passing tests, but I may not run `combat_roundtrip` | NEED: Command A of the RUN REQUEST.
